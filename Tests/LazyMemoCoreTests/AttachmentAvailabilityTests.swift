import Foundation
import Testing
@testable import LazyMemoCore

/// 사진이 지금 여기 있나 — iCloud 가 자리만 잡아 둔 것을 알아보는 길.
@Suite("첨부 — 있나, 오는 중인가, 없나")
struct AttachmentAvailabilityTests {
    private func makePaths() throws -> AppPaths {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-availability-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return paths
    }

    @Test("저장한 사진은 있다")
    func savedIsPresent() throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }
        let store = AttachmentStore(paths: paths)
        let path = try store.save(Data([0x89, 0x50]), fileExtension: "png")
        #expect(store.availability(of: path) == .present)
    }

    @Test("자리표만 있으면 오는 중이다 — 그리고 청한다")
    func placeholderIsDownloading() throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }
        let store = AttachmentStore(paths: paths)
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let placeholder = store.directory.appending(path: ".01K4ZR0000000000000000AA.png.icloud", directoryHint: .notDirectory)
        try Data().write(to: placeholder)

        #expect(store.availability(of: "attachments/01K4ZR0000000000000000AA.png") == .downloading)
    }

    @Test("파일도 자리도 없으면 없다 — Vault 밖을 가리키는 경로도 없다")
    func absentIsMissing() throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }
        let store = AttachmentStore(paths: paths)
        #expect(store.availability(of: "attachments/nope.png") == .missing)
        #expect(store.availability(of: "../etc/passwd") == .missing)
    }
}
