import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MemoService.modify")
struct MemoServiceModifyTests {
    func makeService() throws -> (MemoService, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-modify-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        return (try MemoService(paths: paths), paths)
    }
    func cleanUp(_ paths: AppPaths) { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

    @Test("hash 가 맞으면 바꾸고, 인덱스에도 반영된다")
    func modifiesWhenHashMatches() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "원본", tags: ["a"])
        let changed = try await service.modify(memo.id, expectedHash: memo.contentHash) { $0.folder = "일" }
        #expect(changed.folder == "일")
        #expect(changed.tags == ["a"])
        #expect(try await service.get(memo.id).folder == "일")
    }

    @Test("hash 가 다르면 changed 를 던지고 파일은 그대로")
    func refusesWhenHashDiffers() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "원본")
        await #expect(throws: MemoVault.Failure.self) {
            try await service.modify(memo.id, expectedHash: Memo.contentHash(of: "다른 글")) { $0.body = "덮어씀" }
        }
        #expect(try await service.get(memo.id).body == "원본")
    }

    @Test("expectedHash 가 nil 이면 대조 없이 바꾼다")
    func nilHashSkipsCheck() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "원본")
        let changed = try await service.modify(memo.id, expectedHash: nil) { $0.pinned = true }
        #expect(changed.pinned)
    }

    @Test("휴지통 이동도 hash 를 대조한다")
    func deleteChecksHash() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "원본")
        await #expect(throws: MemoVault.Failure.self) {
            try await service.delete(memo.id, expectedHash: "0000")
        }
        #expect(try await service.all().count == 1)
        _ = try await service.delete(memo.id, expectedHash: memo.contentHash)
        #expect(try await service.all().isEmpty)
    }
}
