import Foundation
import Testing
@testable import LazyMemoCore

/// 규칙이 실제로 파일과 목록에 닿는가 (`{#auto-tidy}`).
///
/// `TidyRuleTests` 는 "무엇이 언제" 를 잰다. 여기서 재는 것은 그 판단이
/// **정말 파일에 적히고, 목록에서 빠지고, 한 번에 되돌아오는지**다 —
/// 규칙만 맞고 배선이 끊기면 사용자에게는 아무 일도 안 일어난다.
@MainActor
@Suite("스스로 물러나기 — 파일과 목록")
struct TidySweepTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-tidy-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    /// 나흘 뒤. 다 체크한 목록이 물러나기에 충분한 시간이다.
    private var laterEnough: Date { Date().addingTimeInterval(4 * 24 * 60 * 60) }

    @Test("다 끝난 목록은 목록에서 빠지지만 파일에는 그대로 있다 — 지운 것이 아니다")
    func tidiedLeavesTheListNotTheDisk() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let done = try await store.create(body: "장보기\n- [x] 우유\n- [x] 계란")
        let alive = try await store.create(body: "아직\n- [ ] 우산")

        await store.tidy(now: laterEnough)

        #expect(store.active.map(\.id) == [alive.id])
        #expect(store.tidiedMemos.map(\.id) == [done.id])
        // 정본은 그대로다 (D4).
        let onDisk = try await MemoVault(paths: paths).load(done.id)
        #expect(onDisk.body.contains("우유"))
        #expect(onDisk.tidied != nil)
    }

    @Test("치워도 검색으로는 나온다 — 못 찾게 되면 그건 삭제다")
    func tidiedIsStillFound() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let done = try await store.create(body: "장보기\n- [x] 우유")
        await store.tidy(now: laterEnough)

        let found = await store.search("장보기")
        #expect(found.map(\.id).contains(done.id))
    }

    @Test("«도로 꺼내기» 는 한 번에 전부 되돌린다")
    func untidyAllBringsEverythingBack() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        _ = try await store.create(body: "하나\n- [x] 끝")
        _ = try await store.create(body: "둘\n- [x] 끝")
        await store.tidy(now: laterEnough)
        #expect(store.active.isEmpty)

        await store.untidyAll()

        #expect(store.active.count == 2)
        #expect(store.tidiedMemos.isEmpty)
    }

    @Test("도로 꺼낸 것을 규칙이 다음 날 도로 치우지 않는다")
    func restoredStaysRestored() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let done = try await store.create(body: "장보기\n- [x] 우유")
        await store.tidy(now: laterEnough)
        await store.untidy(done.id)

        // 꺼낸 바로 다음 정리에서 도로 물러나면 사람 눈에는 고장이다.
        await store.tidy(now: Date().addingTimeInterval(24 * 60 * 60))

        #expect(store.active.map(\.id) == [done.id])
    }

    @Test("치워 둔 메모를 고치면 그 자리에서 도로 살아난다")
    func editingBringsItBack() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let done = try await store.create(body: "장보기\n- [x] 우유")
        await store.tidy(now: laterEnough)
        #expect(store.active.isEmpty)

        _ = try await store.update(done.id, body: "장보기\n- [x] 우유\n- [ ] 빵")

        #expect(store.active.map(\.id) == [done.id])
    }

    @Test("고정한 것은 정리가 지나가도 그대로 있다")
    func pinnedSurvivesTheSweep() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }

        let kept = try await store.create(body: "늘 보는 것\n- [x] 끝")
        _ = try await store.update(kept.id, pinned: true)

        await store.tidy(now: laterEnough)

        #expect(store.active.map(\.id) == [kept.id])
    }

    @Test("`tidied:` 는 파일을 왕복해도 남는다")
    func tidiedSurvivesRoundTrip() throws {
        let stamped = Date(timeIntervalSince1970: 1_777_000_000)
        let memo = Memo(body: "- [x] 끝", tidied: stamped)

        let decoded = try MemoFile.decode(MemoFile.encode(memo))

        #expect(decoded.tidied?.timeIntervalSince1970 == stamped.truncatingSubsecond.timeIntervalSince1970)
    }
}
