import Foundation
import Testing
@testable import LazyMemoCore

@MainActor
@Suite("MemoStore")
struct MemoStoreTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoStore(paths: paths), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    @Test("만들면 메모리와 파일에 동시에 생긴다")
    func createWritesFileAndMemory() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let memo = try await store.create(body: "치과 예약", tags: ["병원"])

        #expect(store.memos.map(\.id) == [memo.id])
        let onDisk = try await MemoVault(paths: paths).load(memo.id)
        #expect(onDisk.body == "치과 예약")
    }

    @Test("update 에서 지정하지 않은 필드는 보존된다")
    func updateKeepsUnspecifiedFields() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let memo = try await store.create(body: "원본", tags: ["태그"], color: .green)
        let updated = try await store.update(memo.id, body: "수정본")

        #expect(updated.body == "수정본")
        #expect(updated.tags == ["태그"])
        #expect(updated.color == .green)
        #expect(updated.created == memo.created)
        // 정본 파일이 초 단위까지만 적으므로 같은 초 안의 수정은 값이 같다.
        // "시각이 뒤로 가지 않는다"까지가 이 형식이 보장할 수 있는 전부다.
        #expect(updated.updated >= memo.updated)
    }

    @Test("삭제는 휴지통으로 가고 되돌릴 수 있다")
    func deleteAndRestoreRoundTrip() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let memo = try await store.create(body: "지웠다 살릴 메모")
        try await store.delete(memo.id)

        #expect(store.memos.isEmpty)
        #expect(store.trash.map(\.id) == [memo.id])

        try await store.restore(memo.id)

        #expect(store.memos.map(\.id) == [memo.id])
        #expect(store.trash.isEmpty)
    }

    @Test("검색이 인덱스를 타고 결과를 돌려준다")
    func searchGoesThroughIndex() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let target = try await store.create(body: "강남역 치과 예약")
        _ = try await store.create(body: "장보기 목록")

        #expect(await store.search("강남역").map(\.id) == [target.id])
        #expect(await store.search("없는말").isEmpty)
    }

    @Test("외부 프로세스가 쓴 파일을 reconcile 이 집어온다 — MCP 서버가 별도 프로세스인 근거")
    func picksUpExternallyWrittenFiles() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        // MCP 서버(다른 프로세스)가 Vault 에 직접 쓴 상황을 흉내 낸다.
        let external = Memo(body: "LLM 이 넣은 메모")
        let vault = MemoVault(paths: paths)
        try await vault.save(external)

        await store.reconcile()

        #expect(store.memos.map(\.id) == [external.id])
        #expect(await store.search("LLM").map(\.id) == [external.id])
    }

    @Test("파일이 사라지면 인덱스에서도 내려간다")
    func dropsMemosDeletedOnDisk() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let memo = try await store.create(body: "곧 사라질 메모")
        let vault = MemoVault(paths: paths)
        try FileManager.default.removeItem(at: await vault.url(for: memo.id))

        await store.reconcile()

        #expect(store.memos.isEmpty)
        #expect(await store.search("사라질").isEmpty)
    }

    @Test("고정한 메모가 목록 맨 위로 온다")
    func pinnedFloatsToTop() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let first = try await store.create(body: "먼저 만든 메모")
        _ = try await store.create(body: "나중에 만든 메모")
        _ = try await store.update(first.id, pinned: true)

        #expect(store.memos.first?.id == first.id)
    }

    @Test("인덱스를 통째로 지워도 파일에서 복원된다 — §5.3 불변식")
    func indexIsFullyDerivable() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let memo = try await store.create(body: "인덱스 없이도 살아남을 메모")
        store.stop()

        try FileManager.default.removeItem(at: paths.index)

        let rebuilt = try MemoStore(paths: paths)
        await rebuilt.reconcile()

        #expect(rebuilt.memos.map(\.id) == [memo.id])
        #expect(await rebuilt.search("살아남을").map(\.id) == [memo.id])
    }
}
