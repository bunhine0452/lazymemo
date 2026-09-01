import Foundation
import LazyMemoCore
import Observation

/// 빠른 입력 상자의 상태 (설계문서 §8).
///
/// 한 상자가 **입력과 검색과 일정 인식을 겸한다.** 치면 기존 메모가 걸러지고,
/// 날짜 표현이 보이면 칩으로 떠오르며, 그대로 Return 을 누르면 새 메모가 된다.
/// 모드 전환이 없어야 조작 수가 줄어든다.
///
/// **빈 상자는 요즘 메모를 들고 있는다.** 예전에는 한 글자라도 쳐야 목록이
/// 나왔는데, 그러면 "무엇을 적어 뒀더라" 를 확인하려는 사람이 기억해 낸
/// 낱말을 먼저 대야 했다 — 기억이 안 나서 여는 것인데. 열면 바로 보이는
/// 쪽이 맞다. 치기 시작하면 그 자리가 찾은 것으로 바뀔 뿐, 목록은 없어지지
/// 않는다.
@MainActor
@Observable
final class QuickCaptureModel {
    var query: String = "" {
        didSet {
            // 날짜 인식은 로컬 문자열 처리라 즉시 한다. 타자마다 칩이 따라와야
            // 사용자가 "아, 얘가 읽고 있구나" 를 알 수 있다.
            schedule = NaturalDateParser.parse(query)
            filter = MemoFilter.read(query)
            reloadImages()
            // 낱말이 바뀌면 목록은 다른 물건이다. 넓혀 둔 것은 그때 것이라
            // 도로 접는다 — 지운 뒤의 다시 짓기(`refreshListing`)는 같은
            // 목록이므로 접지 않는다.
            isExpanded = false
            scheduleSearch()
        }
    }

    /// 찾아 둔 것 전부. 화면에 놓이는 것은 이 중 앞에서 몇 장뿐이다 (`listed`).
    ///
    /// **화면 길이와 아는 길이를 갈라 놓는다.** 예전에는 다섯 장만 들고 왔고,
    /// 그래서 "여섯 번째가 있는지" 를 앱 자신도 몰랐다 — 목록은 조용히 잘렸고
    /// 화면에는 잘렸다는 말이 한 줄도 없었다. 스무 장 너머는 이 상자에서만
    /// 만날 수 있는데, 여기서 잘리면 그 메모들은 어디에도 없는 것이 된다.
    private(set) var pool: [Memo] = []
    /// 지금 놓인 것이 어느 쪽인지. 화살표가 무엇을 훑는지 사람에게 말해 준다.
    private(set) var listing: Listing = .recent
    /// 목록을 넓혀 두었는가. **누르거나, 끝에서 ↓ 를 한 번 더 누르면** 넓어진다.
    private(set) var isExpanded = false

    /// 상자 아래에 놓인 메모. 빈 상자에서는 요즘 것, 치면 찾은 것이다.
    var listed: [Memo] { Array(pool.prefix(visibleLimit)) }

    private var visibleLimit: Int { isExpanded ? Self.expandedLimit : Self.compactLimit }

    /// 목록 아래 한 줄이 말할 것. 없으면 다 보이고 있다는 뜻이다.
    enum Overflow: Equatable {
        /// 아직 안 보인 것이 이만큼. 누르면 넓어진다.
        case more(Int)
        /// 넓힐 만큼 넓혔는데도 남았다 — 낱말로 좁히는 편이 빠르다.
        case tooMany(Int)
    }

    /// 지금 화면에 못 담은 것.
    ///
    /// **세어 두고 적는다.** 목록이 그냥 끊겨 있으면 사람은 그것을 "이게
    /// 전부" 로 읽고, 아홉 번째 메모는 있는 줄도 모르는 채 다시 적힌다.
    var overflow: Overflow? {
        let hidden = pool.count - listed.count
        guard hidden > 0 else { return nil }
        // 넓혀도 남는다면 목록을 더 늘리는 것은 답이 아니다 — 스무 줄을
        // 훑는 것보다 한 글자 더 치는 편이 짧다.
        return isExpanded ? .tooMany(hidden) : .more(hidden)
    }

    /// 목록을 넓힌다. 되돌리는 길은 두지 않는다 — 상자를 닫으면 도로 짧아지고,
    /// 넓어진 것을 다시 좁히려고 누르는 사람은 없다.
    func expand() {
        guard !isExpanded, overflow != nil else { return }
        isExpanded = true
    }

    /// 지금 적은 글에 붙은 사진.
    ///
    /// **이것이 없어서 "사진 붙여넣기가 안 된다" 로 보였다.** 붙은 사진은
    /// 본문에 `![](…)` 로 들어가는데 그 글자는 꾸밈이 감추므로, 화면에서는
    /// 정말로 아무 일도 일어나지 않았다.
    private(set) var images: [AttachedImage] = []
    /// 입력에서 알아낸 일정. 없으면 그냥 메모다.
    private(set) var schedule: NaturalDateParser.Result?
    /// 입력에서 알아낸 **거를 조건** (`MemoFilter`). 낱말이 기억나지 않을 때 남는 길이다.
    private(set) var filter = MemoFilter()
    /// 화살표로 고른 메모. **자리가 아니라 그 메모 자체를 들고 있는다.**
    ///
    /// 자리만 기억하던 때에는 목록이 갈리는 순간 고른 것이 조용히 바뀌었다 —
    /// "은행" 을 골라 둔 채로 `치과` 를 치면 세 번째 자리가 없어지면서 선택이
    /// 첫 줄로 미끄러졌고, 그러면 ⌘⏎ 는 **고른 적 없는 메모**를 연다. 목록은
    /// 타자마다 다시 지어지므로 자리는 근거가 될 수 없다.
    private(set) var selectedID: ULID?
    /// 포인터가 얹힌 줄. **키가 무엇을 할지는 바꾸지 않는다.**
    ///
    /// 예전에는 손이 스치기만 해도 이것이 곧 선택이었다. 그래서 세 줄 적다가
    /// 마우스가 목록 위를 한 번 지나가면 ⌘⏎ 가 「적기 끝」에서 「남의 메모
    /// 열기」로 바뀌었고 — 적던 글은 저장되지 않았다 — ⌘⌫ 는 가리키기만 한
    /// 메모를 휴지통으로 보냈다. 손은 무엇을 누를 수 있는지만 비추고,
    /// 무엇을 할지는 키보드가 정한다.
    var pointed: ULID?
    /// 여기서 방금 지운 것. 되돌리는 줄이 상자 안에 떠 있는 동안만 값이 있다 (D6).
    private(set) var lastDeleted: Memo?

    /// 고른 것이 지금 목록의 몇 번째인가. 없으면 `nil` 이고, 그때 ⌘⏎ 는 새 메모를 만든다.
    ///
    /// 값을 넣는 쪽도 열어 둔다 — 줄을 **직접 누른** 것은 화살표로 고른 것과
    /// 같은 뜻이기 때문이다. 스치는 것만이 선택이 아니다.
    var selection: Int? {
        get { selectedID.flatMap { id in listed.firstIndex { $0.id == id } } }
        set { selectedID = newValue.flatMap { listed[safe: $0]?.id } }
    }

    /// 목록에 놓인 것의 출처.
    enum Listing {
        /// 아무것도 치지 않았을 때 — 최근에 손댄 것부터.
        case recent
        /// 친 글로 걸러 낸 것.
        case found
    }

    // 창 높이를 다시 잡아 달라고 여기서 부탁하던 길은 **버렸다.**
    //
    // 결과 수가 바뀔 때는 부르고 날짜 칩이 뜰 때는 안 부르는, 그런 빠짐이
    // 생기는 구조였다. 지금은 뷰가 다시 그려진 높이를 창이 직접 받아 간다
    // (`CaptureHostingView`) — 모델은 무엇이 화면에 있어야 하는지만 안다.

    /// 말풍선 꼬리가 가리킬 자리 (상자 왼쪽 끝에서의 거리).
    /// `nil` 이면 매달 곳이 없어 꼬리를 그리지 않는다.
    var arrowOffset: CGFloat?

    /// 빈 상자에 흐리게 놓이는 안내 문구. **열 때마다 새로 뽑는다**
    /// (`CapturePrompt`). 첫 글자를 치면 사라지므로 적는 데 방해가 없다.
    private(set) var placeholder: String = CapturePrompt.next(after: nil)

    private let store: MemoStore
    /// 그 메모를 마지막으로 **연** 때. 없으면 열어 본 적이 없다는 뜻이다.
    private let lastOpened: (ULID) -> Date?
    private var searchTask: Task<Void, Never>?

    /// 타자마다 인덱스를 때리지 않는다. 사람이 한 글자 더 치는 시간보다 짧게 둔다.
    private static let searchDelay: Duration = .milliseconds(120)
    /// 인덱스에서 들고 오는 수. **화면에 놓는 수와 다르다** — 몇 장이
    /// 걸렸는지 알아야 "외 N장 더" 를 적을 수 있고, 스무 장 너머로 가는
    /// 길도 여기서 열린다. 200줄을 세어 오는 값은 인덱스에서 거의 공짜다.
    static let searchCeiling = 200
    /// 처음 보이는 줄 수. 메뉴 목록(8장)보다 적게 둔다 — 여기는 적는 자리가
    /// 먼저고, 목록이 길면 적을 자리가 화면 밖으로 밀린다.
    static let compactLimit = 5
    /// 넓혔을 때의 줄 수. 이보다 길면 상자가 화면을 덮는다.
    static let expandedLimit = 20

    init(store: MemoStore, lastOpened: @escaping (ULID) -> Date? = { _ in nil }) {
        self.store = store
        self.lastOpened = lastOpened
    }

    /// 적은 것을 지우고 처음으로 되돌린다. **확정한 뒤에만 부른다.**
    func clear() {
        searchTask?.cancel()
        query = ""
        schedule = nil
        isExpanded = false
        selectedID = nil
        pointed = nil
        images = []
        lastDeleted = nil
        showRecent()
    }

    /// 펼쳐 볼 원본. 화면에 들고 있는 것은 줄인 그림이다 (§11).
    func originalURL(for attachment: AttachedImage) -> URL? {
        store.attachments.url(for: attachment.path)
    }

    /// 붙은 사진이 바뀌었을 때만 파일을 읽는다. 타자마다 디스크를 두들기면
    /// 상자가 뜨는 속도(§11 의 150ms)가 무너진다.
    private func reloadImages() {
        let paths = MarkdownScanner.imagePaths(in: query)
        guard paths != images.map(\.path) else { return }
        images = AttachedImages.load(paths, from: store.attachments)
    }

    /// 상자를 다시 열 때. **적던 것은 그대로 둔다.**
    ///
    /// esc 로 닫았다고 글을 버리면, 여러 줄을 적다가 손이 미끄러진 한 번에
    /// 전부 잃는다. 그렇다고 닫을 때 저장해 버리면 — 이 상자는 검색도 겸하므로 —
    /// 메모를 찾으려고 친 낱말이 새 메모가 되어 쌓인다. 어느 쪽도 안 되므로
    /// **상자가 기억한다.** 다시 열면 글이 전부 선택돼 있어 그냥 치면 덮어쓴다.
    func prepareForShow() {
        selectedID = nil
        pointed = nil
        // 다시 연 상자는 짧은 목록으로 시작한다. 넓혀 둔 것은 그때 찾던 것이다.
        isExpanded = false
        // 지난번에 지운 것을 되돌리는 줄은 남기지 않는다. 다시 연 사람이 보는
        // 것은 지금 하려는 일이지 아까 한 일이 아니다 — 그때의 되돌리기는
        // 메뉴가 5분 동안 들고 있다 (`MenuBarController`).
        lastDeleted = nil
        placeholder = CapturePrompt.next(after: placeholder)
        // 지난번에 연 뒤로 메모가 늘거나 지워졌을 수 있다. 목록은 파일을
        // 다시 읽지 않고 이미 메모리에 있는 것을 훑을 뿐이라 여기서 해도
        // 표시 예산(§11)을 건드리지 않는다.
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { showRecent() }
    }

    /// 빈 상자가 들고 있는 것 — 고정한 것이 먼저, 그 다음 최근에 손댄 순
    /// (`MemoStore.active` 의 차례를 그대로 쓴다).
    private func showRecent() {
        listing = .recent
        // **치워 둔 것은 여기 오지 않는다** (`Tidy`). 다섯 자리뿐인 목록이
        // 다 끝난 장보기로 차면 그건 「요즘」이 아니다. 찾으면 나오고,
        // 열면 도로 꺼내진다.
        //
        // **읽은 것도 「요즘」이다.** 고친 때만 세면 어제 열어 본 메모가 목록
        // 밖으로 밀린다 — 읽기만 해서는 `updated` 가 안 움직이기 때문이다.
        // 그래서 고친 때와 연 때 중 나중 것으로 센다 (`WindowLayout.opened`).
        pool = store.active.sorted { left, right in
            if left.pinned != right.pinned { return left.pinned }
            return recency(of: left) > recency(of: right)
        }
        dropSelectionIfGone()
    }

    private func recency(of memo: Memo) -> Date {
        max(memo.updated, lastOpened(memo.id) ?? .distantPast)
    }

    /// 목록이 다시 지어졌다. 고른 것이 그 안에 없으면 **놓는다.**
    ///
    /// 자리를 맞춰 밀어 넣던 옛 방식이 곧 결함이었다 — 세 번째 자리가
    /// 없어지면 선택이 첫 줄로 미끄러졌고, 그때부터 ⌘⏎ 는 고른 적 없는
    /// 메모를 연다. 들고만 있고 화면에 없는 선택도 같은 종류의 거짓말이라
    /// (지웠다가 낱말을 도로 지우면 되살아난다), 목록에 없으면 놓아 버린다.
    private func dropSelectionIfGone() {
        if let selectedID, !listed.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
        if let pointed, !listed.contains(where: { $0.id == pointed }) {
            self.pointed = nil
        }
    }

    /// 붙여넣거나 끌어다 놓은 사진을 Vault 안 파일로 저장하고 마크다운을 돌려준다.
    ///
    /// 메모 창과 **같은 길**이다 (`NoteModel`). 빠른 입력에서 사진을 못 넣으면
    /// "일단 던져 두는 곳" 이라는 이 상자의 성격이 반쪽이 된다.
    func markdown(forPastedImage data: Data, fileExtension: String) -> String? {
        guard let path = try? store.attachments.save(data, fileExtension: fileExtension)
        else { return nil }
        return "\n![](\(path))\n"
    }


    /// 칩에 보여줄 글. 인식한 원문이 아니라 **해석한 결과**를 보인다 —
    /// "내일" 이라고 되쓰면 제대로 읽었는지 확인할 수 없다.
    var scheduleLabel: String? {
        guard let schedule else { return nil }
        if let at = schedule.at {
            return at.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
        }
        if let due = schedule.due, let start = due.startOfDay() {
            return start.formatted(.dateTime.month().day().weekday(.abbreviated))
        }
        return nil
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // 조건만 있고 낱말이 없어도 찾을 것이 있다 — `#사진` 한 마디로
        // 「그 사진 붙여 둔 거」에 닿는 것이 이 상자의 값이다.
        guard !text.isEmpty else {
            showRecent()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled, let self else { return }
            await self.find(text)
        }
    }

    /// 친 글로 걸러 낸다. 디바운스 밖에서도 부른다 — 지운 직후처럼 기다릴
    /// 이유가 없을 때다.
    ///
    /// **두 걸음이다.** 인덱스는 낱말만 알고, 생김새·태그·장소·날짜는 메모를
    /// 손에 쥐어야 볼 수 있다. 낱말이 비어 있으면(`#사진` 만 쳤을 때) 요즘
    /// 것부터 훑어 거른다 — 그때 인덱스에 넘길 것이 없기 때문이다.
    private func find(_ text: String) async {
        let condition = MemoFilter.read(text)
        let words = condition.words.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = await store.search(words, limit: Self.searchCeiling)
        guard !Task.isCancelled else { return }

        listing = .found
        pool = condition.narrows ? found.filter { condition.matches($0) } : found
        dropSelectionIfGone()
    }

    /// 목록을 지금 상태로 다시 짓는다. **한 박자도 늦으면 안 된다** — 지운
    /// 줄이 그대로 남아 있으면 "안 지워졌다" 로 보이고, 사람은 한 번 더 누른다.
    ///
    /// 요즘 것을 보고 있었으면 요즘 것으로, 찾은 것을 보고 있었으면 같은
    /// 낱말로 다시 찾는다 — 지웠다고 목록의 성격이 바뀌지는 않는다.
    private func refreshListing() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showRecent()
            return
        }
        await find(text)
    }

    // MARK: 지우기 (D6)

    /// 목록에 놓인 것을 **그 자리에서** 지운다.
    ///
    /// 메뉴 목록에 나오는 여덟 장 너머는 이 상자에서만 만날 수 있는데, 여는
    /// 길만 있고 지우는 길이 없으면 아홉 번째 메모부터는 바탕화면에서 그
    /// 종이를 찾아내는 수밖에 없었다.
    ///
    /// **상자는 열린 채로 둔다.** 치우려고 연 사람은 대개 한 장만 지우지
    /// 않는데, 지울 때마다 닫히면 단축키를 다시 눌러 같은 낱말을 또 쳐야 한다.
    /// 휴지통 이동뿐이고(D6), 되돌리는 줄이 상자 안에 바로 생긴다.
    func delete(_ memo: Memo) async {
        // 지우기 **전에** 자리를 적어 둔다. 지운 뒤에는 그 줄이 없다.
        let slot = listed.firstIndex { $0.id == memo.id }
        let wasSelected = selectedID == memo.id
        guard (try? await store.delete(memo.id)) != nil else { return }
        lastDeleted = memo
        await refreshListing()

        // 고르지 않은 줄을 지운 것이면 고른 것은 그대로 있다 — 자리가 아니라
        // 메모를 들고 있으므로 위의 줄이 하나 빠져도 따라 밀리지 않는다.
        guard wasSelected else { return }
        // 고른 줄을 지웠으면 **다음 줄이 그 자리로 올라온다.** ⌘⌫ 를 연달아
        // 누르면 위에서부터 훑으며 치워진다 (§8). 마지막 한 장이었으면
        // 아무것도 골라지지 않는다 — ⌘⏎ 가 빈 것을 열면 안 된다.
        selectedID = slot.flatMap { listed[safe: $0]?.id }
    }

    /// 고른 줄을 지운다 (⌘⌫). 지운 메모를 돌려준다 — 고른 것이 없으면 `nil`
    /// 이고, 그때 ⌘⌫ 는 가로채지 않고 글 편집으로 넘어가야 한다.
    @discardableResult
    func deleteSelected() -> Memo? {
        guard let selection, listed.indices.contains(selection) else { return nil }
        let memo = listed[selection]
        Task { await delete(memo) }
        return memo
    }

    /// 방금 지운 것을 되살린다.
    func restoreLastDeleted() async {
        guard let memo = lastDeleted else { return }
        try? await store.restore(memo.id)
        lastDeleted = nil
        await refreshListing()
    }

    // MARK: 키보드 이동

    func moveSelection(_ delta: Int) {
        guard !listed.isEmpty else { return }
        switch selection {
        case nil:
            selectedID = delta > 0 ? listed.first?.id : listed.last?.id
        case let current?:
            // **끝에서 한 번 더 내리면 목록이 넓어진다.** 손을 옮겨 「외 N장
            // 더」를 누르러 가지 않아도 되게, 이미 하고 있던 손짓을 그대로
            // 한 번 더 쓴다 — 마지막 줄에서 ↓ 는 어차피 할 일이 없었다.
            if delta > 0, current == listed.count - 1, !isExpanded, overflow != nil {
                expand()
                selectedID = listed[safe: current + 1]?.id ?? selectedID
                return
            }
            let next = current + delta
            // 위로 벗어나면 "선택 없음"(= 새 메모)으로 되돌아간다.
            selectedID = listed[safe: next]?.id
        }
    }

    // MARK: 확정

    struct Draft {
        let text: String
        let due: CalendarDate?
        let at: Date?
    }

    enum Commit {
        case open(ULID)
        case create(Draft)
        case nothing
    }

    func commit() -> Commit {
        if let selection, listed.indices.contains(selection) {
            return .open(listed[selection].id)
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .nothing }

        guard let schedule else {
            return .create(Draft(text: text, due: nil, at: nil))
        }
        return .create(Draft(
            text: NaturalDateParser.strip(schedule.phrases, from: text),
            due: schedule.due,
            at: schedule.at
        ))
    }
}
