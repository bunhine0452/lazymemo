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

    /// 서랍에 든 종이 **전부.** 차례는 목록과 같다 (`DrawerContents.filter`).
    private(set) var papers: [Memo] = []

    /// 찾는 글자. 비어 있으면 아무것도 거르지 않는다 (`DrawerSearch`).
    ///
    /// **아무것도 남기지 않는 상태다.** 글자를 지우면 무더기가 그대로 돌아오고,
    /// 파일에도 좌표에도 흔적이 없다 — 찾기가 분류가 되지 않는 이유다 (§16.1).
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            // 걸러진 뒤에도 짚고 있던 것이 남아 있는지 다시 본다.
            prune()
            onLayoutChanged()
        }
    }

    /// 지금 무더기에 놓인 것 — 찾기를 통과한 것들.
    ///
    /// `shownQuery` 를 보는 이유는 화면 밖 렌더 때문이다 — 렌더는 글 상자에
    /// 글자를 넣을 수 없으므로 연출값으로 «찾는 중» 을 세운다 (`Staged`).
    var shown: [Memo] { DrawerSearch.filter(papers, query: shownQuery) }

    /// 고른 장. **여러 장을 한꺼번에 꺼내거나 지우기 위한 것뿐이다** —
    /// 서랍을 닫으면 사라지고 파일에는 남지 않는다.
    private(set) var picked: Set<ULID> = []

    /// 키보드가 짚고 있는 한 장. 손이 얹힌 것과 **같은 표시를 쓴다** —
    /// 두 곳에서 같은 일을 다르게 그리면 두 개의 물건이 된다 (§14.10).
    var focused: ULID?

    /// 몇 장까지 겹쳐 놓는가. 「그리고 N장 더」를 누르면 늘어난다.
    private(set) var limit = DrawerGeometry.visible

    /// 이 화면에서 겹칠 수 있는 최대 장수. 창이 정해 준다 (`DrawerGeometry.limit`).
    var ceiling = Int.max

    /// 판형이 바뀌었다 — 창이 따라 자라거나 줄어야 한다.
    var onLayoutChanged: () -> Void = {}

    /// 찾기 줄에 **지금 커서가 있는가.**
    ///
    /// 뷰가 적어 준다. 창이 응답 사슬(`firstResponder`)을 뒤져 짐작할 수도
    /// 있지만, SwiftUI 가 글 상자를 무엇으로 만드는지는 판마다 다르고 **틀려도
    /// 화면에 아무 표가 안 난다.** 틀렸을 때의 값이 비싸다 — 「찾는 중이 아니다」로
    /// 잘못 읽으면 질의에 띄어쓰기를 넣는 스페이스가 **종이를 고르는 키**가 된다
    /// (`DrawerKeys`). 커서가 어디 있는지는 `@FocusState` 만 확실히 안다.
    var isEditingSearch = false

    /// 커서를 옮겨 달라는 부탁. **커서를 옮기는 일은 뷰만 할 수 있으므로**
    /// (`@FocusState`) 모델은 부르기만 하고 뷰가 그것을 보고 옮긴다.
    ///
    /// 값이 아니라 **셈**인 이유: 같은 부탁이 두 번 올 수 있다(⌘F 를 두 번).
    /// 값으로 두면 두 번째가 변화로 읽히지 않아 아무 일도 일어나지 않는다.
    private(set) var focusRequest = (count: 0, wantsSearch: true)

    /// ⌘F — 커서를 찾기 줄로.
    func inviteSearch() { focusRequest = (focusRequest.count + 1, true) }
    /// 찾기 줄에서 빠져나온다 — 커서를 무더기로 돌려준다.
    func releaseSearch() { focusRequest = (focusRequest.count + 1, false) }

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
        /// 찾는 중인 모습. 화면 밖 렌더는 글 상자에 커서를 놓을 수 없다.
        var query: String?
        /// 골라 둔 모습.
        var picked: Set<ULID> = []
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
        if let filed = lastFiled, !held.contains(where: { $0.id == filed.id }) { lastFiled = nil }
        prune()
    }

    /// **지금 무더기에 없는 것을 계속 짚고 있지 않는다.**
    ///
    /// 셋이 같은 이유로 정리된다 — 펼쳐 둔 장, 짚어 둔 장, 골라 둔 장. 서랍에서
    /// 나갔거나 찾기에 걸러진 종이를 계속 들고 있으면, 「꺼내기」가 **화면에
    /// 없는 종이**에 걸린다. 사람은 자기가 무엇을 꺼냈는지 알 수 없다.
    private func prune() {
        let alive = Set(shown.map(\.id))
        if let zoomed, !alive.contains(zoomed) { self.zoomed = nil }
        if let focused, !alive.contains(focused) { self.focused = nil }
        picked.formIntersection(alive)
    }

    /// **무더기에 있는 장수** — 찾는 중이면 걸러진 수다.
    var count: Int { shown.count }
    /// 서랍이 들고 있는 전부. 찾기와 무관하다.
    var total: Int { papers.count }
    var title: String { DrawerContents.title(count: total) }

    /// 찾은 결과를 한 줄로. 찾는 중이 아니면 `nil` (`DrawerSearch.summary`).
    var searchSummary: String? {
        DrawerSearch.summary(query: shownQuery, found: count)
    }

    /// 찾는 중인가 — 글자가 들어 있으면 그렇다.
    var isSearching: Bool { !shownQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    /// 고른 장수를 한 줄로. 고른 것이 없으면 `nil`.
    var pickedLabel: String? { DrawerContents.picked(count: shownPicked.count) }

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

    func geometry() -> DrawerGeometry {
        DrawerGeometry(count: count, limit: min(limit, ceiling))
    }

    /// 이 종이를 되돌릴 크기.
    func fullSize(of id: ULID) -> CGSize {
        geometry().zoomed(paper: paperSize(id))
    }

    // MARK: 손짓

    func toggle() { setOpen(!isOpen) }

    func setOpen(_ open: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        // 접을 때는 **들고 있던 것을 전부 내려놓는다.** 다음에 열었을 때 한 장이
        // 크게 펼쳐져 있거나, 찾던 글자가 남아 있거나, 세 장이 골라진 채이면
        // "내가 저걸 왜 저래 뒀지" 가 남는다. 서랍은 늘 같은 모습으로 열린다.
        if !open {
            zoomed = nil
            focused = nil
            picked.removeAll()
            query = ""
            limit = DrawerGeometry.visible
        }
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
        if focused == id { focused = nil }
        picked.remove(id)
        onDelete(id)
    }

    // MARK: 여러 장을 한꺼번에

    /// 한 장을 고르기에 넣거나 뺀다.
    func pick(_ id: ULID) {
        if picked.contains(id) { picked.remove(id) } else { picked.insert(id) }
    }

    func clearPicked() { picked.removeAll() }

    /// **고른 것을 한꺼번에 되돌린다.**
    ///
    /// 차례가 요점이다. 무더기에 놓인 차례 그대로 꺼내야 바탕화면에서도 같은
    /// 차례로 선다 — 집합(`Set`)이 주는 차례대로 부르면 꺼낼 때마다 순서가
    /// 달라지고, 그러면 «되돌렸다» 가 아니라 «흩뿌렸다» 가 된다.
    func takeOutPicked() {
        for id in orderedPicked { takeOut(id) }
        picked.removeAll()
    }

    /// 고른 것을 한꺼번에 지운다. 되돌리기는 메뉴에 있다 (D6).
    func deletePicked() {
        for id in orderedPicked { onDelete(id) }
        if let zoomed, picked.contains(zoomed) { self.zoomed = nil }
        if let focused, picked.contains(focused) { self.focused = nil }
        picked.removeAll()
    }

    private var orderedPicked: [ULID] {
        shown.map(\.id).filter { picked.contains($0) }
    }

    // MARK: 키보드로 훑기

    /// 무더기를 한 장 위아래로 짚는다. 아직 아무것도 안 짚었으면 **맨 위부터.**
    func moveFocus(by step: Int) {
        let ids = shown.prefix(geometry().stacked).map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = focused, let index = ids.firstIndex(of: current) else {
            focused = step < 0 ? ids.last : ids.first
            return
        }
        let next = min(max(index + step, 0), ids.count - 1)
        focused = ids[next]
    }

    /// **한 겹만 되돌린다** — 고르기 → 찾기 → 펼친 종이 → 짚은 자리 → 서랍.
    ///
    /// esc 한 번에 전부 지우면 세 글자를 찾다가 한 번 잘못 눌렀을 때 서랍이
    /// 통째로 닫힌다. 한 겹씩 벗겨야 되돌리기가 예측된다.
    /// esc 를 한 번 더 누르면 **서랍이 닫히는가.** 벗길 겹이 남았으면 아니다.
    ///
    /// 창이 이것을 묻는 이유: 글 상자에 커서가 있을 때의 마지막 esc 는
    /// 「서랍을 닫아라」가 아니라 「상자에서 빠져나가라」다 (`DrawerWindowController.handle`).
    var escapeWouldClose: Bool {
        picked.isEmpty && !isSearching && zoomed == nil && focused == nil
    }

    func escape() {
        if !picked.isEmpty { picked.removeAll(); return }
        if isSearching { query = ""; return }
        if zoomed != nil { zoomed = nil; return }
        if focused != nil { focused = nil; return }
        setOpen(false)
    }

    /// 가려진 장을 한 쪽 더 펼친다 (`DrawerContents.page`).
    func revealMore() {
        limit = min(max(limit + DrawerContents.page, DrawerGeometry.visible), ceiling)
        onLayoutChanged()
    }

    /// 이 화면이 허락하는 최대 장수를 창이 알려 준다.
    func setCeiling(_ value: Int) {
        guard value != ceiling else { return }
        ceiling = value
        onLayoutChanged()
    }

    /// 키 하나를 받아 처리했으면 `true`. 문법은 `DrawerKeys` 가 정한다.
    ///
    /// 짚은 것이 없을 때의 ↩·⌘⌫ 는 **아무 일도 하지 않는다** — 「무엇에」가
    /// 없는 동작은 사람이 겨눈 적이 없는 동작이다.
    func handle(_ intent: DrawerKeys.Intent) -> Bool {
        switch intent {
        case .move(let step):
            moveFocus(by: step)
        case .zoom:
            guard let target = focused ?? zoomed else { return false }
            zoom(target)
        case .takeOut:
            if !picked.isEmpty {
                takeOutPicked()
            } else if let one = aimed {
                takeOut(one)
            } else {
                return false
            }
        case .delete:
            if !picked.isEmpty {
                deletePicked()
            } else if let one = aimed {
                delete(one)
            } else {
                return false
            }
        case .pick:
            guard let target = focused else { return false }
            pick(target)
        case .search:
            return false   // 커서를 옮기는 일은 뷰가 한다 (`DrawerView.searchFocused`).
        case .back:
            escape()
        case .revealMore:
            guard geometry().scrolls else { return false }
            revealMore()
        }
        return true
    }

    /// 지금 조작이 걸리는 한 장 — 펼쳐 둔 것이 있으면 그것, 아니면 짚은 것.
    private var aimed: ULID? { zoomed ?? focused }

    // MARK: 연출값이 있으면 그것이 이긴다 (`PreviewRenderer`)

    var shownOpen: Bool { staged?.isOpen ?? isOpen }
    var shownZoomed: ULID? { staged?.zoomed ?? zoomed }
    var shownLanding: ULID? { staged?.landing ?? landing }
    var shownLastFiled: Memo? { staged?.lastFiled ?? lastFiled }
    var shownQuery: String { staged?.query ?? query }
    var shownPicked: Set<ULID> { staged.map { $0.picked } ?? picked }
}
