import Foundation
import Testing
@testable import LazyMemoCore

/// 실패를 조용히 삼키지 않는다 (설계문서 §6 의 연장).
///
/// 저장 버튼이 없는 앱에서는 "적혔겠지" 가 기본 믿음이다. 쓰기가 실패해도
/// 글은 화면에 그대로 있으므로 적힌 것과 **똑같이 보이고**, 껐다 켠 뒤에야
/// 사라진 것을 안다. 한동안 `MemoStore` 는 실패를 적어 두기만 하고 읽는 곳이
/// 없었으며, 그나마도 **읽기 경로에만** 적혔다 — 정작 잃는 것은 쓰기인데.
@MainActor
@Suite("MemoStore — 실패는 화면까지 나간다")
struct MemoStoreTroubleTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-trouble-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    @Test("없는 메모에 쓰면 실패가 남는다 — 사람의 말과 기계의 말이 따로 있다")
    func recordsWriteFailure() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        #expect(store.trouble == nil)

        await #expect(throws: (any Error).self) {
            try await store.update(ULID(), body: "허공에 쓰기")
        }

        let trouble = try #require(store.trouble)
        // 메뉴에 그대로 적히는 줄이므로 사람의 말이어야 한다.
        #expect(trouble.doing == "메모를 저장하지 못했습니다")
        // 기계의 말은 도움말로만 나간다 — 비어 있으면 원인을 쫓을 길이 없다.
        #expect(!trouble.detail.isEmpty)
    }

    @Test("다시 성공하면 경고가 스스로 사라진다 — 낡은 경고는 안 읽힌다")
    func clearsTroubleOnSuccess() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        _ = try? await store.update(ULID(), body: "허공에 쓰기")
        #expect(store.trouble != nil)

        _ = try await store.create(body: "이번엔 된다")

        #expect(store.trouble == nil)
    }

    @Test("실패해도 그대로 던진다 — 부르는 쪽의 처리를 뺏지 않는다")
    func stillThrows() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        var threw = false
        do { _ = try await store.delete(ULID()) } catch { threw = true }

        #expect(threw)
        #expect(store.trouble?.doing == "메모를 지우지 못했습니다")
    }

    @Test("느린 길로 답을 낸 것은 실패가 아니다 — 검색은 경고를 올리지 않는다")
    func fallbackSearchIsNotTrouble() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "치과 예약")

        // 인덱스 파일을 통째로 치워도 파일 스캔으로 답이 나온다 (§5.3).
        try? FileManager.default.removeItem(at: paths.index)
        let found = await store.search("치과")

        #expect(found.count == 1)
        // 사용자가 찾던 것은 나왔다. 여기서 경고를 띄우면 그 경고는
        // 다음번 진짜 실패에서도 읽히지 않는다.
        #expect(store.trouble == nil)
    }
}
