import Foundation
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoPlaces
import Observation

/// 펜 — 화면 바닥의 적는 칸. 적기와 찾기를 겸한다 (MOBILE_DESIGN §3).
///
/// 맥의 `QuickCaptureModel` 과 같은 규칙을 같은 부품으로 돈다: 읽는 것은
/// `NoteReader`, 거르는 것은 `MemoFilter` + `HangulInitials` + 인덱스. 여기서
/// 새 규칙을 만들지 않는다.
@Observable
final class PenModel {
    let store: MemoStore
    private let draft: CaptureDraftStore

    /// 치는 글. 바뀔 때마다 초안에 남기고(껐다 켜도 남는다) 무더기를 거른다.
    var text: String {
        didSet {
            guard text != oldValue else { return }
            draft.remember(text)
            reschedule()
            // 글을 다 지우면 끈 칩도 잊는다 — 다음 글의 날짜가 말없이 안 읽히면 안 된다.
            if text.isEmpty { readsDate = true; readsPlace = true; readsEvery = true }
            // 글을 고치면 답은 물러나고 검색으로 돌아간다 (맥의 상자와 같은 규칙, quick-capture-assistant D9).
            if shown != nil || asked != nil || assistant?.answer != nil || assistant?.proposal != nil || assistant?.phase == .thinking {
                shown = nil
                listing = .search
                asked = nil
                assistant?.reset()
            }
            // 가는 길의 끝난 한 줄도 다음 글자에 물러난다.
            if !text.isEmpty { planner?.acknowledge() }
        }
    }

    // MARK: 가는 길 — 약속을 남기면 「어디서 출발하시나요?」 (`RoutePlanner`, 맥의 상자와 같은 대화)

    /// 없으면(시험) 묻지 않는다. `HomeView` 가 끼운다.
    var planner: RoutePlanner?

    // MARK: 비서 — 펜 하나가 묻기·시키기·되묻기까지 겸한다 (맥의 QuickCaptureModel 과 같은 갈래)

    /// 이 기기의 비서. 없으면(시험) 펜은 적기와 찾기만 한다.
    var assistant: AssistantModel? {
        didSet { assistant?.onSettled = { [weak self] in self?.reflectAssistant() } }
    }
    /// 편집 화면의 ✦ 로 들고 온 메모 — 「이거」다 (D10). 칩의 × 로 놓거나, 답·결과가 오면 놓는다.
    var target: ULID?
    var targetTitle: String? { target.flatMap { store.memo($0)?.title } }
    /// 방금 비서에게 한 말 — 「읽는 중」 머리글과 답 카드가 이것을 인용한다. 글을 고치면 잊는다.
    private(set) var asked: String?

    /// 편집 화면의 ✦ — 그 메모를 들고 펜을 올린다. 편집 화면이 다 물러난 뒤에 불린다 (`MemoEditorView.onDisappear`):
    /// 그 전에는 글 칸이 화면에 없어 포커스를 줘도 받지 못한다.
    func adopt(target id: ULID) {
        target = id
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            requestFocus()
        }
    }
    /// 되물음 뒤에 기다리는 새 메모 — 「약속 시간이 언제인가요?」의 답을 이것에 잇는다.
    private(set) var pending: (question: String, draft: FieldPatch)?
    var pendingQuestion: String? { pending?.question }
    /// 초안 한 줄 — 「친구랑 밥 먹기로 했어 · 9월 30일 (수) · @홍대입구」.
    var pendingSummary: String? {
        guard let draft = pending?.draft else { return nil }
        var parts = [draft.body ?? ""]
        if case .set(let due) = draft.due { parts.append(DayWords.long(due)) }
        if let place = draft.place { parts.append("@" + place) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
    static let timeChoices = ["12시", "점심", "저녁 7시", "시각 없이"]

    /// 목록의 출처 — 찾은 것, 아니면 비서가 정한 것. `reading` 은 묻는 동안 그대로 둔 후보다 (맥 E-1 「목록 그대로」).
    enum Listing: Equatable { case search, reading, evidence, related, candidates }
    private(set) var listing: Listing = .search
    /// 비서가 정한 목록(근거·관련·후보). 글을 고치면 놓는다.
    private(set) var shown: [Memo]?
    /// 목록에 놓을 것. `nil` 이면 빈 펜 — 무더기 전부.
    var results: [Memo]? { shown ?? found }

    private func showMemos(_ ids: [ULID], as listing: Listing) {
        self.listing = listing
        shown = ids.compactMap { store.memo($0) }
    }

    /// 비서가 방금 정한 것에 맞춰 목록을 고른다 — `AssistantModel.onSettled` 에서.
    func reflectAssistant() {
        guard let assistant else { return }
        // 답이 왔거나 바꿨으면 「이거」는 할 일을 다했다 — 결과 줄이 그 메모의 이름을 든다.
        if assistant.answer != nil || assistant.receipt != nil { target = nil }
        if let answer = assistant.answer {
            showMemos(answer.found ? answer.evidence : assistant.relatedMemos.map(\.memoID), as: answer.found ? .evidence : .related)
        } else if let proposal = assistant.proposal, AssistantIntent.asksWhichMemo(proposal) {
            // 「어느 메모?」— 비서가 후보를 못 찾았으면(「금요일 10시에 다시 알려줘」는 어느 메모의 낱말도 아니다)
            // 지금 목록이 곧 후보다. 줄을 누르면 여는 대신 그 메모에게 같은 말을 한다 (D10).
            let candidates = proposal.candidates.isEmpty ? (shown ?? found ?? store.active).map(\.id) : proposal.candidates
            showMemos(candidates, as: .candidates)
        } else if case .failed = assistant.phase, !assistant.relatedMemos.isEmpty {
            showMemos(assistant.relatedMemos.map(\.memoID), as: .related)
        } else {
            // 결과 줄·휴지통 되물음·실패 — 읽는 동안 세워 둔 후보는 내리고 검색으로 돌아간다. 바꿨으면 다시 짓는다.
            shown = nil; listing = .search
            if let receipt = assistant.receipt {
                Task { await refresh() }
                // 비서가 만든 약속 메모도 같은 되물음을 받는다 — 「메모 만들어」로 적었든 서술로 적었든.
                if receipt.kind == .createMemo, receipt.id != routedReceipt {
                    routedReceipt = receipt.id
                    planner?.begin(receipt.after)
                }
            }
        }
    }

    /// 가는 길을 이미 물은 비서의 결과 — 같은 결과에 두 번 묻지 않는다.
    private var routedReceipt: UUID?

    /// 「어느 메모?」의 후보 하나를 골랐다 — 같은 말을 그 메모에게.
    func pick(_ id: ULID) { assistant?.pick(id) }

    /// 읽는 중에 그만둔다 — 세워 둔 후보도 내린다 (`cancel` 은 `onSettled` 를 부르지 않는다).
    func cancelReading() {
        assistant?.cancel()
        shown = nil; listing = .search; asked = nil
    }

    /// 비서에게 말을 넘기기 전에 — 펜은 비우고, 지금 목록은 읽는 동안 그대로 세워 둔다.
    /// 글이 비면 목록이 무더기 전부로 튀었다가 답이 오면 근거로 줄어드는데, 그 두 번의 뜀이 답을 기다리는 사람을 흔든다.
    private func handOff(_ said: String) {
        let candidates = found ?? []
        text = ""
        draft.forget()
        asked = said
        if !candidates.isEmpty { shown = candidates; listing = .reading }
    }

    /// 답을 기다리던 초안을 놓는다 — ⊗ 를 눌렀을 때 「시각 없이」와 같다 (D12).
    func takePendingDraft() -> FieldPatch? {
        defer { pending = nil }
        return pending?.draft
    }

    /// 달력 탭이 미리 물린 날. 적은 글에 날짜가 있으면 그쪽이 이긴다 (`QuickSchedule`).
    var presetDay: CalendarDate?
    /// 폴더 칩을 골라 둔 채 적으면 그 폴더로 간다 (맥의 「펼쳐 둔 채 놓으면」).
    var folder: String?

    /// 칩을 눌러 끈 해석. 글은 그대로, 읽기만 않는다.
    var readsDate = true
    var readsPlace = true
    /// 되풀이는 날짜와 따로 끈다 — 「매주 월요일 회의」에서 되풀이만 빼고 날짜는 남길 수 있다.
    var readsEvery = true

    /// 열 때마다 바뀌는 안내 문구.
    private(set) var prompt: String

    /// 찾은 것. `nil` 이면 찾는 중이 아니다 (빈 펜).
    private(set) var found: [Memo]?
    private var searchTask: Task<Void, Never>?

    /// 「지금 여기」가 물린 장소.
    var here: Here?

    /// 밖에서 펜을 올려 달라는 신호 — 값이 바뀌면 `PenBar` 가 포커스를 준다.
    var focusRequest = 0
    func requestFocus() { focusRequest += 1 }

    /// 켤 때의 포커스는 한 번뿐이다. 첫 실행의 안내가 떠 있는 동안은 미룬다 —
    /// 안내 위로 키보드가 올라오면 안 된다 (`HomeView`).
    private var launchFocusTaken = false
    var holdsLaunchFocus = false
    func takeLaunchFocus() -> Bool {
        guard !launchFocusTaken, !holdsLaunchFocus else { return false }
        launchFocusTaken = true
        return true
    }

    /// 안내가 닫혔다 — 미뤄 둔 켤 때의 포커스를 지금 준다. 그 뒤로는 다시 없다.
    func releaseLaunchFocus() {
        holdsLaunchFocus = false
        launchFocusTaken = true
        requestFocus()
    }

    /// 방금 남긴 메모 — 목록이 그리로 간다.
    private(set) var lastLeft: ULID?
    struct Here: Equatable {
        var place: String
        var geo: Coordinate?
    }

    init(store: MemoStore, draft: CaptureDraftStore) {
        self.store = store
        self.draft = draft
        self.text = draft.restored
        self.prompt = CapturePrompt.next(after: nil)
        if !text.isEmpty { reschedule() }
    }

    // MARK: 읽기 — 누르기 전에 무엇을 읽었는지 보인다

    /// 글에서 읽어 낸 것 전부 — 칩을 껐어도 그대로. 칩은 이것으로 그린다:
    /// 끈 칩도 빈 테두리로 남아 있어야 다시 켤 수 있다 (MOBILE_DESIGN §3).
    ///
    /// 글이 없고 자리만 물려 있으면 **자리가 곧 글이다** — 「여기 주차했다」는
    /// 사람이 나중에 덧붙인다 (맥의 `HereCapture` 와 같다).
    private var readAll: ParsedNote {
        guard let inbound = InboundNote.make(text: text, place: here?.place) else {
            if let here { return ParsedNote(body: here.place, place: here.place) }
            return ParsedNote(body: "")
        }
        return NoteReader.read(inbound)
    }

    /// 실제로 남길 것. 끈 칩은 빼고 돌려준다.
    var reading: ParsedNote {
        var note = readAll
        if !readsDate { note.due = nil; note.at = nil }
        // 되풀이는 날짜 위에 선다 — 날짜를 끄면 되풀이도 설 자리가 없다.
        if !readsDate || !readsEvery { note.every = nil }
        if !readsPlace, here == nil { note.place = nil; note.geo = nil }
        return note
    }

    var canLeave: Bool {
        if planner?.isWaiting == true || pending != nil { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if planner?.isBusy == true { return false }
        return InboundNote.make(text: text) != nil || here != nil
    }

    /// 단추의 라벨이 곧 동사다 (quick-capture-assistant D5): 답하기 · 시키기 · 메모에게 묻기 · 달력에 남기기 · 메모 남기기.
    /// 맥의 「「치과 예약」에 적용」은 폰의 좁은 단추에 두 줄로 꺾여 — 누구에게인지는 바로 위의 「열린 메모」 칩이 말한다.
    /// 달력이 물린 날도 칩을 끄면 안 쓰이므로(`leave`) 단추도 같이 바뀐다.
    var leaveLabel: String {
        if pending != nil || planner?.isWaiting == true { return String(localized: "답하기") }
        switch saying {
        case .asking: return String(localized: "메모에게 묻기")
        case .telling: return String(localized: "시키기")
        case .writing: break
        }
        let note = reading
        let dated = note.due != nil || note.at != nil || (readsDate && presetDay != nil)
        return dated ? String(localized: "달력에 남기기") : String(localized: "메모 남기기")
    }

    /// 지금 글이 누구에게 가는가 — 단추의 동사, 칩의 유무, 빈 목록의 한 줄이 이것으로 갈린다.
    /// 「이거」를 들고 있으면 묻는 말이 아닌 것은 전부 그 메모에게 시키는 말이다 — 동사가 없어도 (「금요일 10시」).
    enum Saying: Equatable { case writing, asking, telling }
    var saying: Saying {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard assistant != nil, !trimmed.isEmpty, pending == nil, planner?.isActive != true else { return .writing }
        if AssistantIntent.isQuestion(trimmed) { return .asking }
        if target != nil || AssistantIntent.hasCommandVerb(trimmed) { return .telling }
        return .writing
    }

    /// 칩 하나 — 날짜. 끈 뒤에도 글이 그대로면 칩도 그대로다 (꺼진 모양으로).
    var dateChip: String? {
        let note = readAll
        if let at = note.at { return String(localized: "\(DayWords.long(CalendarDate(at))) \(DayWords.clock(at)) · 달력으로") }
        if let due = note.due { return String(localized: "\(DayWords.long(due)) · 달력으로") }
        if let presetDay { return String(localized: "\(DayWords.long(presetDay)) · 달력으로") }
        return nil
    }

    var placeChip: String? {
        guard let place = here?.place ?? readAll.place else { return nil }
        return "@" + place
    }

    var everyChip: String? {
        readAll.every.map { $0.text() }
    }

    // MARK: 적기 끝

    /// `store.create` — 새 줄이 펜 바로 위로 들어온다. 글 칸은 비고 키보드는 남는다.
    @discardableResult
    func leave() async -> Memo? {
        guard canLeave else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 가는 길의 되물음 — 출발지든 탈것이든 무슨 말이든 그 답이다 (「됐어」는 물러나는 답).
        if let planner, planner.isWaiting {
            planner.reply(trimmed)
            text = ""; draft.forget()
            return nil
        }

        // 되물음의 답 — 「12시야」. 답이 아니면 초안을 놓고 새 말로 본다.
        if let pending {
            if let done = AssistantIntent.complete(draft: pending.draft, reply: trimmed) {
                self.pending = nil
                return await create(done.patch)
            }
            self.pending = nil
        }

        if let assistant {
            // 물음 — 메모가 답한다. 목록은 근거로 줄어든다 (D9). 「이거」가 있으면 그 메모부터 읽는다.
            if AssistantIntent.isQuestion(trimmed) {
                handOff(trimmed)
                assistant.ask(trimmed, selected: target)
                return nil
            }
            // 시키는 말 — 대상은 편집 화면에서 들고 온 「이거」, 없으면 비서가 되묻고 목록이 후보가 된다 (D10).
            if target != nil || AssistantIntent.hasCommandVerb(trimmed) {
                handOff(trimmed)
                assistant.command(trimmed, selected: target)
                return nil
            }
            // 약속인데 시각이 없다 — 한 가지만 묻고 펜은 답을 기다린다 (D6).
            if readsDate, let composed = AssistantIntent.compose(trimmed), composed.kind == .ask, var draftPatch = composed.draft {
                let note = reading
                if draftPatch.place == nil { draftPatch.place = note.place; draftPatch.geo = here?.geo ?? note.geo }
                pending = (composed.question ?? String(localized: "약속 시간이 언제인가요?"), draftPatch)
                text = ""; draft.forget()
                return nil
            }
        }

        let note = reading
        var schedule = Schedule(due: note.due, at: note.at)
        var body = note.body
        if readsDate, let presetDay, schedule.isEmpty {
            let drafted = QuickSchedule.make(from: body, on: presetDay)
            schedule = drafted.schedule
            body = drafted.body
        }

        let memo = try? await store.create(
            body: body, due: schedule.due, at: schedule.at, every: note.every,
            place: note.place, geo: here?.geo ?? note.geo, folder: folder
        )
        guard let memo else { return nil }
        finishLeaving(memo)
        return memo
    }

    /// 비서의 초안으로 적는다 — 되물음이 끝났을 때, 또는 ⊗·시각 없이.
    @discardableResult
    func create(_ patch: FieldPatch) async -> Memo? {
        let memo = try? await store.create(
            body: patch.body ?? "", due: patch.due.value, at: patch.at.value,
            place: patch.place, geo: patch.geo, folder: folder
        )
        guard let memo else { return nil }
        finishLeaving(memo)
        return memo
    }

    private func finishLeaving(_ memo: Memo) {
        lastLeft = memo.id
        text = ""
        draft.forget()
        here = nil
        readsDate = true
        readsPlace = true
        readsEvery = true
        prompt = CapturePrompt.next(after: prompt)
        // 앞으로 올 약속에 자리가 있으면 펜이 「어디서 출발하시나요?」를 세운다. 아니면 아무 일도 없다.
        planner?.begin(memo)
    }

    /// 뒤로 물러날 때 적던 글을 파일에 내린다.
    func flush() { draft.flush() }

    // MARK: 찾기 — 한 글자부터 무더기가 찾은 것으로 바뀐다

    private static let searchDelay: Duration = .milliseconds(100)
    static let searchCeiling = 20

    private func reschedule() {
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            found = nil
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled, let self else { return }
            await self.find(query)
        }
    }

    /// 두 걸음 — 인덱스는 낱말만 알고, 생김새·장소·날짜는 메모를 손에 쥐어야
    /// 볼 수 있다 (`QuickCaptureModel.find` 와 같다).
    private func find(_ query: String) async {
        // 비서에게 갈 말은 낱말로 줄 세운다 (맥의 상자와 같다, D9·D10) — 「치과 언제였지?」는 어느 메모의 문장도
        // 아니라 구(phrase)로는 안 잡힌다. 이 목록이 곧 근거 후보고, 시키는 말이면 대상 후보다. 시키는 말에 걸리는
        // 낱말이 없으면 목록을 비우지 않는다 — 「금요일 10시에 다시 알려줘」는 어느 메모의 낱말도 아니다.
        if assistant != nil, saying != .writing {
            let ranked = MemoRanker.search(query, in: store.active, limit: Self.searchCeiling)
            if !ranked.isEmpty || saying == .asking { found = ranked }
            return
        }
        let condition = MemoFilter.read(query)
        let words = condition.words.trimmingCharacters(in: .whitespacesAndNewlines)
        var pool: [Memo]
        if HangulInitials.isInitialsQuery(words) {
            // 첫소리는 인덱스가 모른다 — 메모리를 훑는다.
            pool = store.memos.filter { HangulInitials.matches($0.title + "\n" + $0.body, query: words) }
        } else {
            pool = await store.search(words, limit: Self.searchCeiling)
            // 구로 못 찾은 여러 낱말은 낱말 랭킹으로 한 번 더 — 「엄마 선물」이 「엄마 생신 선물」을 찾게 (맥과 같다).
            if pool.isEmpty, words.contains(" ") { pool = MemoRanker.search(words, in: store.active, limit: Self.searchCeiling) }
        }
        guard !Task.isCancelled else { return }
        found = condition.narrows ? pool.filter { condition.matches($0) } : pool
    }

    /// 목록을 지금 상태로 다시 짓는다 — 지운 직후처럼 기다릴 이유가 없을 때.
    func refresh() async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { found = nil; return }
        await find(query)
    }
}

/// 칩과 머리글에 적는 날의 낱말. `MemoTimeLabel` 은 목록의 짧은 조각이고,
/// 여기는 「9월 14일 (일)」처럼 조금 더 긴 자리다.
enum DayWords {
    static func long(_ day: CalendarDate, calendar: Calendar = .current) -> String {
        DateWords.monthDayWeekday(day, calendar: calendar)
    }

    static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
