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
        let to: CalendarDate
    }

    /// 되돌리기 줄이 머무는 시간. 이보다 길면 화면에 눌어붙고, 짧으면 놓친다.
    private static let undoWindow = Duration.seconds(8)

    private(set) var grid: MonthGrid
    /// 날짜별 일정. 격자와 아래 판이 같은 것을 본다.
    private(set) var byDay: [String: [Memo]] = [:]
    /// 아래 판이 펼쳐 보이는 날. 처음에는 오늘이다.
    private(set) var selected: CalendarDate
    private(set) var lastMove: Move?
    /// 마지막으로 실패한 조작. 조용히 삼키지 않는다.
    private(set) var failure: String?

    let today: CalendarDate

    private let store: MemoStore
    private let calendar: Calendar
    private var undoTask: Task<Void, Never>?

    init(store: MemoStore, now: Date = Date(), calendar: Calendar = .current) {
        self.store = store
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

    // MARK: 동사

    /// 다른 날로 옮긴다 — 끌어다 놓기의 착지점.
    func move(_ memo: Memo, to date: CalendarDate) async {
        let before = Schedule(memo)
        guard before.day(calendar: calendar) != date else { return }
        await write(before.moved(to: date, calendar: calendar), to: memo.id)
        remember(Move(id: memo.id, from: before, to: date))
        select(date)
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
            await refresh()
        } catch {
            failure = "적기 실패: \(error)"
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
        undoTask?.cancel()
    }

    // MARK: 내부

    private func write(_ schedule: Schedule, to id: ULID) async {
        do {
            // 자리를 통째로 쓴다. 한쪽만 건드리면 한 메모가 두 날에 선다.
            _ = try await store.update(id, due: .some(schedule.due), at: .some(schedule.at))
            failure = nil
            await refresh()
        } catch {
            failure = "옮기기 실패: \(error)"
        }
    }

    private func remember(_ move: Move) {
        lastMove = move
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.lastMove = nil
        }
    }
}
