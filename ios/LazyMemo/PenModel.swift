import Foundation
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
        }
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

    var canLeave: Bool { InboundNote.make(text: text) != nil || here != nil }

    /// 날짜가 읽혔으면(또는 달력이 물렸으면) 단추가 그렇게 말한다.
    /// 달력이 물린 날도 칩을 끄면 안 쓰이므로(`leave`) 단추도 같이 바뀐다.
    var leaveLabel: String {
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

        lastLeft = memo.id
        text = ""
        draft.forget()
        here = nil
        readsDate = true
        readsPlace = true
        readsEvery = true
        prompt = CapturePrompt.next(after: prompt)
        return memo
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
