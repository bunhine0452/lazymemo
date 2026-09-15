import CryptoKit
import Foundation

/// 모델 파일의 자리와 상태 — vault 밖 Application Support, iCloud·백업 제외 (명세 §7).
///
/// 배치: `<support>/models/<profileID>/<file>` 이 활성, `<file>.part` 가 받는 중, `manifest.json` 이 활성 판의 기록.
/// 검증 전에는 활성 파일을 건드리지 않는다 — 새 판이 깨져도 옛 판은 남는다.
public actor ModelStore {
    public enum Failure: Error, Equatable {
        case checksumMismatch(expected: String, actual: String)
        case sizeMismatch(expected: Int64, actual: Int64)
        case insufficientDisk(needed: Int64, available: Int64)
        case notStaged
    }

    public let root: URL
    private let fileManager: FileManager

    public init(support: URL, fileManager: FileManager = .default) {
        self.root = support.appending(path: "models", directoryHint: .isDirectory)
        self.fileManager = fileManager
    }

    public nonisolated func directory(for m: ModelManifest) -> URL {
        root.appending(path: m.profileID, directoryHint: .isDirectory)
    }
    public nonisolated func activeURL(for m: ModelManifest) -> URL {
        directory(for: m).appending(path: m.file.name, directoryHint: .notDirectory)
    }
    public nonisolated func stagingURL(for m: ModelManifest) -> URL {
        directory(for: m).appending(path: m.file.name + ".part", directoryHint: .notDirectory)
    }

    /// 활성 파일이 있고 크기가 맞으면 ready. 해시는 활성화 때 한 번 본다 — 매 실행마다 2.4GB 를 읽지 않는다.
    public func availability(_ m: ModelManifest) -> ModelAvailability {
        let url = activeURL(for: m)
        guard let size = fileSize(url) else { return .notDownloaded }
        return size == m.file.bytes ? .ready : .corrupted
    }

    /// 받다 만 바이트 수. 이어받기의 시작점.
    public func stagedBytes(_ m: ModelManifest) -> Int64 { fileSize(stagingURL(for: m)) ?? 0 }

    public func prepareDirectory(_ m: ModelManifest) throws {
        try fileManager.createDirectory(at: directory(for: m), withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var dir = root
        try? dir.setResourceValues(values)
    }

    /// 남은 바이트 + 여유(200MB)가 볼륨에 있어야 시작한다.
    public func ensureDiskSpace(_ m: ModelManifest) throws {
        let needed = m.file.bytes - stagedBytes(m) + 200 * 1024 * 1024
        let values = try? root.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values?.volumeAvailableCapacityForImportantUsage ?? .max
        if available < needed { throw Failure.insufficientDisk(needed: needed, available: available) }
    }

    /// staging → 크기·SHA-256 검증 → 원자적 교체. 실패하면 활성 파일은 그대로다.
    public func activate(_ m: ModelManifest) throws {
        let staged = stagingURL(for: m)
        guard let size = fileSize(staged) else { throw Failure.notStaged }
        guard size == m.file.bytes else { throw Failure.sizeMismatch(expected: m.file.bytes, actual: size) }
        let actual = try Self.sha256(of: staged)
        guard actual == m.file.sha256 else {
            try? fileManager.removeItem(at: staged)
            throw Failure.checksumMismatch(expected: m.file.sha256, actual: actual)
        }
        let active = activeURL(for: m)
        _ = try fileManager.replaceItemAt(active, withItemAt: staged)
        let manifestURL = directory(for: m).appending(path: "manifest.json", directoryHint: .notDirectory)
        try JSONEncoder().encode(m).write(to: manifestURL, options: .atomic)
    }

    public func discardStaging(_ m: ModelManifest) {
        try? fileManager.removeItem(at: stagingURL(for: m))
    }

    /// 앱 안에서 지운다 — 폴더째. 다시 받을 수 있다.
    public func delete(_ m: ModelManifest) throws {
        let dir = directory(for: m)
        if fileManager.fileExists(atPath: dir.path(percentEncoded: false)) {
            try fileManager.removeItem(at: dir)
        }
    }

    private func fileSize(_ url: URL) -> Int64? {
        // symlink 면 대상의 크기 — 시험이 2.4GB 를 복사하지 않고 링크로 앉힌다.
        let resolved = url.resolvingSymlinksInPath()
        guard let attrs = try? fileManager.attributesOfItem(atPath: resolved.path(percentEncoded: false)),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    /// 파일을 통째로 메모리에 올리지 않는다 — 8MB 씩.
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 * 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
