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


    /// 화살표로 그 제목의 줄까지 내려간다.
    ///
    /// 자리 번호로 고르면 정렬이 바뀌는 순간 시험이 **엉뚱한 것을 고른 채로**
    /// 통과한다 — 요즘 목록은 최근 손댄 순이라 만든 차례의 역순이다.
    private func chooseRow(titled title: String, in model: QuickCaptureModel) {
        guard let index = model.listed.firstIndex(where: { $0.title == title }) else {
            Issue.record("목록에 「\(title)」 이 없다")
            return
        }
        for _ in 0...index { model.moveSelection(1) }
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
        await settle("찾은 것이 오지 않았다") { model.listing == .found }
        #expect(model.listed.map(\.title) == ["치과 예약"])

        model.query = ""
        await settle("요즘 것으로 안 돌아왔다") { model.listing == .recent }
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

    // MARK: 스무 장 너머 (`{#capture-more}`, `{#search-limit-raise}`)

    @Test("끊긴 자리에 몇 장이 남았는지 적는다 — 목록이 조용히 잘리지 않는다")
    func countsWhatItCouldNotShow() async throws {
        let store = try makeStore()
        try await fill(store, (1...9).map { "메모 \($0)" })
        let model = QuickCaptureModel(store: store)

        model.prepareForShow()

        // 다섯 줄만 보이지만 아홉 장이 있다는 것은 앱이 알고 있어야 한다.
        #expect(model.overflow == .more(4))
    }

    @Test("넓히면 스무 장까지 보인다")
    func expandsBeyondTheShortList() async throws {
        let store = try makeStore()
        try await fill(store, (1...9).map { "메모 \($0)" })
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        model.expand()

        #expect(model.listed.count == 9)
        #expect(model.overflow == nil)
    }

    @Test("스무 장을 넘으면 넓혀도 남는다 — 그때는 낱말로 좁히라고 적는다")
    func saysWhenEvenWideIsNotEnough() async throws {
        let store = try makeStore()
        try await fill(store, (1...24).map { "메모 \($0)" })
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        model.expand()

        #expect(model.listed.count == QuickCaptureModel.expandedLimit)
        #expect(model.overflow == .tooMany(4))
    }

    @Test("마지막 줄에서 ↓ 를 한 번 더 누르면 넓어지고 다음 줄로 내려간다")
    func oneMoreDownAtTheEndWidensTheList() async throws {
        let store = try makeStore()
        try await fill(store, (1...9).map { "메모 \($0)" })
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        // 다섯 줄을 지나 마지막 줄까지 내려간다.
        for _ in 1...5 { model.moveSelection(1) }
        #expect(model.selection == 4)

        model.moveSelection(1)

        #expect(model.isExpanded)
        // 넓어진 목록의 여섯째 줄이 골라져 있다 — 손이 멈추지 않는다.
        #expect(model.selection == 5)
    }

    @Test("다 보이는 목록에서는 ↓ 가 예전처럼 선택을 놓는다")
    func downStillReleasesWhenNothingIsHidden() async throws {
        let store = try makeStore()
        try await fill(store, ["치과 예약", "은행"])
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        for _ in 1...2 { model.moveSelection(1) }
        #expect(model.selection == 1)

        model.moveSelection(1)

        // 아래로 벗어나면 "선택 없음" — 그때 ⌘⏎ 는 새 메모를 만든다.
        #expect(model.selection == nil)
        #expect(!model.isExpanded)
    }

    @Test("찾은 것도 다섯 장에서 끊기지 않는다")
    func searchIsNoLongerCappedAtFive() async throws {
        let store = try makeStore()
        try await fill(store, (1...12).map { "장보기 \($0)" })
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()

        model.query = "장보기"
        // 목록의 성격이 바뀌는 것을 기다린다. «열두 장» 은 기다릴 조건이
        // 못 된다 — 요즘 목록에도 이미 열두 장이 들어 있다.
        await settle("찾은 것이 오지 않았다") { model.listing == .found }

        #expect(model.listing == .found)
        // 예전에는 인덱스에서 다섯 줄만 들고 와서 여섯 번째가 있는지조차 몰랐다.
        #expect(model.overflow == .more(7))
        model.expand()
        #expect(model.listed.count == 12)
    }

    @Test("낱말이 바뀌면 넓혀 둔 것이 도로 접힌다 — 새 목록은 다른 물건이다")
    func newWordsCollapseTheList() async throws {
        let store = try makeStore()
        try await fill(store, (1...9).map { "메모 \($0)" })
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        model.expand()
        #expect(model.isExpanded)

        model.query = "메모"
        await settle("찾은 것이 오지 않았다") { model.listing == .found }

        #expect(!model.isExpanded)
        #expect(model.listed.count == 5)
    }

    @Test("목록이 갈리면 고른 것을 놓는다 — 고른 적 없는 메모가 골라져 있으면 안 된다")
    func dropsSelectionWhenItLeavesTheList() async throws {
        let store = try makeStore()
        try await fill(store, ["치과 예약", "전기요금", "은행"])
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        chooseRow(titled: "은행", in: model)
        let picked = model.selectedID
        #expect(picked != nil)

        // 찾은 것이 하나뿐이면 골라 둔 「은행」은 목록에서 사라진다.
        model.query = "치과"
        await settle("찾은 것이 한 장이 되지 않았다") { model.listed.count == 1 }
        #expect(model.listed[0].id != picked)

        // 예전에는 자리를 맞춰 첫 줄로 **밀어 넣었다.** 그러면 ⌘⏎ 가
        // 고른 적 없는 「치과 예약」을 연다. 놓는 것이 맞다 — 그때 ⌘⏎ 는
        // 친 낱말로 새 메모를 만든다.
        #expect(model.selection == nil)
        guard case .create = model.commit() else {
            Issue.record("고른 적 없는 메모를 열려고 한다")
            return
        }
    }

    @Test("낱말을 도로 지워도 놓은 선택은 되살아나지 않는다")
    func doesNotResurrectDroppedSelection() async throws {
        let store = try makeStore()
        try await fill(store, ["치과 예약", "전기요금", "은행"])
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        chooseRow(titled: "은행", in: model)

        model.query = "치과"
        await settle("찾은 것이 오지 않았다") { model.listing == .found }
        model.query = ""
        await settle("요즘 것으로 안 돌아왔다") { model.listing == .recent }

        // 화면에서 사라진 선택을 몰래 들고 있다가 되돌려 주면, 사용자는
        // 아무것도 고르지 않은 상자에서 ⌘⏎ 를 눌러 남의 메모를 열게 된다.
        #expect(model.listed.count == 3)
        #expect(model.selection == nil)
    }

    @Test("메모가 없으면 목록도 없다 — 빈 줄만 늘어놓지 않는다")
    func emptyVaultShowsNothing() throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)

        model.prepareForShow()

        #expect(model.listed.isEmpty)
    }
}
