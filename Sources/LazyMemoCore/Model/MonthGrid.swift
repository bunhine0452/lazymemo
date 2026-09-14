import Foundation

/// 한 달치 달력 격자 (설계문서 §10).
///
/// AppKit·SwiftUI 밖에 두는 이유는 이 계산이 틀리기 쉽고 눈으로는 잘 안
/// 보이기 때문이다 — 주 시작 요일, 앞뒤 달 넘침, 2월, 윤년. 순수 값으로
/// 만들어 테스트로 못 박는다.
public struct MonthGrid: Sendable, Equatable {
    public struct Day: Sendable, Equatable, Identifiable {
        public let date: CalendarDate
        /// 이번 달이 아니라 앞뒤 달에서 넘어온 칸.
        public let isOverflow: Bool

        public var id: String { date.description }
    }

    public let year: Int
    public let month: Int
    /// 항상 7의 배수. 주 단위로 잘라 쓰면 된다.
    public let days: [Day]

    public var weeks: [[Day]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    /// 격자가 덮는 전체 범위. 인덱스 날짜 범위 조회에 그대로 넘긴다 —
    /// 앞뒤 달에서 넘어온 칸의 일정도 보여야 하므로 이번 달 범위로는 부족하다.
    public var range: ClosedRange<CalendarDate>? {
        guard let first = days.first?.date, let last = days.last?.date else { return nil }
        return first...last
    }

    /// 「2026년 9월」 · 「September 2026」.
    public var title: String { title() }

    public func title(locale: Locale = .current) -> String {
        DateWords.yearMonth(year: year, month: month, locale: locale)
    }

    /// - Parameter firstWeekday: 1 = 일요일 (한국·미국 관행), 2 = 월요일.
    public static func make(
        year: Int,
        month: Int,
        firstWeekday: Int = 1,
        calendar baseCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> MonthGrid {
        var calendar = baseCalendar
        calendar.firstWeekday = firstWeekday

        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            return MonthGrid(year: year, month: month, days: [])
        }

        // 1일이 격자에서 몇 칸째인가. 주 시작 요일을 바꿔도 맞아야 한다.
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekdayOfFirst - firstWeekday + 7) % 7

        var days: [Day] = []

        for offset in stride(from: leading, to: 0, by: -1) {
            if let date = calendar.date(byAdding: .day, value: -offset, to: firstOfMonth) {
                days.append(Day(date: CalendarDate(date, calendar: calendar), isOverflow: true))
            }
        }
        for dayNumber in range {
            days.append(Day(
                date: CalendarDate(year: year, month: month, day: dayNumber),
                isOverflow: false
            ))
        }
        // 마지막 주를 채운다. 빈칸을 두면 격자가 무너져 보인다.
        let trailing = (7 - days.count % 7) % 7
        if trailing > 0, let lastOfMonth = calendar.date(
            from: DateComponents(year: year, month: month, day: range.count)
        ) {
            for offset in 1...trailing {
                if let date = calendar.date(byAdding: .day, value: offset, to: lastOfMonth) {
                    days.append(Day(date: CalendarDate(date, calendar: calendar), isOverflow: true))
                }
            }
        }

        return MonthGrid(year: year, month: month, days: days)
    }

    /// 이웃 달로 이동. 12월 다음은 다음 해 1월이다.
    public func advanced(by months: Int) -> MonthGrid {
        let zeroBased = (year * 12 + (month - 1)) + months
        return .make(year: zeroBased / 12, month: zeroBased % 12 + 1)
    }

    public static func current(
        _ date: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> MonthGrid {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return .make(year: parts.year ?? 2026, month: parts.month ?? 1)
    }
}
