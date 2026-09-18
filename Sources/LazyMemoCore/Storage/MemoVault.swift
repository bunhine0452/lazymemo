import Foundation

/// 마크다운 정본에 대한 유일한 파일 접근 계층 (D4).
///
/// 인덱스도 UI 도 MCP 도 파일을 직접 건드리지 않는다. 여기를 통과하지 않는
/// 쓰기 경로가 생기는 순간 "파일이 정본"이라는 약속이 깨진다.
public actor MemoVault {
    public enum Failure: Error, CustomStringConvertible {
        case notFound(ULID)
        case notInTrash(ULID)
        /// 대조한 본문 hash 가 다르다 — 그 사이 누가 고쳤다. 아무것도 쓰지 않았다.
        case changed(ULID)

        public var description: String {
            switch self {
            case .notFound(let id): L("메모를 찾을 수 없습니다: \(id.description)")
            case .notInTrash(let id): L("휴지통에 없는 메모입니다: \(id.description)")
            case .changed(let id): L("그 사이 메모가 바뀌었습니다: \(id.description)")
            }
        }
    }

    /// 저장 결과 — 인덱스 갱신에 필요한 것만 돌려준다.
    public struct SaveResult: Sendable {
        public let memo: Memo
        public let relativePath: String
        public let modifiedAt: Date
    }

    /// 휴지통 보존 기간 (D6). 지난 것만 하드 삭제 대상이 된다.
    public static let trashRetention: TimeInterval = 30 * 24 * 60 * 60

    private let paths: AppPaths
    private let fileManager: FileManager

    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    // MARK: 경로 — id 만으로 결정된다

    /// `notes/2026/08/<ulid>.md`. 연·월은 **ULID 에 박힌 생성 시각**에서 뽑는다.
    /// frontmatter 의 `created` 를 쓰면 사용자가 그 값을 고치는 순간 파일을 잃는다.
    public nonisolated func url(for id: ULID) -> URL {
        paths.notesDirectory(for: id.timestamp)
            .appending(path: MemoFile.fileName(for: id), directoryHint: .notDirectory)
    }

    public nonisolated func trashURL(for id: ULID) -> URL {
        paths.trash.appending(path: MemoFile.fileName(for: id), directoryHint: .notDirectory)
    }

    public nonisolated func relativePath(of url: URL) -> String {
        let base = paths.vault.path(percentEncoded: false)
        let full = url.path(percentEncoded: false)
        return full.hasPrefix(base) ? String(full.dropFirst(base.count)) : full
    }

    // MARK: 읽기

    public func load(_ id: ULID) throws -> Memo {
        guard let location = try locate(id) else { throw Failure.notFound(id) }
        return try read(at: location, id: id)
    }

    /// Vault 전체 스캔. 인덱스 재생성의 근거이며, 이 경로가 항상 살아 있어야
    /// "인덱스는 언제든 버려도 된다"는 §5.3 의 불변식이 성립한다.
    public func loadAll() throws -> [SaveResult] {
        try scan(directory: paths.notes).compactMap { location in
            guard let id = MemoFile.identifier(fromFileName: location.lastPathComponent),
                  let memo = try? read(at: location, id: id)
            else { return nil }
            return SaveResult(
                memo: memo,
                relativePath: relativePath(of: location),
                modifiedAt: modificationDate(of: location)
            )
        }
    }

    public func trashedMemos() throws -> [Memo] {
        try scan(directory: paths.trash).compactMap { location in
            guard let id = MemoFile.identifier(fromFileName: location.lastPathComponent) else { return nil }
            return try? read(at: location, id: id)
        }
        .sorted { ($0.deleted ?? $0.updated) > ($1.deleted ?? $1.updated) }
    }

    public func exists(_ id: ULID) -> Bool {
        (try? locate(id)) != nil
    }

    // MARK: 쓰기

    /// `at` 을 주면 그 자리에 쓴다 — 사람이 Finder 로 다른 달 폴더에 옮겨 둔 파일을 고칠 때.
    /// 규격 자리에 새로 쓰면 같은 메모가 두 파일이 되어 목록에 둘로 선다.
    @discardableResult
    public func save(_ memo: Memo, at location: URL? = nil) throws -> SaveResult {
        let location = location ?? url(for: memo.id)
        try fileManager.createDirectory(
            at: location.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // 원자적 쓰기 — 저장 도중 죽어도 반쪽짜리 파일이 남지 않는다.
        // 저장 버튼 없이 계속 쓰는 앱이라(§8) 중단 지점이 많다.
        //
        // iCloud 컨테이너 안에서도 NSFileCoordinator 없이 이대로 쓴다. 원자적
        // 쓰기는 임시 파일 + 이름 바꾸기라 iCloud 가 반쪽을 볼 수 없고, iCloud 가
        // 내려놓는 쪽도 같은 방식이라 우리가 반쪽을 읽을 일이 없다. 두 기기가
        // 따로 고친 것은 판본으로 남고 `settleConflicts` 가 정리한다.
        // oculpm-defer: 파일 조정 없음 — 같은 파일을 iCloud 가 내려놓는 순간과 겹치면 판본이 하나 더 생길 수 있다; 실기기 왕복에서 유실·충돌 보고가 오면 coordinate(writingItemAt:) 로 감싼다
        try Data(MemoFile.encode(memo).utf8).write(to: location, options: .atomic)

        return SaveResult(
            memo: memo,
            relativePath: relativePath(of: location),
            modifiedAt: modificationDate(of: location)
        )
    }

    /// 읽고 대조하고 쓰기를 **한 actor 호출 안에서** 한다 — 사이에 `await` 가 없어
    /// 다른 쓰기가 끼어들 수 없다. 밖에서 get→update 로 흉내 내면 그 사이가 열린다.
    ///
    /// `expectedHash` 가 있고 지금 본문의 hash 와 다르면 `Failure.changed` — 파일은 그대로다.
    /// 같은 기기 안의 약속이다. 다른 기기의 판본은 `settleConflicts` 가 따로 정리한다.
    @discardableResult
    public func modify(
        _ id: ULID, expectedHash: String?, _ change: (inout Memo) throws -> Void
    ) throws -> SaveResult {
        guard let location = try locate(id) else { throw Failure.notFound(id) }
        var memo = try read(at: location, id: id)
        if let expectedHash, memo.contentHash != expectedHash { throw Failure.changed(id) }
        try change(&memo)
        return try save(memo, at: location)
    }

    // MARK: 삭제 — 하드 삭제로 가는 길이 없다 (D6)

    /// 파일을 지우지 않고 `.trash/` 로 옮긴다. 이것이 MCP 가 도달할 수 있는
    /// 삭제 경로의 전부다 (설계문서 §6).
    @discardableResult
    public func moveToTrash(_ id: ULID, expectedHash: String? = nil, now: Date = Date()) throws -> Memo {
        guard let location = try locate(id) else { throw Failure.notFound(id) }

        var memo = try read(at: location, id: id)
        if let expectedHash, memo.contentHash != expectedHash { throw Failure.changed(id) }
        memo.deleted = now

        let destination = trashURL(for: id)
        try fileManager.createDirectory(at: paths.trash, withIntermediateDirectories: true)
        // 삭제 시각을 남기려면 어차피 다시 써야 하므로, 옮기고 나서 덮어쓴다.
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: location, to: destination)
        try Data(MemoFile.encode(memo).utf8).write(to: destination, options: .atomic)

        return memo
    }

    @discardableResult
    public func restore(_ id: ULID) throws -> SaveResult {
        let source = trashURL(for: id)
        guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else {
            throw Failure.notInTrash(id)
        }

        var memo = try read(at: source, id: id)
        memo.deleted = nil
        let result = try save(memo)
        try fileManager.removeItem(at: source)
        return result
    }

    /// 보존 기간이 지난 것만 실제로 지운다.
    ///
    /// **MCP 도구로 노출하지 않는다** — LLM 이 도달할 수 있는 코드 경로에
    /// 하드 삭제가 없어야 한다는 D6 의 요구는 규약이 아니라 배선으로 지킨다.
    @discardableResult
    public func purgeExpired(
        retention: TimeInterval = MemoVault.trashRetention,
        now: Date = Date()
    ) throws -> [ULID] {
        var purged: [ULID] = []
        for location in try scan(directory: paths.trash) {
            guard let id = MemoFile.identifier(fromFileName: location.lastPathComponent),
                  let memo = try? read(at: location, id: id)
            else { continue }

            // 삭제 시각이 없는 파일은 사용자가 직접 넣었을 수 있으니 건드리지 않는다.
            guard let deleted = memo.deleted, now.timeIntervalSince(deleted) > retention else { continue }

            try fileManager.removeItem(at: location)
            purged.append(id)
        }
        return purged
    }

    // MARK: 아직 안 내려온 파일 — iCloud 가 자리만 잡아 둔 것

    /// iCloud 는 목록만 먼저 주고 내용은 열 때 가져온다. 그 자리에는 숨은
    /// `.<이름>.md.icloud` 가 있고 `scan` 은 숨은 파일을 건너뛰므로, 우리가 청하지
    /// 않으면 그 메모는 화면에 **없다** — 맥의 「Mac 저장 공간 최적화」가 오래된
    /// 메모를 치웠을 때, 폰이 먼저 적은 메모가 맥에 처음 올 때.
    ///
    /// 돌려주는 것은 청한 수. 내려오면 파일 감시가 발화해 `reconcile` 이 다시 돈다.
    @discardableResult
    public func requestMissingDownloads() -> Int {
        var requested = 0
        for directory in [paths.notes, paths.trash] {
            guard let enumerator = fileManager.enumerator(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard let real = Self.realFile(behindPlaceholder: url) else { continue }
                // 실패해도 다음 대조에 다시 청한다. 여기서 멈추면 그 한 장이 영영 안 보인다.
                if (try? fileManager.startDownloadingUbiquitousItem(at: real)) != nil { requested += 1 }
            }
        }
        return requested
    }

    /// `.<ulid>.md.icloud` → `<ulid>.md`. 그 모양이 아니면 `nil`.
    static func realFile(behindPlaceholder url: URL) -> URL? {
        let name = url.lastPathComponent
        guard url.pathExtension == "icloud", name.hasPrefix(".") else { return nil }
        let real = String(name.dropFirst().dropLast(".icloud".count))
        guard real.hasSuffix("." + MemoFile.fileExtension) else { return nil }
        return url.deletingLastPathComponent().appending(path: real, directoryHint: .notDirectory)
    }

    // MARK: 충돌 — iCloud 가 판본을 둘 남겼을 때

    /// 판본이 둘 이상인 파일을 찾아 정리한다 (`ConflictSettlement`). 진 판본은
    /// 휴지통에 새 메모로 남기고, iCloud 에는 정리했다고 알린다 — 알리지
    /// 않으면 같은 충돌을 다음에 또 본다.
    ///
    /// 돌려주는 것은 휴지통으로 간 것들. 화면이 「다른 기기의 글 한 장을 휴지통에
    /// 두었습니다」 하고 적을 수 있게.
    @discardableResult
    public func settleConflicts(now: Date = Date()) throws -> [Memo] {
        var retired: [Memo] = []

        for location in try scan(directory: paths.notes) {
            guard let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: location),
                  !versions.isEmpty,
                  let id = MemoFile.identifier(fromFileName: location.lastPathComponent),
                  let current = try? read(at: location, id: id)
            else { continue }

            let others = versions.compactMap { try? read(at: $0.url, id: id) }
            let outcome = ConflictSettlement.settle(current: current, others: others, now: now)

            for loser in outcome.retired {
                try retire(loser)
                retired.append(loser)
            }
            if outcome.keep != current { try save(outcome.keep) }

            for version in versions { version.isResolved = true }
            try? NSFileVersion.removeOtherVersionsOfItem(at: location)
        }

        return retired
    }

    /// 휴지통에 **바로** 앉힌다 — 바탕화면을 거치지 않는다. 충돌에서 진 판본이
    /// 잠깐이라도 종이로 서면 사용자는 같은 메모가 둘로 보인다.
    func retire(_ memo: Memo) throws {
        precondition(memo.deleted != nil, "휴지통에 앉히는 메모는 deleted 가 있어야 한다")
        try fileManager.createDirectory(at: paths.trash, withIntermediateDirectories: true)
        try Data(MemoFile.encode(memo).utf8).write(to: trashURL(for: memo.id), options: .atomic)
    }

    // MARK: 내부

    private func read(at location: URL, id: ULID) throws -> Memo {
        let text = try String(contentsOf: location, encoding: .utf8)
        return try MemoFile.decode(text, fallbackID: id)
    }

    /// 규격 경로를 먼저 보고, 없으면 훑는다 — 사용자가 파일을 옮겼을 수 있다.
    private func locate(_ id: ULID) throws -> URL? {
        let expected = url(for: id)
        if fileManager.fileExists(atPath: expected.path(percentEncoded: false)) { return expected }

        let name = MemoFile.fileName(for: id)
        return try scan(directory: paths.notes).first { $0.lastPathComponent == name }
    }

    /// 폴더에 떨어진 **낯선 이름의 `.md` 를 정본으로 받아 앉힌다.**
    ///
    /// 이 앱의 파일 이름은 ULID 인데, 밖에서 만든 파일이 그 규칙을 알 리 없다.
    /// 아이폰 단축어가 떨군 `메모.md`, Hazel 이 옮겨 놓은 것, Finder 로 끌어다
    /// 놓은 것 — 이름을 맞추라고 요구하는 대신 **우리가 붙인다.** 「완성을
    /// 요구하지 않는다」(철학 1)는 화면 안에서만 지킬 약속이 아니다.
    ///
    /// frontmatter 가 아예 없으면 파일 전체를 본문으로 본다. `id` 만 없으면
    /// 나머지(`due`·`place` 등)는 그대로 살린다 — `MemoFile.decode` 의 `fallbackID`
    /// 가 그 자리를 위해 있던 것이다.
    ///
    /// **받아 앉힌 뒤 원본 파일은 지운다.** 두 이름으로 같은 메모가 남으면 다음
    /// 스캔에서 또 받아 앉혀 무한히 불어난다.
    @discardableResult
    public func adopt(now: Date = Date()) throws -> [Memo] {
        var adopted: [Memo] = []

        for location in try scan(directory: paths.notes) {
            let name = location.lastPathComponent
            // 이미 우리 이름이면 손댈 것이 없다.
            guard MemoFile.identifier(fromFileName: name) == nil else { continue }

            guard let data = try? Data(contentsOf: location) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // 빈 파일은 받지 않는다. 쓰다 만 것일 수도 있으므로 지우지도 않는다.
            guard !trimmed.isEmpty else { continue }

            let modified = modificationDate(of: location)
            let fresh = ULID(timestamp: modified)
            let memo = (try? MemoFile.decode(text, fallbackID: fresh))
                ?? Memo(id: fresh, created: modified, updated: modified, body: trimmed)

            guard let saved = try? save(memo) else { continue }
            // 정본이 새 자리에 앉은 것을 확인한 뒤에 지운다.
            if url(for: memo.id) != location { try? fileManager.removeItem(at: location) }
            adopted.append(saved.memo)
        }

        return adopted
    }

    private func scan(directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        return enumerator.compactMap { element in
            guard let url = element as? URL,
                  url.pathExtension == MemoFile.fileExtension
            else { return nil }
            return url
        }
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? Date()
    }
}
