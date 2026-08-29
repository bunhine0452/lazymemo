import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 빈 상자가 **요즘 메모를 들고 있는지** (설계문서 §8).
///
/// 이전에는 한 글자라도 쳐야 목록이 나왔다. 그래서 "무엇을 적어 뒀더라" 를
/// 확인하려는 사람은 기억해 낸 낱말을 먼저 대야 했는데, 기억이 안 나서 여는
/// 것이므로 그 길은 처음부터 막혀 있었다. 열자마자 보이고, 치면 그 자리가
/// 찾은 것으로 바뀌는 것 — 그 두 가지가 여기서 고정된다.
@MainActor
@Suite("빠른 입력 — 다른 메모로 가는 길")
struct CaptureBrowseTests {
    private func makeStore() throws -> MemoStore {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-browse-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return try MemoStore(paths: paths)
    }

    @discardableResult
    private func fill(_ store: MemoStore, _ bodies: [String]) async throws -> [Memo] {
        var made: [Memo] = []
        for body in bodies { made.append(try await store.create(body: body)) }
        return made
    }

    /// 검색은 디바운스(120ms)가 걸려 있다. 결과가 올 때까지만 기다린다.
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(300))
    }

    @Test("열면 적지 않아도 요즘 메모가 놓여 있다")
    func recentMemosAppearOnOpen() async throws {
        let store = try makeStore()
        try await fill(store, ["치과 예약", "전기요금", "은행"])
        let model = QuickCaptureModel(store: store)

        model.prepareForShow()

        #expect(model.listing == .recent)
        #expect(model.listed.count == 3)
        // 고른 것이 없어야 ⌘⏎ 가 새 메모를 만든다 — 열자마자 목록이 보인다고
        // 해서 적으러 온 사람의 길이 달라지면 안 된다.
        #expect(model.selection == nil)
    }

    @Test("↓ 로 고른 메모를 ⌘⏎ 가 연다")
    func selectedRecentMemoOpens() async throws {
        let store = try makeStore()
        let made = try await fill(store, ["치과 예약"])
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        model.moveSelection(1)

        #expect(model.selection == 0)
        guard case .open(let id) = model.commit() else {
            Issue.record("고른 메모를 열지 않았다")
            return
        }
        #expect(id == made[0].id)
    }

    @Test("치면 찾은 것으로 바뀌고, 지우면 도로 요즘 것이 된다")
    func typingSwitchesToSearchAndBack() async throws {
        let store = try makeStore()
        try await fill(store, ["치과 예약", "전기요금"])
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        model.query = "치과"
        await settle()
        #expect(model.listing == .found)
        #expect(model.listed.map(\.title) == ["치과 예약"])

        model.query = ""
        await settle()
        #expect(model.listing == .recent)
        #expect(model.listed.count == 2)
    }

    @Test("요즘 목록은 다섯 장을 넘지 않는다 — 목록이 적을 자리를 밀어내면 안 된다")
    func recentListStaysShort() async throws {
        let store = try makeStore()
        try await fill(store, (1...9).map { "메모 \($0)" })
        let model = QuickCaptureModel(store: store)

        model.prepareForShow()

        #expect(model.listed.count == 5)
    }

    @Test("목록이 줄어들면 고른 자리도 따라 줄어든다")
    func selectionStaysInsideTheList() async throws {
        let store = try makeStore()
        try await fill(store, ["치과 예약", "전기요금", "은행"])
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        model.moveSelection(1)
        model.moveSelection(1)
        model.moveSelection(1)
        #expect(model.selection == 2)

        // 찾은 것이 하나뿐이면 세 번째 자리는 없어진다.
        model.query = "치과"
        await settle()

        #expect(model.selection == 0)
        #expect(model.listed.count == 1)
    }

    @Test("메모가 없으면 목록도 없다 — 빈 줄만 늘어놓지 않는다")
    func emptyVaultShowsNothing() throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)

        model.prepareForShow()

        #expect(model.listed.isEmpty)
    }
}
