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
            reloadImages()
            scheduleSearch()
        }
    }

    /// 상자 아래에 놓인 메모. 빈 상자에서는 요즘 것, 치면 찾은 것이다.
    private(set) var listed: [Memo] = []
    /// 지금 놓인 것이 어느 쪽인지. 화살표가 무엇을 훑는지 사람에게 말해 준다.
    private(set) var listing: Listing = .recent
    /// 지금 적은 글에 붙은 사진.
    ///
    /// **이것이 없어서 "사진 붙여넣기가 안 된다" 로 보였다.** 붙은 사진은
    /// 본문에 `![](…)` 로 들어가는데 그 글자는 꾸밈이 감추므로, 화면에서는
    /// 정말로 아무 일도 일어나지 않았다.
    private(set) var images: [AttachedImage] = []
    /// 입력에서 알아낸 일정. 없으면 그냥 메모다.
    private(set) var schedule: NaturalDateParser.Result?
    /// 화살표로 고른 항목. `nil` 이면 Return 이 새 메모를 만든다.
    var selection: Int?
    /// 여기서 방금 지운 것. 되돌리는 줄이 상자 안에 떠 있는 동안만 값이 있다 (D6).
    private(set) var lastDeleted: Memo?

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
    private var searchTask: Task<Void, Never>?

    /// 타자마다 인덱스를 때리지 않는다. 사람이 한 글자 더 치는 시간보다 짧게 둔다.
    private static let searchDelay: Duration = .milliseconds(120)
    private static let matchLimit = 5
    /// 빈 상자에 얹는 요즘 메모의 수. 메뉴 목록(8장)보다 적게 둔다 —
    /// 여기는 적는 자리가 먼저고, 목록이 길면 적을 자리가 화면 밖으로 밀린다.
    private static let recentLimit = 5

    init(store: MemoStore) {
        self.store = store
    }

    /// 적은 것을 지우고 처음으로 되돌린다. **확정한 뒤에만 부른다.**
    func clear() {
        searchTask?.cancel()
        query = ""
        schedule = nil
        selection = nil
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
        selection = nil
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
    /// (`MemoStore.memos` 의 차례를 그대로 쓴다).
    private func showRecent() {
        listing = .recent
        listed = Array(store.memos.prefix(Self.recentLimit))
        clampSelection()
    }

    private func clampSelection() {
        guard let selection else { return }
        if listed.isEmpty {
            self.selection = nil
        } else if selection >= listed.count {
            self.selection = listed.count - 1
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
    private func find(_ text: String) async {
        let found = await store.search(text, limit: Self.matchLimit)
        guard !Task.isCancelled else { return }
        listing = .found
        listed = found
        clampSelection()
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
        guard (try? await store.delete(memo.id)) != nil else { return }
        lastDeleted = memo
        await refreshListing()
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
            selection = delta > 0 ? 0 : listed.count - 1
        case let current?:
            let next = current + delta
            // 위로 벗어나면 "선택 없음"(= 새 메모)으로 되돌아간다.
            selection = (next < 0 || next >= listed.count) ? nil : next
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
