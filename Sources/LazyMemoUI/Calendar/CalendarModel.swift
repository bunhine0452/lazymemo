import Foundation
import LazyMemoCore
import Observation

/// 바탕화면 캘린더의 상태 (설계문서 §10).
///
/// 별도 이벤트 타입이 없다 — `due` 나 `at` 이 채워진 메모가 곧 일정이다.
@MainActor
@Observable
final class CalendarModel {
    private(set) var grid: MonthGrid
    /// 날짜 → 그 날의 메모. 키는 `CalendarDate.description`("2026-09-01").
    private(set) var eventsByDay: [String: [Memo]] = [:]
    var selectedDay: CalendarDate?

    private let store: MemoStore
    private let today: CalendarDate

    init(store: MemoStore, now: Date = Date()) {
        self.store = store
        self.grid = MonthGrid.current(now)
        self.today = CalendarDate(now)
    }

    func isToday(_ date: CalendarDate) -> Bool { date == today }

    var isShowingCurrentMonth: Bool {
        grid.year == today.year && grid.month == today.month
    }

    func events(on date: CalendarDate) -> [Memo] {
        eventsByDay[date.description] ?? []
    }

    var selectedEvents: [Memo] {
        selectedDay.map(events(on:)) ?? []
    }

    // MARK: 이동

    func step(_ months: Int) {
        grid = grid.advanced(by: months)
        selectedDay = nil
        Task { await refresh() }
    }

    func goToToday() {
        grid = MonthGrid.make(year: today.year, month: today.month)
        selectedDay = today
        Task { await refresh() }
    }

    // MARK: 조회

    /// 격자가 덮는 **전체** 범위를 묻는다. 이번 달만 물으면 앞뒤 달에서
    /// 넘어온 칸의 일정이 빠져 달력에 구멍이 생긴다.
    func refresh() async {
        guard let range = grid.range else { return }
        let memos = await store.scheduled(from: range.lowerBound, to: range.upperBound)

        var grouped: [String: [Memo]] = [:]
        for memo in memos {
            guard let date = memo.scheduledDate() else { continue }
            grouped[date.description, default: []].append(memo)
        }
        // 하루 안에서는 시각이 있는 것부터.
        eventsByDay = grouped.mapValues { day in
            day.sorted { left, right in
                switch (left.at, right.at) {
                case (let l?, let r?): l < r
                case (_?, nil): true
                case (nil, _?): false
                default: left.updated > right.updated
                }
            }
        }
    }
}
