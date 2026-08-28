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
}
