import Foundation

/// 시각 없는 날짜 (설계문서 §5.2 의 `due`).
///
/// `Date` 를 쓰지 않는 이유: "9월 1일 마감"은 특정 순간이 아니라 달력 위의 칸이다.
/// `Date` 로 담으면 타임존이 바뀔 때마다 하루씩 밀린다.
public struct CalendarDate: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// `2026-09-01` 만 받는다. 느슨하게 파싱하면 잘못된 날짜가 조용히 저장된다.
    public init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 정렬·범위 비교용. 자릿수가 겹치지 않아 단순 정수 비교로 충분하다.
    private var sortKey: Int { year * 10_000 + month * 100 + day }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    /// 캘린더 범위 쿼리에서 그 날의 시작 시각이 필요할 때.
    public func startOfDay(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// 다음 자정. 하루가 바뀌는 순간에 깨야 하는 것들이 이 시각을 쓴다.
    ///
    /// **더하기 24시간이 아니다.** 서머타임이 있는 지역에서는 하루가 23시간
    /// 이거나 25시간이라, 24시간을 더하면 자정을 놓치거나 한 시간 일찍 깬다.
    /// `Calendar` 에게 "다음 날의 시작" 을 묻는 것이 유일하게 맞는 길이다.
    public static func nextMidnight(after now: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    }

    /// 며칠 뒤(앞)의 날. 달과 해를 넘기는 계산은 `Calendar` 에 맡긴다 —
    /// 31일에 하루를 더하는 일은 손으로 하면 반드시 틀린다.
    public func adding(days: Int, calendar: Calendar = .current) -> CalendarDate {
        guard let start = startOfDay(calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: start)
        else { return self }
        return CalendarDate(moved, calendar: calendar)
    }
}
