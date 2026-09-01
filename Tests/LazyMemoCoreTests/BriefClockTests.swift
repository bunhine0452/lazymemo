import Foundation
import Testing
@testable import LazyMemoCore

@Suite("BriefClock")
struct BriefClockTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ h: Int, _ m: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: h, minute: m))!
    }

    @Test("아침 여덟 시 전이면 오늘 여덟 시다")
    func todayWhenEarly() {
        #expect(BriefClock.next(after: date(6), calendar: calendar) == date(8))
        #expect(BriefClock.next(after: date(7, 59), calendar: calendar) == date(8))
    }

    @Test("지났으면 내일 여덟 시다")
    func tomorrowWhenPassed() {
        let tomorrow = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 1, hour: 8)
        )!
        #expect(BriefClock.next(after: date(8), calendar: calendar) == tomorrow)
        #expect(BriefClock.next(after: date(23, 30), calendar: calendar) == tomorrow)
    }
}
