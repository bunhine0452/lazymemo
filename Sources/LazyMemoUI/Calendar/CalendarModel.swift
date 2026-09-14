import Foundation
import LazyMemoCore
import Observation

/// 「달력」의 상태 (설계문서 §10).
///
/// 앞선 판(「흐름」)은 **읽기만 하는 화면**이었다. 아래로 흐르는 목록에서 할 수
/// 있는 일은 스크롤과 메모 열기뿐이었고, 달력을 만지는 동사 — 넣기·옮기기·
/// 미루기 — 는 하나도 없었다. 게으른 사람이 달력에 실제로 하는 일이 그 셋인데
/// 그 셋이 전부 앱 밖(빠른 입력, 메모 창)에 있었다는 뜻이다.
///
/// 그래서 이 모델은 화면이 아니라 **동사**를 중심으로 짜여 있다. 조회는 두 줄
/// 이고, 나머지는 전부 옮기기·미루기·적기·되돌리기다.
@MainActor
@Observable
final class CalendarModel {
    /// 방금 한 옮기기. 되돌리기 한 줄이 여기 걸린다.
    struct Move: Equatable {
        let id: ULID
        /// 옮기기 **전**의 자리. 되돌리기는 이것을 그대로 되쓴다.
        let from: Schedule
        /// 내려앉은 날. `nil` 이면 달력에서 내려온 것이다 — 날짜를 뗐으므로
        /// 그 메모는 바탕화면의 종이로 돌아간다 (설계문서 §7.2).
        let to: CalendarDate?
    }

    /// 되돌리기 줄이 머무는 시간. 이보다 길면 화면에 눌어붙고, 짧으면 놓친다.
    private static let undoWindow = Duration.seconds(8)

    private(set) var grid: MonthGrid
    /// 날짜별 일정. 격자와 아래 판이 같은 것을 본다.
    private(set) var byDay: [String: [Memo]] = [:]
    /// 시스템 캘린더에서 빌려 온 일정. **아래 판에만 선다.**
    ///
    /// 격자의 번진 잉크(§10.4)에는 넣지 않는다. 그 밀도는 «내가 쌓아 둔 것» 을
    /// 말하는 것이고, 남의 회의까지 세면 평일이 전부 똑같이 붐벼 보인다 —
    /// 밀도가 아무것도 알려 주지 않게 된다.
    private(set) var foreignByDay: [String: [ForeignEvent]] = [:]
    /// 아래 판이 펼쳐 보이는 날. 처음에는 오늘이다.
    private(set) var selected: CalendarDate
    private(set) var lastMove: Move?
    /// 방금 여기서 지운 일정. 되돌리는 줄이 바닥에 떠 있는 동안만 값이 있다 (D6).
    ///
    /// 달력 줄에는 「미루기」와 「종이로」는 있는데 지우는 길만 없었다. 그래서
    /// 필요 없어진 일정을 치우려면 날짜를 떼어 종이로 내려보낸 뒤 그 종이를
    /// 찾아 지워야 했다 — 조작 셋이고, 그 사이 바탕화면에 종이가 한 장 난다.
    private(set) var lastDeleted: Memo?
    /// 종이에서 건너와 **놓을 날을 기다리는** 메모 (설계문서 §7.2).
    ///
    /// 날짜를 글자로 치게 하지 않는다. 달력 위에서 날짜를 가리키는 방법은
    /// 이미 하나 있고(끌어다 놓기), 그것과 같은 낱말을 쓴다 — 다른 점은
    /// 집어 든 자리가 달력 밖이라는 것뿐이다.
    private(set) var holding: Memo?
    /// 마지막으로 실패한 조작. 조용히 삼키지 않는다.
    private(set) var failure: String?

    /// 오늘. **`let` 이었다.**
    ///
    /// 창을 만들 때 한 번 잡고 앱이 꺼질 때까지 그대로였는데, 이 앱은 바탕화면에
    /// 상주하므로 며칠씩 안 꺼진다. 자정이 지나면 동그라미가 어제 칸에 남고,
    /// 「오늘」 버튼이 어제로 가고, 「미루기」가 어제를 기준으로 세어 **오늘로
    /// 미뤘다.** 이제 `DayClock` 이 넘겨 준다.
    private(set) var today: CalendarDate

    private let store: MemoStore
    private let calendar: Calendar
    /// 남의 일정을 **읽기만** 하는 문. 권한이 없거나 꺼져 있으면 빈 문이 선다.
    private let feed: CalendarFeed
    private var undoTask: Task<Void, Never>?

    init(
        store: MemoStore,
        feed: CalendarFeed = EmptyCalendarFeed(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.feed = feed
        self.calendar = calendar
        let today = CalendarDate(now, calendar: calendar)
        self.today = today
        self.selected = today
        self.grid = MonthGrid.make(year: today.year, month: today.month)
    }

    // MARK: 조회

    func memos(on date: CalendarDate) -> [Memo] {
        byDay[date.description] ?? []
    }

    var selectedMemos: [Memo] { memos(on: selected) }

    /// 아래 판에 서는 줄 — 우리 종이와 남의 일정이 한 줄기로 (`DayAgenda`).
    func rows(on date: CalendarDate) -> [AgendaRow] {
        DayAgenda.rows(
            memos: memos(on: date),
            events: foreignByDay[date.description] ?? []
        )
    }

    var selectedRows: [AgendaRow] { rows(on: selected) }

    func isToday(_ date: CalendarDate) -> Bool { date == today }

    var isOnToday: Bool { selected == today && grid.year == today.year && grid.month == today.month }

    func refresh() async {
        guard let range = grid.range else { return }
        let memos = await store.scheduled(from: range.lowerBound, to: range.upperBound)

        var grouped: [String: [Memo]] = [:]
        for memo in memos {
            guard let date = memo.scheduledDate(calendar: calendar) else { continue }
            grouped[date.description, default: []].append(memo)
        }
        byDay = grouped.mapValues(sortWithinDay)

        // 남의 일정은 우리 것을 다 세운 **뒤에** 얹는다. 캘린더가 느리거나
        // 권한이 없어도 내 메모는 이미 화면에 있다.
        let events = await feed.events(from: range.lowerBound, to: range.upperBound)
        var borrowed: [String: [ForeignEvent]] = [:]
        for event in events {
            borrowed[event.day(calendar: calendar).description, default: []].append(event)
        }
        foreignByDay = borrowed
    }

    /// 하루 안에서는 시각이 있는 것부터, 그 다음 최근 수정 순.
    private func sortWithinDay(_ memos: [Memo]) -> [Memo] {
        memos.sorted { left, right in
            switch (left.at, right.at) {
            case (let l?, let r?): l < r
            case (_?, nil): true
            case (nil, _?): false
            default: left.updated > right.updated
            }
        }
    }

    // MARK: 이동

    /// 이웃 달로. 고른 날은 같은 날짜를 그 달에서 이어 잡는다 — 선택이 격자
    /// 밖으로 빠지면 아래 판이 보이지 않는 날을 펼치게 된다.
    func stepMonth(_ delta: Int) {
        grid = grid.advanced(by: delta)
        let length = grid.days.filter { !$0.isOverflow }.count
        selected = CalendarDate(
            year: grid.year, month: grid.month, day: min(selected.day, max(length, 1))
        )
        Task { await refresh() }
    }

    func select(_ date: CalendarDate) {
        selected = date
        guard date.year != grid.year || date.month != grid.month else { return }
        // 앞뒤 달에서 넘어온 칸을 고르면 그 달로 넘어간다. 달력의 오랜 관행이고,
        // 고른 날이 격자 가장자리에 걸린 채로 남는 것보다 읽기 쉽다.
        grid = MonthGrid.make(year: date.year, month: date.month)
        Task { await refresh() }
    }

    func goToday() {
        selected = today
        grid = MonthGrid.make(year: today.year, month: today.month)
        Task { await refresh() }
    }

    /// 하루가 바뀌었다 (`DayClock`).
    ///
    /// 고른 날이 **어제의 오늘**이었으면 함께 넘어간다 — 창을 열어 둔 채로
    /// 자정을 넘긴 사람에게 어제가 펼쳐져 있으면 그것부터가 거짓말이다.
    /// 일부러 다른 날을 골라 둔 사람은 건드리지 않는다: 사람이 정한 것이 이긴다.
    func dayChanged(to newToday: CalendarDate) {
        guard newToday != today else { return }
        let wasOnToday = selected == today
        today = newToday
        // 지난 일정을 미루면 어디로 가는지도 오늘을 기준으로 다시 셈해진다.
        if wasOnToday {
            goToday()
        } else {
            Task { await refresh() }
        }
    }

    // MARK: 동사

    /// 다른 날로 옮긴다 — 끌어다 놓기의 착지점.
    func move(_ memo: Memo, to date: CalendarDate) async {
        let before = Schedule(memo)
        guard before.day(calendar: calendar) != date else { return }
        await write(before.moved(to: date, calendar: calendar), to: memo.id)
        remember(Move(id: memo.id, from: before, to: date))
        select(date)
    }

    /// 종이에서 건너온 메모를 받아 든다. 놓을 날은 사용자가 가리킨다.
    func hold(_ memo: Memo) {
        holding = memo
        failure = nil
    }

    /// 놓기를 그만둔다. 들고 있던 것은 그대로 종이로 남는다.
    func cancelHold() { holding = nil }

    /// 들고 있던 것을 그 날에 놓는다 — 종이에서 달력으로 건너오는 마지막 한 걸음.
    func place(on date: CalendarDate) async {
        guard let memo = holding else { return }
        holding = nil
        await move(memo, to: date)
    }

    /// 날짜를 뗀다 — 일정이 다시 그냥 메모가 되어 바탕화면의 종이로 돌아간다.
    ///
    /// 「미루기」의 짝이다. 미루기가 *언제*를 고치는 것이라면 이것은 *어디*를
    /// 고친다. 언제 할지 모르겠다고 판명된 일을 달력에 남겨 두면 그 날이 와서
    /// 지나가고, 그 다음부터 달력은 지나간 일로 채워진다.
    func detach(_ memo: Memo) async {
        let before = Schedule(memo)
        guard !before.isEmpty else { return }
        await write(Schedule(), to: memo.id, verb: L("종이로 보내기"))
        remember(Move(id: memo.id, from: before, to: nil))
    }

    /// 이 일정을 지운다. 휴지통 이동뿐이고(D6) 되돌리는 줄이 바로 아래에 생긴다.
    ///
    /// **날짜를 떼는 것과 다른 일이다.** 「종이로」는 언제 할지 모르겠다는
    /// 뜻이고 이것은 안 하겠다는 뜻이다. 그 둘을 한 버튼에 묶으면 달력에서
    /// 없애는 유일한 길이 바탕화면에 종이를 한 장 내는 길이 된다.
    func delete(_ memo: Memo) async {
        do {
            try await store.delete(memo.id)
            failure = nil
            lastMove = nil
            lastDeleted = memo
            forget { $0.lastDeleted = nil }
            await refresh()
        } catch {
            failure = L("지우기 실패: \(String(describing: error))")
        }
    }

    /// 방금 지운 것을 되살린다.
    func restoreDeleted() async {
        guard let memo = lastDeleted else { return }
        lastDeleted = nil
        undoTask?.cancel()
        try? await store.restore(memo.id)
        await refresh()
    }

    /// 하루 미룬다 — 게으른 사람이 달력에 가장 자주 하는 일.
    func postpone(_ memo: Memo) async {
        let before = Schedule(memo)
        let after = before.postponed(notBefore: today, calendar: calendar)
        guard let landing = after.day(calendar: calendar) else { return }
        await write(after, to: memo.id)
        remember(Move(id: memo.id, from: before, to: landing))
    }

    /// 미루면 며칠로 가는지. 누르기 **전에** 말해 준다.
    func postponeTarget(_ memo: Memo) -> CalendarDate? {
        Schedule(memo).postponed(notBefore: today, calendar: calendar).day(calendar: calendar)
    }

    /// 고른 날에 한 줄 적는다. 형식은 없다 — "오후 3시 치과" 면 그것이 곧 약속이다.
    func add(_ text: String) async {
        let draft = QuickSchedule.make(from: text, on: selected, calendar: calendar)
        guard !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            _ = try await store.create(
                body: draft.body, due: draft.schedule.due, at: draft.schedule.at
            )
            failure = nil
            // 적은 줄이 고른 날에 떨어지지 않을 수 있다 — "내일 3시" 라고
            // 쳤으면 적은 쪽이 이긴다 (`QuickSchedule`). 그러면 방금 적은 것이
            // 보이지 않는 날에 놓이므로, 옮기기와 마찬가지로 **간 곳을 펼쳐
            // 보여준다.** 종이가 나지 않는 이상(§7.2) 여기 말고는 확인할 자리가
            // 없다.
            if let landing = draft.schedule.day(calendar: calendar), landing != selected {
                select(landing)
            }
            await refresh()
        } catch {
            failure = L("적기 실패: \(String(describing: error))")
        }
    }

    /// 옮기기를 되돌린다. 들고 있던 **옮기기 전의 자리**를 통째로 되쓴다.
    func undo() async {
        guard let move = lastMove else { return }
        await write(move.from, to: move.id)
        lastMove = nil
        undoTask?.cancel()
        if let day = move.from.day(calendar: calendar) { select(day) }
    }

    func dismissUndo() {
        lastMove = nil
        lastDeleted = nil
        undoTask?.cancel()
    }

    // MARK: 내부

    private func write(_ schedule: Schedule, to id: ULID, verb: String = L("옮기기")) async {
        do {
            // 자리를 통째로 쓴다. 한쪽만 건드리면 한 메모가 두 날에 선다.
            _ = try await store.update(id, due: .some(schedule.due), at: .some(schedule.at))
            failure = nil
            await refresh()
        } catch {
            failure = L("\(verb) 실패: \(String(describing: error))")
        }
    }

    private func remember(_ move: Move) {
        lastMove = move
        // 바닥의 한 줄은 하나뿐이다. 방금 한 일이 둘이면 사람은 어느 것을
        // 되돌리는지 모른다 — 마지막 것만 남긴다.
        lastDeleted = nil
        forget { $0.lastMove = nil }
    }

    /// 되돌리는 줄을 시간이 지나면 스스로 물리게 한다.
    private func forget(_ clear: @escaping (CalendarModel) -> Void) {
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled, let self else { return }
            clear(self)
        }
    }
}
