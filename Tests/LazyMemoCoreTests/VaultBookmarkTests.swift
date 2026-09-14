import Foundation
import Testing
@testable import LazyMemoCore

#if os(macOS)
/// 샌드박스 판이 고른 폴더에 다시 닿는 열쇠. 샌드박스 밖에서도 만들고 열 수
/// 있어야 두 판이 같은 설정 파일을 쓴다.
@Suite("VaultBookmark")
struct VaultBookmarkTests {
    private func makeRoot() throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-bookmark-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("만든 열쇠로 같은 폴더가 열린다")
    func opensTheSameFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = root.appending(path: "lazymemo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)

        let key = try #require(VaultBookmark.make(for: vault))
        let access = try #require(VaultBookmark.open(key))

        #expect(access.url.standardizedFileURL.resolvingSymlinksInPath()
                == vault.standardizedFileURL.resolvingSymlinksInPath())
        // 갓 만든 열쇠는 낡지 않았다.
        #expect(access.refreshed == nil)
    }

    @Test("폴더가 없어지면 열리지 않는다 — 조용히 다른 곳을 가리키지 않는다")
    func missingFolderDoesNotOpen() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = root.appending(path: "lazymemo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let key = try #require(VaultBookmark.make(for: vault))

        try FileManager.default.removeItem(at: vault)

        #expect(VaultBookmark.open(key) == nil)
    }

    @Test("열쇠는 설정 파일을 오간다")
    func roundTripsThroughSettings() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let vault = root.appending(path: "lazymemo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let key = try #require(VaultBookmark.make(for: vault))

        let settings = SettingsStore(
            location: support.appending(path: "settings.json", directoryHint: .notDirectory)
        )
        settings.update {
            $0.vaultPath = vault.path(percentEncoded: false)
            $0.vaultBookmark = key
        }

        let stored = try #require(Settings.storedVault(inSupport: support))
        #expect(stored.path == vault.path(percentEncoded: false))
        #expect(stored.bookmark == key)
    }
}
#endif
