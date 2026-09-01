import CoreGraphics
import LazyMemoCore
import Observation

/// 「서랍」이 들고 있는 것 — 어떤 종이가 들었고, 지금 무엇을 하고 있는가.
///
/// 창(`DrawerWindowController`)과 나눠 둔 이유는 `CalendarModel` 과 같다.
/// 서랍은 창이 닫혀 있는 동안에도 살아 있어야 한다 — 종이를 끌어다 놓는 손은
/// 서랍이 닫혀 있을 때 오고, 그때 몇 장이 들었는지를 폴더에 적어야 한다.
@MainActor
@Observable
final class DrawerModel {

    /// 서랍에 든 종이. 차례는 목록과 같다 (`DrawerContents.filter`).
    private(set) var papers: [Memo] = []

    /// 펼쳐져 있는가.
    private(set) var isOpen = false

    /// 지금 원래 크기로 되돌아와 있는 한 장. 없으면 전부 작은 채다.
    var zoomed: ULID?

    /// 지금 서랍 위에 떠 있는 종이 — 손을 놓으면 들어온다.
    ///
    /// 끌고 있는 것은 서랍이 아니라 **바탕화면의 창**이라 SwiftUI 가 알 길이
    /// 없다. 창을 지켜보는 쪽(`DrawerWindowController`)이 여기 적어 준다.
    var landing: ULID?

    /// 방금 한 일. 바닥 한 줄에 적혔다가 다음 일이 생기면 밀려난다.
    var lastFiled: Memo?

    /// 화면 밖 렌더에서만 채운다 (`PreviewRenderer`) — 펼친 모습도, 되돌린
    /// 종이도, 서랍 위에 떠 있는 종이도 전부 **손이 있어야만** 나타난다.
    var staged: Staged?

    struct Staged {
        var isOpen = false
        var zoomed: ULID?
        var hovered: ULID?
        var landing: ULID?
        var lastFiled: Memo?
    }

    private let store: MemoStore
    /// 이 종이를 사람이 치웠는가 (`layout.json`). 좌표는 파생물이라 모델이
    /// 직접 읽지 않고 바깥에서 받는다 — 시험이 창 없이 이 규칙을 물을 수 있게.
    private let putAway: (ULID) -> Bool
    /// 그 종이가 바탕화면에서 갖던 크기. 되돌릴 때 이 크기로 자란다.
    private let paperSize: (ULID) -> CGSize

    /// 서랍에서 도로 꺼낸다 — 바탕화면으로 돌려보낸다.
    var onTakeOut: (ULID) -> Void = { _ in }
    /// 지운다. 되돌리기는 메뉴에 있다 (D6).
    var onDelete: (ULID) -> Void = { _ in }
    /// 펼치고 접는 일은 창의 크기를 바꾸는 일이라 창이 맡는다.
    var onToggle: (Bool) -> Void = { _ in }

    init(
        store: MemoStore,
        putAway: @escaping (ULID) -> Bool,
        paperSize: @escaping (ULID) -> CGSize = { _ in DrawerGeometry.paperRoom }
    ) {
        self.store = store
        self.putAway = putAway
        self.paperSize = paperSize
        refresh()
    }

    // MARK: 들여다보기

    func refresh() {
        let held = DrawerContents.filter(store.memos) { putAway($0.id) }
        papers = held
        // 서랍에서 나간 종이를 계속 펼쳐 놓고 있을 수는 없다 — 꺼내기를
        // 누른 그 종이가 바로 그렇게 된다.
        if let zoomed, !held.contains(where: { $0.id == zoomed }) { self.zoomed = nil }
        if let filed = lastFiled, !held.contains(where: { $0.id == filed.id }) { lastFiled = nil }
    }

    var count: Int { papers.count }
    var title: String { DrawerContents.title(count: count) }

    /// 맨 위 종이 **아래로** 삐죽 나온 것들의 색. 세 장이면 충분하다 —
    /// 그 이상은 무더기가 아니라 색 띠가 된다.
    ///
    /// `dropFirst` 가 요점이다. 맨 위 한 장은 `DrawerView.topSheet` 가 이미
    /// 그리므로, 여기에 그것까지 넣으면 같은 종이가 두 번 그려지면서 **두께가
    /// 한 겹 사라진다** — 닫힌 무더기가 몇 장인지 말하는 유일한 수단이 그
    /// 두께인데.
    var peekingInks: [MemoColor] {
        Array(papers.dropFirst().prefix(3).map(\.color))
    }

    func geometry() -> DrawerGeometry { DrawerGeometry(count: count) }

    /// 이 종이를 되돌릴 크기.
    func fullSize(of id: ULID) -> CGSize {
        geometry().zoomed(paper: paperSize(id))
    }

    // MARK: 손짓

    func toggle() { setOpen(!isOpen) }

    func setOpen(_ open: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        // 접을 때 되돌린 종이를 들고 가지 않는다. 다음에 열었을 때 한 장이
        // 크게 펼쳐져 있으면 "내가 저걸 왜 열어 뒀지" 가 남는다.
        if !open { zoomed = nil }
        onToggle(open)
    }

    /// 누르면 원래 크기로, 한 번 더 누르면 도로 작아진다.
    func zoom(_ id: ULID) {
        zoomed = zoomed == id ? nil : id
    }

    func shrink() { zoomed = nil }

    /// 종이 한 장이 방금 서랍에 들어왔다.
    func received(_ memo: Memo) {
        lastFiled = memo
        refresh()
    }

    func takeOut(_ id: ULID) {
        if zoomed == id { zoomed = nil }
        if lastFiled?.id == id { lastFiled = nil }
        onTakeOut(id)
    }

    func delete(_ id: ULID) {
        if zoomed == id { zoomed = nil }
        onDelete(id)
    }

    // MARK: 연출값이 있으면 그것이 이긴다 (`PreviewRenderer`)

    var shownOpen: Bool { staged?.isOpen ?? isOpen }
    var shownZoomed: ULID? { staged?.zoomed ?? zoomed }
    var shownLanding: ULID? { staged?.landing ?? landing }
    var shownLastFiled: Memo? { staged?.lastFiled ?? lastFiled }
}
