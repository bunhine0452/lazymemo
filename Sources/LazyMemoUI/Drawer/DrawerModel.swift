import CoreGraphics
import LazyMemoCore
import Observation

/// 「서랍」이 들고 있는 것 — 어떤 종이가 들었고, 어느 폴더를 보고 있고, 지금
/// 무엇을 하고 있는가.
///
/// 창(`DrawerWindowController`)과 나눠 둔 이유는 `CalendarModel` 과 같다.
/// 서랍은 창이 닫혀 있는 동안에도 살아 있어야 한다 — 종이를 끌어다 놓는 손은
/// 서랍이 닫혀 있을 때 오고, 그때 몇 장이 들었는지를 탭에 적어야 한다.
@MainActor
@Observable
final class DrawerModel {

    /// 서랍에 든 종이 **전부.** 차례는 목록과 같다 (`DrawerContents.filter`).
    private(set) var papers: [Memo] = []

    /// 폴더 이름들 — 설정의 차례에 메모에만 있는 이름을 더한 것 (`MemoFolders.names`).
    private(set) var folders: [String] = []

    /// 지금 보고 있는 폴더. `nil` 은 「전체」다.
    var selectedFolder: String? {
        didSet {
            guard selectedFolder != oldValue else { return }
            // 칸을 옮기면 짚은 것도 펼친 것도 그 칸의 것이 아니다.
            prune()
            onLayoutChanged()
        }
    }

    /// 찾는 글자. 비어 있으면 아무것도 거르지 않는다 (`DrawerSearch`).
    ///
    /// **아무것도 남기지 않는 상태다.** 글자를 지우면 목록이 그대로 돌아오고,
    /// 파일에도 좌표에도 흔적이 없다 — 찾기가 분류가 되지 않는 이유다 (§16.1).
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            prune()
            onLayoutChanged()
        }
    }

    /// 지금 목록에 놓인 것 — 폴더와 찾기를 통과한 것들.
    ///
    /// `shownQuery`·`shownFolder` 를 보는 이유는 화면 밖 렌더 때문이다 — 렌더는
    /// 글 상자에 글자를 넣을 수 없으므로 연출값으로 «찾는 중» 을 세운다 (`Staged`).
    var shown: [Memo] {
        DrawerSearch.filter(MemoFolders.filter(papers, folder: shownFolder), query: shownQuery)
    }

    /// 고른 줄. **여러 장을 한꺼번에 꺼내거나 옮기거나 지우기 위한 것뿐이다** —
    /// 서랍을 닫으면 사라지고 파일에는 남지 않는다.
    private(set) var picked: Set<ULID> = []

    /// 키보드가 짚고 있는 한 줄. 손이 얹힌 것과 **같은 표시를 쓴다** —
    /// 두 곳에서 같은 일을 다르게 그리면 두 개의 물건이 된다 (§14.10).
    var focused: ULID?

    /// 펼쳐 둔 한 줄 — 본문 전부와 조작이 그 줄 아래 나온다.
    var expanded: ULID? {
        didSet { if expanded != oldValue { onLayoutChanged() } }
    }

    /// 새 폴더 이름을 적는 중인가.
    var isNamingFolder = false {
        didSet { if isNamingFolder != oldValue { onLayoutChanged() } }
    }
    /// 이름을 바꾸는 중인 폴더.
    var renamingFolder: String?

    /// 목록에 허락된 최대 높이. 창이 화면을 보고 정해 준다 (`DrawerGeometry.listCeiling`).
    var ceiling: CGFloat = .greatestFiniteMagnitude

    /// 판형이 바뀌었다 — 창이 따라 자라거나 줄어야 한다.
    var onLayoutChanged: () -> Void = {}

    /// 글 상자(찾기·폴더 이름)에 **지금 커서가 있는가.**
    ///
    /// 뷰가 적어 준다. 창이 응답 사슬(`firstResponder`)을 뒤져 짐작할 수도
    /// 있지만, SwiftUI 가 글 상자를 무엇으로 만드는지는 판마다 다르고 **틀려도
    /// 화면에 아무 표가 안 난다.** 틀렸을 때의 값이 비싸다 — 「찾는 중이 아니다」로
    /// 잘못 읽으면 질의에 띄어쓰기를 넣는 스페이스가 **줄을 고르는 키**가 된다
    /// (`DrawerKeys`). 커서가 어디 있는지는 `@FocusState` 만 확실히 안다.
    var isEditingSearch = false

    /// 커서를 옮겨 달라는 부탁. **커서를 옮기는 일은 뷰만 할 수 있으므로**
    /// (`@FocusState`) 모델은 부르기만 하고 뷰가 그것을 보고 옮긴다.
    ///
    /// 값이 아니라 **셈**인 이유: 같은 부탁이 두 번 올 수 있다(⌘F 를 두 번).
    private(set) var focusRequest = (count: 0, wantsSearch: true)

    /// ⌘F — 커서를 찾기 줄로.
    func inviteSearch() { focusRequest = (focusRequest.count + 1, true) }
    /// 찾기 줄에서 빠져나온다 — 커서를 목록으로 돌려준다.
    func releaseSearch() { focusRequest = (focusRequest.count + 1, false) }

    /// 펼쳐져 있는가.
    private(set) var isOpen = false

    /// 지금 서랍 위에 떠 있는 종이 — 손을 놓으면 들어온다.
    ///
    /// 끌고 있는 것은 서랍이 아니라 **바탕화면의 창**이라 SwiftUI 가 알 길이
    /// 없다. 창을 지켜보는 쪽(`DrawerWindowController`)이 여기 적어 준다.
    var landing: ULID?

    /// 방금 한 일. 바닥 한 줄에 적혔다가 다음 일이 생기면 밀려난다.
    var lastFiled: Memo?

    /// 화면 밖 렌더에서만 채운다 (`PreviewRenderer`) — 펼친 모습도, 손이 얹힌
    /// 줄도, 서랍 위에 떠 있는 종이도 전부 **손이 있어야만** 나타난다.
    var staged: Staged?

    struct Staged {
        var isOpen = false
        var expanded: ULID?
        var hovered: ULID?
        var landing: ULID?
        var lastFiled: Memo?
        /// 찾는 중인 모습. 화면 밖 렌더는 글 상자에 커서를 놓을 수 없다.
        var query: String?
        /// 어느 폴더를 보고 있는 모습. `nil` 은 「전체」.
        var folder: String?
        /// 골라 둔 모습.
        var picked: Set<ULID> = []
        /// 새 폴더 이름을 적는 모습.
        var naming = false
    }

    private let store: MemoStore
    /// 이 종이를 사람이 치웠는가 (`layout.json`). 좌표는 파생물이라 모델이
    /// 직접 읽지 않고 바깥에서 받는다 — 시험이 창 없이 이 규칙을 물을 수 있게.
    private let putAway: (ULID) -> Bool
    /// 설정에 적힌 폴더 차례. 바뀌면 `onFoldersChanged` 로 돌려준다.
    private var listedFolders: [String]
    /// 이름을 바꾸거나 없애서 **물러나는 중인** 폴더. 이름표를 떼는 일은
    /// 파일마다 비동기라, 그 사이 메모가 옛 이름표를 달고 있으면 없앤 폴더가
    /// 한 박자 더 서 있다 — 마지막 이름표가 떨어질 때까지 보이지 않게 한다.
    private var retired: Set<String> = []

    /// 서랍에서 도로 꺼낸다 — 바탕화면으로 돌려보낸다.
    var onTakeOut: (ULID) -> Void = { _ in }
    /// 지운다. 되돌리기는 메뉴에 있다 (D6).
    var onDelete: (ULID) -> Void = { _ in }
    /// 펼치고 접는 일은 창의 크기를 바꾸는 일이라 창이 맡는다.
    var onToggle: (Bool) -> Void = { _ in }
    /// 폴더의 차례가 바뀌었다 — 설정에 적을 것 (`Settings.folders`).
    var onFoldersChanged: ([String]) -> Void = { _ in }

    init(store: MemoStore, putAway: @escaping (ULID) -> Bool, folders: [String] = []) {
        self.store = store
        self.putAway = putAway
        self.listedFolders = folders.compactMap(MemoFolders.normalized)
        refresh()
    }

    // MARK: 들여다보기

    func refresh() {
        let held = DrawerContents.filter(store.memos) { putAway($0.id) }
        papers = held
        // 메모에만 적힌 이름표도 폴더다 — 다른 컴퓨터에서 왔거나 Claude 가 적었거나.
        // 다만 물러나는 중인 이름은 마지막 이름표가 떨어질 때까지 감춘다.
        retired = retired.intersection(store.memos.compactMap(\.folder))
        folders = MemoFolders.names(listed: listedFolders, memos: store.memos)
            .filter { !retired.contains($0) }
        // 보고 있던 폴더가 없어졌으면 「전체」로 돌아간다.
        if let selectedFolder, !folders.contains(selectedFolder) { self.selectedFolder = nil }
        // 서랍에서 나간 종이를 계속 펼쳐 놓고 있을 수는 없다 — 꺼내기를
        // 누른 그 종이가 바로 그렇게 된다.
        if let filed = lastFiled, !held.contains(where: { $0.id == filed.id }) { lastFiled = nil }
        prune()
        onLayoutChanged()
    }

    /// **지금 목록에 없는 것을 계속 짚고 있지 않는다.**
    ///
    /// 셋이 같은 이유로 정리된다 — 펼쳐 둔 줄, 짚어 둔 줄, 골라 둔 줄. 서랍에서
    /// 나갔거나 찾기·폴더에 걸러진 종이를 계속 들고 있으면, 「꺼내기」가 **화면에
    /// 없는 종이**에 걸린다. 사람은 자기가 무엇을 꺼냈는지 알 수 없다.
    private func prune() {
        let alive = Set(shown.map(\.id))
        if let expanded, !alive.contains(expanded) { self.expanded = nil }
        if let focused, !alive.contains(focused) { self.focused = nil }
        picked.formIntersection(alive)
    }

    /// **목록에 있는 장수** — 찾거나 폴더를 보는 중이면 걸러진 수다.
    var count: Int { shown.count }
    /// 서랍이 들고 있는 전부. 찾기와 폴더에 무관하다.
    var total: Int { papers.count }
    var title: String { DrawerContents.title(count: total) }

    /// 폴더마다 몇 장인지 — **서랍에 든 것만** 센다.
    var counts: [String: Int] { MemoFolders.counts(in: papers) }

    /// 어느 폴더에도 안 넣은 종이 수.
    var loose: Int { papers.filter { $0.folder == nil }.count }

    /// 찾은 결과를 한 줄로. 찾는 중이 아니면 `nil` (`DrawerSearch.summary`).
    var searchSummary: String? {
        DrawerSearch.summary(query: shownQuery, found: count)
    }

    /// 찾는 중인가 — 글자가 들어 있으면 그렇다.
    var isSearching: Bool { !shownQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    /// 고른 장수를 한 줄로. 고른 것이 없으면 `nil`.
    var pickedLabel: String? { DrawerContents.picked(count: shownPicked.count) }

    func geometry() -> DrawerGeometry {
        let opened = shownExpanded.flatMap { id in shown.first { $0.id == id } }
        return DrawerGeometry(
            count: count, expanded: opened != nil,
            expandedLines: opened.map { DrawerText.bodyLines(of: $0.body) } ?? 1,
            ceiling: ceiling
        )
    }

    /// 폴더의 차례를 밖에서 정해 준다 — 소개 영상 주행(`DemoTour`)이 설정을 나중에 심을 때.
    func adoptFolders(_ names: [String]) {
        listedFolders = names.compactMap(MemoFolders.normalized)
        refresh()
    }

    // MARK: 손짓

    func toggle() { setOpen(!isOpen) }

    func setOpen(_ open: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        // 접을 때는 **들고 있던 것을 전부 내려놓는다.** 다음에 열었을 때 한 줄이
        // 펼쳐져 있거나, 찾던 글자가 남아 있거나, 세 장이 골라진 채이면
        // "내가 저걸 왜 저래 뒀지" 가 남는다. 서랍은 늘 같은 모습으로 열린다.
        //
        // **보던 폴더는 남긴다.** 폴더는 상태가 아니라 자리다 — 「장보기」를
        // 보다가 접었으면 다음에도 「장보기」가 맞다.
        if !open {
            expanded = nil
            focused = nil
            picked.removeAll()
            query = ""
            isNamingFolder = false
            renamingFolder = nil
        }
        onToggle(open)
    }

    /// 누르면 펼치고, 한 번 더 누르면 도로 접는다.
    func zoom(_ id: ULID) {
        expanded = expanded == id ? nil : id
        focused = id
    }

    func shrink() { expanded = nil }

    /// 종이 한 장이 방금 서랍에 들어왔다.
    ///
    /// **보고 있던 폴더로 들어간다.** 「장보기」를 펼쳐 놓고 종이를 끌어다
    /// 놓았는데 「전체」에만 떨어지면, 사람은 자기가 겨눈 자리에 놓이지 않은
    /// 것으로 본다 — 그리고 그 종이는 「장보기」를 보는 동안 보이지 않는다.
    func received(_ memo: Memo) {
        lastFiled = memo
        if isOpen, let folder = selectedFolder, memo.folder != folder {
            move(memo.id, to: folder)
        }
        refresh()
    }

    func takeOut(_ id: ULID) {
        if expanded == id { expanded = nil }
        if lastFiled?.id == id { lastFiled = nil }
        onTakeOut(id)
    }

    func delete(_ id: ULID) {
        if expanded == id { expanded = nil }
        if focused == id { focused = nil }
        picked.remove(id)
        onDelete(id)
    }

    // MARK: 폴더

    /// 종이를 이 폴더로 옮긴다. `nil` 이면 폴더에서 뺀다. **파일에 적는다** —
    /// 이름표는 종이의 것이지 서랍의 것이 아니다 (`Memo.folder`).
    func move(_ id: ULID, to folder: String?) {
        Task { [store] in _ = try? await store.update(id, folder: .some(folder)) }
    }

    /// 고른 것을 한꺼번에 옮긴다. 차례는 목록 그대로다 (`takeOutPicked` 와 같은 이유).
    func movePicked(to folder: String?) {
        for id in orderedPicked { move(id, to: folder) }
        picked.removeAll()
    }

    /// 새 폴더. 이미 있는 이름이면 그 폴더로 간다 — 같은 이름 둘은 오타다.
    /// - Returns: 만들었거나 이미 있어서 그리로 갔으면 `true`, 이름이 비었으면 `false`.
    @discardableResult
    func createFolder(_ name: String) -> Bool {
        guard let name = MemoFolders.normalized(name) else { return false }
        listedFolders = MemoFolders.adding(name, to: listedFolders)
        onFoldersChanged(listedFolders)
        isNamingFolder = false
        refresh()
        selectedFolder = name
        return true
    }

    /// 이름을 바꾼다. **그 이름표를 단 종이 전부**가 따라간다 — 바탕화면에
    /// 나와 있는 것까지. 안 그러면 그 종이는 다음에 서랍에 들어올 때 이미
    /// 없는 폴더로 간다.
    /// - Returns: 바꿨으면 `true`. 빈 이름이거나 이미 있는 이름이면 `false`.
    @discardableResult
    func renameFolder(_ old: String, to new: String) -> Bool {
        guard let listed = MemoFolders.renaming(old, to: new, in: listedFolders),
              let new = MemoFolders.normalized(new)
        else {
            renamingFolder = nil
            return false
        }
        listedFolders = listed
        onFoldersChanged(listedFolders)
        renamingFolder = nil
        retired.insert(old)
        let wasSelected = selectedFolder == old
        for memo in store.memos where memo.folder == old { move(memo.id, to: new) }
        refresh()
        if wasSelected { selectedFolder = new }
        return true
    }

    /// 폴더를 없앤다. **종이는 없어지지 않는다** — 이름표만 떼고 서랍에 남는다.
    /// 폴더를 지우는 것이 메모를 지우는 길이 되면 안 된다 (D6 의 정신).
    func deleteFolder(_ name: String) {
        listedFolders = MemoFolders.removing(name, from: listedFolders)
        onFoldersChanged(listedFolders)
        retired.insert(name)
        for memo in store.memos where memo.folder == name { move(memo.id, to: nil) }
        if selectedFolder == name { selectedFolder = nil }
        refresh()
    }

    /// 옆 폴더로 옮겨 본다 (Tab). 「전체」→ 첫 폴더 → … → 마지막 → 「전체」.
    func stepFolder(_ delta: Int) {
        guard !folders.isEmpty else { return }
        let slots: [String?] = [nil] + folders.map { $0 }
        let current = slots.firstIndex { $0 == selectedFolder } ?? 0
        let next = (current + delta + slots.count) % slots.count
        selectedFolder = slots[next]
    }

    // MARK: 여러 장을 한꺼번에

    /// 한 줄을 고르기에 넣거나 뺀다.
    func pick(_ id: ULID) {
        if picked.contains(id) { picked.remove(id) } else { picked.insert(id) }
    }

    func clearPicked() { picked.removeAll() }

    /// **고른 것을 한꺼번에 되돌린다.**
    ///
    /// 차례가 요점이다. 목록에 놓인 차례 그대로 꺼내야 바탕화면에서도 같은
    /// 차례로 선다 — 집합(`Set`)이 주는 차례대로 부르면 꺼낼 때마다 순서가
    /// 달라지고, 그러면 «되돌렸다» 가 아니라 «흩뿌렸다» 가 된다.
    func takeOutPicked() {
        for id in orderedPicked { takeOut(id) }
        picked.removeAll()
    }

    /// 고른 것을 한꺼번에 지운다. 되돌리기는 메뉴에 있다 (D6).
    func deletePicked() {
        for id in orderedPicked { onDelete(id) }
        if let expanded, picked.contains(expanded) { self.expanded = nil }
        if let focused, picked.contains(focused) { self.focused = nil }
        picked.removeAll()
    }

    private var orderedPicked: [ULID] {
        shown.map(\.id).filter { picked.contains($0) }
    }

    // MARK: 키보드로 훑기

    /// 목록을 한 줄 위아래로 짚는다. 아직 아무것도 안 짚었으면 **맨 위부터.**
    func moveFocus(by step: Int) {
        let ids = shown.map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = focused, let index = ids.firstIndex(of: current) else {
            focused = step < 0 ? ids.last : ids.first
            return
        }
        let next = min(max(index + step, 0), ids.count - 1)
        focused = ids[next]
    }

    /// **한 겹만 되돌린다** — 고르기 → 이름 적기 → 찾기 → 펼친 줄 → 짚은 자리 → 폴더 → 서랍.
    ///
    /// esc 한 번에 전부 지우면 세 글자를 찾다가 한 번 잘못 눌렀을 때 서랍이
    /// 통째로 닫힌다. 한 겹씩 벗겨야 되돌리기가 예측된다.
    ///
    /// esc 를 한 번 더 누르면 **서랍이 닫히는가.** 벗길 겹이 남았으면 아니다.
    /// 창이 이것을 묻는 이유: 글 상자에 커서가 있을 때의 마지막 esc 는
    /// 「서랍을 닫아라」가 아니라 「상자에서 빠져나가라」다 (`DrawerWindowController.handle`).
    var escapeWouldClose: Bool {
        picked.isEmpty && !isNamingFolder && renamingFolder == nil && !isSearching
            && expanded == nil && focused == nil && selectedFolder == nil
    }

    func escape() {
        if !picked.isEmpty { picked.removeAll(); return }
        if isNamingFolder { isNamingFolder = false; return }
        if renamingFolder != nil { renamingFolder = nil; return }
        if isSearching { query = ""; return }
        if expanded != nil { expanded = nil; return }
        if focused != nil { focused = nil; return }
        if selectedFolder != nil { selectedFolder = nil; return }
        setOpen(false)
    }

    /// 이 화면이 허락하는 목록 높이를 창이 알려 준다.
    func setCeiling(_ value: CGFloat) {
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
            guard let target = focused ?? expanded else { return false }
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
        case .folder(let delta):
            guard !folders.isEmpty else { return false }
            stepFolder(delta)
        }
        return true
    }

    /// 지금 조작이 걸리는 한 줄 — 펼쳐 둔 것이 있으면 그것, 아니면 짚은 것.
    private var aimed: ULID? { expanded ?? focused }

    // MARK: 연출값이 있으면 그것이 이긴다 (`PreviewRenderer`)

    var shownOpen: Bool { staged?.isOpen ?? isOpen }
    var shownExpanded: ULID? { staged?.expanded ?? expanded }
    var shownLanding: ULID? { staged?.landing ?? landing }
    var shownLastFiled: Memo? { staged?.lastFiled ?? lastFiled }
    var shownQuery: String { staged?.query ?? query }
    var shownFolder: String? {
        if let staged { return staged.folder }
        return selectedFolder
    }
    var shownPicked: Set<ULID> { staged.map { $0.picked } ?? picked }
    var shownNaming: Bool { staged?.naming ?? isNamingFolder }
}
