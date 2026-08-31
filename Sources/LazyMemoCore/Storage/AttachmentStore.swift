import Foundation

/// 메모에 붙은 사진 같은 첨부 파일 (D4 의 연장).
///
/// 마크다운이 정본이므로 사진도 **Vault 안의 진짜 파일**이어야 한다. 데이터베이스나
/// 앱 전용 저장소에 넣으면 사용자가 Finder 로 열어볼 수 없고, 폴더를 통째로
/// 옮기는 것만으로 동기화된다는 약속(§5.1)도 깨진다.
///
/// `MemoVault` 와 달리 actor 가 아니다. 첨부는 한 번 쓰고 다시 쓰지 않는 덩어리라
/// 경합이 없고, 붙여넣기는 사용자의 손이 멈춘 그 순간에 끝나야 한다.
public struct AttachmentStore: Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case unsupported(String)

        public var description: String {
            switch self {
            case .unsupported(let kind): "붙일 수 없는 형식입니다: \(kind)"
            }
        }
    }

    /// Vault 안에서 첨부가 사는 곳.
    public static let directoryName = "attachments"

    private let paths: AppPaths

    public init(paths: AppPaths) {
        self.paths = paths
    }

    /// `FileManager` 는 Sendable 이 아니라 담아 두지 않는다. 쓸 때마다 얻는다.
    private var fileManager: FileManager { .default }

    public var directory: URL {
        paths.vault.appending(path: Self.directoryName, directoryHint: .isDirectory)
    }

    /// 파일로 쓰고 **본문에 넣을 상대 경로**를 돌려준다.
    ///
    /// 절대 경로를 쓰지 않는 이유: 사용자가 Vault 를 iCloud 로 옮기거나 다른
    /// 기계에서 열면 절대 경로는 전부 끊어진다. 마크다운은 파일 옆에서
    /// 읽히는 문서다.
    public func save(_ data: Data, fileExtension: String, id: ULID = ULID()) throws -> String {
        let sanitized = fileExtension
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        guard !sanitized.isEmpty, sanitized.count <= 5 else {
            throw Failure.unsupported(fileExtension)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(id.stringValue).\(sanitized)"
        try data.write(to: directory.appending(path: name, directoryHint: .notDirectory), options: .atomic)

        return "\(Self.directoryName)/\(name)"
    }

    /// 본문의 상대 경로를 실제 파일 위치로 되돌린다.
    public func url(for relativePath: String) -> URL? {
        // 상위로 올라가는 경로는 받지 않는다. 본문은 사용자와 LLM 이 쓰는
        // 값이라 Vault 밖을 가리키게 만들 수 있다.
        guard !relativePath.hasPrefix("/"), !relativePath.contains("..") else { return nil }
        return paths.vault.appending(path: relativePath, directoryHint: .notDirectory)
    }

    /// 어디서도 참조하지 않는 첨부를 찾는다. 지우는 것은 호출자가 정한다 (D6).
    public func orphans(referencedBy bodies: [String]) throws -> [URL] {
        let referenced = Set(bodies.flatMap(MarkdownScanner.imagePaths(in:)))
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }

        return entries.filter { entry in
            !referenced.contains("\(Self.directoryName)/\(entry.lastPathComponent)")
        }
    }

    // MARK: 치우기 (D6)

    /// 휴지통으로 간 첨부가 사는 곳.
    ///
    /// 메모와 **같은 규칙**이다 — 지우는 것이 아니라 옮기는 것이고, 보존
    /// 기간이 지나야 사라진다. 사진은 다시 만들 수 없는 것이라 더 그렇다.
    public var trashDirectory: URL {
        paths.trash.appending(path: Self.directoryName, directoryHint: .isDirectory)
    }

    /// 어디서도 참조하지 않는 첨부를 휴지통으로 옮긴다.
    ///
    /// `orphans(referencedBy:)` 는 오래 구현만 되어 있고 **앱 어디서도 부르지
    /// 않았다.** 그래서 붙였다 지운 사진, 빠른 입력에 붙여 놓고 확정하지 않은
    /// 사진이 Vault 에 영원히 쌓였다.
    ///
    /// - Parameters:
    ///   - bodies: 참조로 치는 본문. **휴지통에 있는 메모의 본문도 넣어야
    ///     한다** — 안 그러면 지운 메모를 되돌렸을 때 사진만 사라진다.
    ///   - notTouchedSince: 이보다 최근에 손댄 파일은 건드리지 않는다. 빠른
    ///     입력에 사진을 붙이면 **파일이 먼저 생기고** 본문은 아직 어느 메모에도
    ///     없다. 그 사이를 쓸면 사용자가 방금 붙인 사진이 눈앞에서 사라진다.
    /// - Returns: 옮긴 파일 수.
    @discardableResult
    public func discardOrphans(referencedBy bodies: [String], notTouchedSince: Date) throws -> Int {
        let stale = try orphans(referencedBy: bodies)
            .filter { modifiedAt($0) < notTouchedSince }
        guard !stale.isEmpty else { return 0 }

        try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        var moved = 0
        for file in stale {
            let destination = trashDirectory
                .appending(path: file.lastPathComponent, directoryHint: .notDirectory)
            try? fileManager.removeItem(at: destination)
            guard (try? fileManager.moveItem(at: file, to: destination)) != nil else { continue }
            // 옮긴 시각을 새로 찍는다. 이것이 메모의 `deleted:` 에 해당하는
            // 자리라 — 안 찍으면 2년 전에 붙인 사진이 치워지자마자 보존
            // 기간이 지난 것으로 읽혀 그 자리에서 지워진다.
            try? fileManager.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: destination.path(percentEncoded: false)
            )
            moved += 1
        }
        return moved
    }

    /// 휴지통의 첨부 중 보존 기간이 지난 것을 지운다.
    ///
    /// **첨부에 대한 하드 삭제는 여기뿐이고, 앱만 부른다** — 메모와 같은
    /// 배선이다 (D6). MCP 도구 표면에는 이 함수로 가는 길이 없다.
    @discardableResult
    public func purgeTrashed(
        retention: TimeInterval = MemoVault.trashRetention, now: Date = Date()
    ) throws -> Int {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: trashDirectory, includingPropertiesForKeys: nil
        ) else { return 0 }

        var purged = 0
        for entry in entries where now.timeIntervalSince(modifiedAt(entry)) > retention {
            guard (try? fileManager.removeItem(at: entry)) != nil else { continue }
            purged += 1
        }
        return purged
    }

    private func modifiedAt(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? Date()
    }
}
