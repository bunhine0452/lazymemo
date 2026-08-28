import Foundation
import LazyMemoCore
import Observation

/// 「흐름」의 상태 — 격자가 아니라 시간순으로 흐르는 목록 (철학 2).
///
/// 월 격자를 버린 이유는 그것이 **조망을 위한 도구**이기 때문이다. 게으른
/// 사람이 알고 싶은 것은 "이번 달 전체 지도" 가 아니라 "다음에 뭐가 오나" 다.
/// 그래서 오늘을 기준으로 아래로 흐르고, 아무것도 없는 날은 아예 나타나지 않는다.
///
/// 날짜 없는 메모는 흐름에 없다. 그것은 시간 위의 물건이 아니라 바탕화면
/// 위의 물건이고, 여기서 억지로 자리를 주면 축이 흐려진다.
@MainActor
@Observable
final class StreamModel {
    struct Day: Identifiable, Equatable {
        let date: CalendarDate
        let memos: [Memo]
        var id: String { date.description }
    }

    /// 앞으로 이만큼까지 내다본다. 그 너머는 게으른 사람의 관심 밖이다.
    private static let horizonDays = 180
    /// 지난 것을 펼쳤을 때 거슬러 올라가는 범위.
    private static let retrospectDays = 90

    private(set) var days: [Day] = []
    /// 상단 점 스트립이 보여줄 달.
    private(set) var strip: MonthGrid
    /// 날짜별 메모 수. 스트립의 점 굵기를 정한다.
    private(set) var stripCounts: [String: Int] = [:]

    /// 지난 것을 함께 보일지. 기본은 앞만 본다.
    var showsPast = false {
        didSet { Task { await refresh() } }
    }

    let today: CalendarDate
    private let store: MemoStore
    private let calendar: Calendar

    init(store: MemoStore, now: Date = Date(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        self.today = CalendarDate(now, calendar: calendar)
        self.strip = MonthGrid.current(now, calendar: Calendar(identifier: .gregorian))
    }

    func isToday(_ date: CalendarDate) -> Bool { date == today }

    /// 오늘이 흐름 어디쯤인지. 처음 열 때 그 자리로 보낸다.
    var todayIndex: Int? {
        days.firstIndex { $0.date == today }
    }

    var isEmpty: Bool { days.isEmpty }

    // MARK: 이동

    func stepStrip(_ months: Int) {
        strip = strip.advanced(by: months)
        Task { await refreshStrip() }
    }

    func resetStrip() {
        strip = MonthGrid.make(year: today.year, month: today.month)
        Task { await refreshStrip() }
    }

    var isStripOnCurrentMonth: Bool {
        strip.year == today.year && strip.month == today.month
    }

    // MARK: 조회

    func refresh() async {
        await refreshStream()
        await refreshStrip()
    }

    private func refreshStream() async {
        guard let start = bound(days: showsPast ? -Self.retrospectDays : 0),
              let end = bound(days: Self.horizonDays)
        else { return }

        let memos = await store.scheduled(from: start, to: end)

        var grouped: [String: [Memo]] = [:]
        for memo in memos {
            guard let date = memo.scheduledDate(calendar: calendar) else { continue }
            grouped[date.description, default: []].append(memo)
        }

        var result: [Day] = grouped.compactMap { key, memos in
            guard let date = CalendarDate(iso: key) else { return nil }
            return Day(date: date, memos: sortWithinDay(memos))
        }

        // 오늘은 비어 있어도 자리를 지킨다. 기준점이 사라지면 흐름을 읽을 수 없다.
        if !result.contains(where: { $0.date == today }) {
            result.append(Day(date: today, memos: []))
        }

        days = result.sorted { $0.date < $1.date }
    }

    /// 스트립은 흐름과 다른 달을 볼 수 있으므로 따로 묻는다.
    private func refreshStrip() async {
        guard let range = strip.range else { return }
        let memos = await store.scheduled(from: range.lowerBound, to: range.upperBound)

        var counts: [String: Int] = [:]
        for memo in memos {
            guard let date = memo.scheduledDate(calendar: calendar) else { continue }
            counts[date.description, default: 0] += 1
        }
        stripCounts = counts
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

    private func bound(days offset: Int) -> CalendarDate? {
        guard let base = today.startOfDay(calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: offset, to: base)
        else { return nil }
        return CalendarDate(moved, calendar: calendar)
    }
}
