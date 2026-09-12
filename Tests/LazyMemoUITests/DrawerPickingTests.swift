import CoreGraphics
import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 서랍 안에서 **여러 장을 한꺼번에**, 그리고 **한 겹씩 되돌리기.**
///
/// 화면으로는 확인할 수 없는 것들이다. 「고른 세 장을 꺼냈다」와 「고른 세 장
/// 중 둘만 꺼냈다」는 그림이 같고(둘 다 무더기가 줄어든다), esc 가 몇 겹을
/// 벗겼는지는 렌더에 아무 흔적도 남기지 않는다 (§14.9).
@MainActor
@Suite("서랍 — 고르기와 되돌리기")
struct DrawerPickingTests {

    /// 창고 하나에 날짜 없는 종이 몇 장. **전부 치운 것으로 친다** — 좌표
    /// 파일이 없는 시험에서는 「사람이 치웠는가」를 물을 곳이 없다.
    private func drawer(_ bodies: [String]) async throws -> (DrawerModel, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-drawer-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        for body in bodies { _ = try await store.create(body: body) }
        return (DrawerModel(store: store, putAway: { _ in true }), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    // MARK: 고르기

    @Test("고르고 다시 누르면 놓는다")
    func pickingTogglesOne() async throws {
        let (model, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        let first = try #require(model.shown.first?.id)

        model.pick(first)
        #expect(model.picked == [first])
        model.pick(first)
        #expect(model.picked.isEmpty)
    }

    @Test("고른 것이 없으면 아무 말도 하지 않는다 — 「0장 골랐습니다」는 말이 아니다")
    func silentWithNothingPicked() async throws {
        let (model, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        #expect(model.pickedLabel == nil)
        model.pick(try #require(model.shown.first?.id))
        #expect(model.pickedLabel == "1장 골랐습니다")
    }

    /// 집합이 주는 차례대로 꺼내면 꺼낼 때마다 순서가 달라지고, 그러면
    /// «되돌렸다» 가 아니라 «흩뿌렸다» 가 된다.
    @Test("한꺼번에 꺼낼 때 차례는 무더기에 놓인 그대로다")
    func takingOutKeepsPileOrder() async throws {
        let (model, paths) = try await drawer(["하나", "둘", "셋", "넷"])
        defer { cleanUp(paths) }
        var takenOut: [ULID] = []
        model.onTakeOut = { takenOut.append($0) }

        let order = model.shown.map(\.id)
        for id in [order[2], order[0], order[3]] { model.pick(id) }
        model.takeOutPicked()

        #expect(takenOut == [order[0], order[2], order[3]])
        #expect(model.picked.isEmpty)
    }

    @Test("한꺼번에 지우면 고른 것만, 전부 지운다")
    func deletingPickedDeletesExactlyThose() async throws {
        let (model, paths) = try await drawer(["하나", "둘", "셋"])
        defer { cleanUp(paths) }
        var deleted: Set<ULID> = []
        model.onDelete = { deleted.insert($0) }

        let order = model.shown.map(\.id)
        model.pick(order[0])
        model.pick(order[2])
        model.deletePicked()

        #expect(deleted == [order[0], order[2]])
        #expect(model.picked.isEmpty)
    }

    /// **화면에 없는 종이에 조작이 걸리면 안 된다.** 골라 둔 채로 글자를 치면
    /// 걸러진 장이 무더기에서 사라지는데, 그것이 계속 골라진 채로 남아 있으면
    /// 「모두 꺼내기」가 사람이 보지 못하는 종이를 꺼낸다.
    @Test("찾기로 걸러진 장은 고르기에서도 빠진다")
    func filteringDropsPicked() async throws {
        let (model, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        // **차례를 짐작하지 않는다.** 창고의 차례는 최근순이고 같은 순간에
        // 만들어진 둘 사이에서는 갈리지 않는다 — 제목으로 집는다.
        let dentist = try #require(id(of: "치과", in: model))
        let groceries = try #require(id(of: "장보기", in: model))
        model.pick(dentist)
        model.pick(groceries)
        #expect(model.picked.count == 2)

        model.query = "치과"
        #expect(model.picked == [dentist])
    }

    @Test("짚어 둔 장도 걸러지면 놓는다")
    func filteringDropsFocus() async throws {
        let (model, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        model.focused = try #require(id(of: "장보기", in: model))
        model.query = "치과"
        #expect(model.focused == nil)
    }

    private func id(of title: String, in model: DrawerModel) -> ULID? {
        model.shown.first { $0.title == title }?.id
    }

    // MARK: 키보드로 훑기

    @Test("아무것도 안 짚었을 때 ↓ 는 맨 위부터, ↑ 는 맨 아래부터")
    func firstMoveEntersThePile() async throws {
        let (model, paths) = try await drawer(["하나", "둘", "셋"])
        defer { cleanUp(paths) }
        let order = model.shown.map(\.id)

        model.moveFocus(by: 1)
        #expect(model.focused == order.first)

        model.focused = nil
        model.moveFocus(by: -1)
        #expect(model.focused == order.last)
    }

    /// 끝에서 한 번 더 눌러도 **넘어가지 않는다.** 무더기를 감아 돌면 사람은
    /// 자기가 끝에 닿았다는 것을 알 수 없다.
    @Test("무더기 끝에서는 멈춘다")
    func focusStopsAtTheEdges() async throws {
        let (model, paths) = try await drawer(["하나", "둘"])
        defer { cleanUp(paths) }
        let order = model.shown.map(\.id)

        model.focused = order.last
        model.moveFocus(by: 1)
        #expect(model.focused == order.last)

        model.focused = order.first
        model.moveFocus(by: -1)
        #expect(model.focused == order.first)
    }

    /// 가려진 장은 아직 화면에 없다. 짚을 수 있게 두면 **보이지 않는 종이가
    /// 골라지고 지워진다.**
    @Test("아직 펼치지 않은 장은 짚히지 않는다")
    func focusStaysWithinTheStack() async throws {
        let (model, paths) = try await drawer((1...12).map { "종이 \($0)" })
        defer { cleanUp(paths) }
        #expect(model.geometry().stacked == DrawerGeometry.visible)

        for _ in 0..<20 { model.moveFocus(by: 1) }
        let stacked = model.shown.prefix(model.geometry().stacked).map(\.id)
        #expect(model.focused == stacked.last)
    }

    // MARK: 한 겹씩 되돌리기

    /// esc 한 번에 전부 지우면 세 글자를 찾다가 한 번 잘못 눌렀을 때 서랍이
    /// 통째로 닫힌다. 한 겹씩 벗겨야 되돌리기가 예측된다.
    @Test("esc 는 고르기 → 찾기 → 펼친 종이 → 짚은 자리 → 서랍 차례로 벗긴다")
    func escapePeelsOneLayerAtATime() async throws {
        let (model, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        let first = try #require(model.shown.first?.id)

        model.setOpen(true)
        model.query = "장"
        model.zoom(first)
        model.focused = first
        model.pick(first)

        model.escape()
        #expect(model.picked.isEmpty)
        #expect(model.isSearching)

        model.escape()
        #expect(!model.isSearching)
        #expect(model.zoomed == first)

        model.escape()
        #expect(model.zoomed == nil)
        #expect(model.focused == first)

        model.escape()
        #expect(model.focused == nil)
        #expect(model.isOpen)

        model.escape()
        #expect(!model.isOpen)
    }

    @Test("벗길 겹이 남았으면 esc 가 서랍을 닫지 않는다")
    func escapeWouldCloseOnlyAtTheBottom() async throws {
        let (model, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        model.setOpen(true)
        #expect(model.escapeWouldClose)

        model.query = "장"
        #expect(!model.escapeWouldClose)
    }

    /// 서랍은 늘 같은 모습으로 열린다. 접을 때 들고 있던 것을 그대로 두면
    /// 다음에 열었을 때 "내가 저걸 왜 저래 뒀지" 가 남는다.
    @Test("접으면 찾던 글자도 고른 것도 더 펼친 것도 놓는다")
    func closingPutsEverythingDown() async throws {
        let (model, paths) = try await drawer((1...12).map { "종이 \($0)" })
        defer { cleanUp(paths) }
        model.setOpen(true)
        model.query = "종이"
        model.pick(try #require(model.shown.first?.id))
        model.revealMore()

        model.setOpen(false)
        #expect(model.query.isEmpty)
        #expect(model.picked.isEmpty)
        #expect(model.focused == nil)
        #expect(model.geometry().stacked == DrawerGeometry.visible)
    }

    // MARK: 키 하나가 실제로 하는 일

    /// **「무엇에」가 없는 동작은 사람이 겨눈 적이 없는 동작이다.** 아무것도
    /// 안 짚었는데 ⌘⌫ 가 무언가를 지우면, 사람은 자기가 무엇을 지웠는지 알 수 없다.
    @Test("짚은 것이 없으면 ↩·⌘↩·⌘⌫ 는 아무 일도 하지 않는다")
    func keysWithoutATargetDoNothing() async throws {
        let (model, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        var touched = 0
        model.onDelete = { _ in touched += 1 }
        model.onTakeOut = { _ in touched += 1 }

        #expect(!model.handle(.zoom))
        #expect(!model.handle(.takeOut))
        #expect(!model.handle(.delete))
        #expect(touched == 0)
    }

    @Test("짚은 장에 ⌘↩ 는 꺼내고 ⌘⌫ 는 지운다")
    func keysActOnTheAimedPaper() async throws {
        let (model, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        var takenOut: [ULID] = []
        var deleted: [ULID] = []
        model.onTakeOut = { takenOut.append($0) }
        model.onDelete = { deleted.append($0) }

        let groceries = try #require(id(of: "장보기", in: model))
        model.focused = groceries
        #expect(model.handle(.takeOut))
        #expect(takenOut == [groceries])

        model.focused = try #require(id(of: "치과", in: model))
        #expect(model.handle(.delete))
        #expect(deleted == [try #require(id(of: "치과", in: model))])
    }

    /// 고른 것이 있으면 **고른 것이 이긴다.** 세 장을 골라 두고 ⌘⌫ 를 눌렀는데
    /// 짚은 한 장만 지워지면, 사람은 나머지 둘이 지워진 줄 알고 넘어간다.
    @Test("고른 것이 있으면 ⌘⌫ 는 고른 것 전부에 걸린다")
    func pickedWinsOverAimed() async throws {
        let (model, paths) = try await drawer(["하나", "둘", "셋"])
        defer { cleanUp(paths) }
        var deleted: Set<ULID> = []
        model.onDelete = { deleted.insert($0) }

        let order = model.shown.map(\.id)
        model.focused = order[0]
        model.pick(order[1])
        model.pick(order[2])

        #expect(model.handle(.delete))
        #expect(deleted == [order[1], order[2]])
    }

    @Test("더 펼칠 것이 없으면 + 는 흘려보낸다 — 맡지 않은 키는 삼키지 않는다")
    func revealIsIgnoredWhenNothingIsHidden() async throws {
        let (model, paths) = try await drawer(["하나", "둘"])
        defer { cleanUp(paths) }
        #expect(!model.handle(.revealMore))
    }

    // MARK: 더 보기

    /// 「그리고 N장 더」라고 적어 놓고 누를 수 없으면, 그 넉 장을 보려면 앞의
    /// 여덟 장을 먼저 꺼내야 한다. 말만 하고 길을 안 내는 것은 자른 것과 같다.
    @Test("더 보기를 누르면 여덟 장씩 더 펼쳐진다")
    func revealingGrowsThePile() async throws {
        let (model, paths) = try await drawer((1...20).map { "종이 \($0)" })
        defer { cleanUp(paths) }
        #expect(model.geometry().stacked == 8)
        #expect(model.geometry().scrolls)

        model.revealMore()
        #expect(model.geometry().stacked == 16)

        model.revealMore()
        #expect(model.geometry().stacked == 20)
        #expect(!model.geometry().scrolls)
    }

    /// 상한이 없으면 창이 화면 위아래로 빠져나가고, 그러면 §16.4 가 고쳐 둔
    /// 고장(「폴더가 있던 자리를 통째로 떠난다」)이 그대로 돌아온다.
    @Test("화면이 허락하는 것보다 더 펼치지 않는다 — 그래도 조용히 자르지는 않는다")
    func revealingStopsAtTheScreenEdge() async throws {
        let (model, paths) = try await drawer((1...40).map { "종이 \($0)" })
        defer { cleanUp(paths) }
        model.setCeiling(11)

        for _ in 0..<5 { model.revealMore() }
        #expect(model.geometry().stacked == 11)
        // 남은 것이 있다는 말은 계속 한다.
        #expect(DrawerContents.overflow(count: model.count, shown: 11) == "그리고 29장 더")
    }
}
