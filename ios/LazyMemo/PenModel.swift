import Foundation
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
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
            if shown != nil || assistant?.answer != nil || assistant?.proposal != nil || assistant?.phase == .thinking {
                shown = nil
                assistant?.reset()
            }
        }
    }

    // MARK: 비서 — 펜 하나가 묻기·시키기·되묻기까지 겸한다 (맥의 QuickCaptureModel 과 같은 갈래)

    /// 이 기기의 비서. 없으면(시험) 펜은 적기와 찾기만 한다.
    var assistant: AssistantModel? {
        didSet { assistant?.onSettled = { [weak self] in self?.reflectAssistant() } }
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

    /// 목록의 출처 — 찾은 것, 아니면 비서가 정한 것.
    enum Listing: Equatable { case search, evidence, related, candidates }
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
        if let answer = assistant.answer {
            showMemos(answer.found ? answer.evidence : assistant.relatedMemos.map(\.memoID), as: answer.found ? .evidence : .related)
        } else if let proposal = assistant.proposal, proposal.kind == .ask, !proposal.candidates.isEmpty {
            showMemos(proposal.candidates, as: .candidates)
        } else if case .failed = assistant.phase, !assistant.relatedMemos.isEmpty {
            showMemos(assistant.relatedMemos.map(\.memoID), as: .related)
        } else if assistant.receipt != nil {
            shown = nil; listing = .search
            Task { await refresh() }
        }
    }

    /// 「어느 메모?」의 후보 하나를 골랐다 — 같은 말을 그 메모에게.
    func pick(_ id: ULID) { assistant?.pick(id) }

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
        if pending != nil { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return InboundNote.make(text: text) != nil || here != nil
    }

    /// 단추의 라벨이 곧 동사다 (quick-capture-assistant D5): 답하기 · 시키기 · 메모에게 묻기 · 달력에 남기기 · 메모 남기기.
    /// 달력이 물린 날도 칩을 끄면 안 쓰이므로(`leave`) 단추도 같이 바뀐다.
    var leaveLabel: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if pending != nil { return String(localized: "답하기") }
        if assistant != nil, !trimmed.isEmpty {
            if AssistantIntent.hasCommandVerb(trimmed) { return String(localized: "시키기") }
            if AssistantIntent.isQuestion(trimmed) { return String(localized: "메모에게 묻기") }
        }
        let note = reading
        let dated = note.due != nil || note.at != nil || (readsDate && presetDay != nil)
        return dated ? String(localized: "달력에 남기기") : String(localized: "메모 남기기")
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

        // 되물음의 답 — 「12시야」. 답이 아니면 초안을 놓고 새 말로 본다.
        if let pending {
            if let done = AssistantIntent.complete(draft: pending.draft, reply: trimmed) {
                self.pending = nil
                return await create(done.patch)
            }
            self.pending = nil
        }

        if let assistant {
            // 시키는 말 — 대상은 비서가 되묻고 목록이 후보가 된다 (D10). 열린 메모는 편집 화면의 시트가 맡는다.
            if AssistantIntent.hasCommandVerb(trimmed) {
                let said = trimmed
                text = ""; draft.forget()
                assistant.command(said)
                return nil
            }
            // 물음 — 메모가 답한다. 목록은 근거로 줄어든다 (D9).
            if AssistantIntent.isQuestion(trimmed) {
                let said = trimmed
                text = ""; draft.forget()
                assistant.ask(said)
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
        let condition = MemoFilter.read(query)
        let words = condition.words.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool: [Memo]
        if HangulInitials.isInitialsQuery(words) {
            // 첫소리는 인덱스가 모른다 — 메모리를 훑는다.
            pool = store.memos.filter { HangulInitials.matches($0.title + "\n" + $0.body, query: words) }
        } else {
            pool = await store.search(words, limit: Self.searchCeiling)
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
