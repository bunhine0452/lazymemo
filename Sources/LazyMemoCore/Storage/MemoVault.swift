import Foundation

/// 마크다운 정본에 대한 유일한 파일 접근 계층 (D4).
///
/// 인덱스도 UI 도 MCP 도 파일을 직접 건드리지 않는다. 여기를 통과하지 않는
/// 쓰기 경로가 생기는 순간 "파일이 정본"이라는 약속이 깨진다.
public actor MemoVault {
    public enum Failure: Error, CustomStringConvertible {
        case notFound(ULID)
        case notInTrash(ULID)

        public var description: String {
            switch self {
            case .notFound(let id): "메모를 찾을 수 없습니다: \(id)"
            case .notInTrash(let id): "휴지통에 없는 메모입니다: \(id)"
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

    @discardableResult
    public func save(_ memo: Memo) throws -> SaveResult {
        let location = url(for: memo.id)
        try fileManager.createDirectory(
            at: location.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // 원자적 쓰기 — 저장 도중 죽어도 반쪽짜리 파일이 남지 않는다.
        // 저장 버튼 없이 계속 쓰는 앱이라(§8) 중단 지점이 많다.
        try Data(MemoFile.encode(memo).utf8).write(to: location, options: .atomic)

        return SaveResult(
            memo: memo,
            relativePath: relativePath(of: location),
            modifiedAt: modificationDate(of: location)
        )
    }

    // MARK: 삭제 — 하드 삭제로 가는 길이 없다 (D6)

    /// 파일을 지우지 않고 `.trash/` 로 옮긴다. 이것이 MCP 가 도달할 수 있는
    /// 삭제 경로의 전부다 (설계문서 §6).
    @discardableResult
    public func moveToTrash(_ id: ULID, now: Date = Date()) throws -> Memo {
        guard let location = try locate(id) else { throw Failure.notFound(id) }

        var memo = try read(at: location, id: id)
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
