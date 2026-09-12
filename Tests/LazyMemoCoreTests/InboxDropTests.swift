import Foundation
import Testing
@testable import LazyMemoCore

/// 공유 확장이 지나는 문 — 인덱스 없이 정본 한 장.
@Suite("InboxDrop — 앱 밖에서 떨구기")
struct InboxDropTests {
    private func makePaths() throws -> AppPaths {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-drop-\(UUID().uuidString)", directoryHint: .isDirectory)
        return AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
    }

    @Test("떨군 글이 다른 문과 같은 규칙으로 읽혀 파일이 된다")
    func dropsAParsedFile() async throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let memo = try await InboxDrop.drop(
            InboundNote(text: "내일 3시 치과 @강남역"), into: paths, now: now
        )

        #expect(memo.at != nil)
        #expect(memo.place == "강남역")
        #expect(memo.body == "치과")
        let loaded = try await MemoVault(paths: paths).load(memo.id)
        #expect(loaded == memo)
    }

    @Test("인덱스는 만들지 않는다 — 그것은 앱의 몫이다")
    func leavesNoIndexBehind() async throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

        try await InboxDrop.drop(InboundNote(text: "우유"), into: paths)

        #expect(!FileManager.default.fileExists(atPath: paths.index.path(percentEncoded: false)))
    }

    @Test("iCloud 가 없으면 App Group 폴더가 Vault 다 — 확장과 앱이 같은 곳을 본다")
    func sharedGroupIsTheLocalVault() {
        let group = URL(filePath: "/tmp/lazymemo-test/group", directoryHint: .isDirectory)
        let resolved = AppPaths.resolveCloud(container: nil, shared: group, environment: [:])

        #expect(!resolved.usingCloud)
        #expect(resolved.paths.vault.path(percentEncoded: false) == "/tmp/lazymemo-test/group/lazymemo/")
    }

    @Test("iCloud 가 있으면 App Group 보다 컨테이너가 먼저다")
    func cloudBeatsGroup() {
        let group = URL(filePath: "/tmp/lazymemo-test/group", directoryHint: .isDirectory)
        let container = URL(filePath: "/tmp/lazymemo-test/iCloud~lazymemo", directoryHint: .isDirectory)
        let resolved = AppPaths.resolveCloud(container: container, shared: group, environment: [:])

        #expect(resolved.usingCloud)
        #expect(resolved.paths.vault.path(percentEncoded: false) == "/tmp/lazymemo-test/iCloud~lazymemo/Documents/")
    }
}
