import Foundation
import Testing
@testable import LazyMemoCore

/// 다음 자정을 언제로 잡는가 (`DayClock` 이 이 값으로 잔다).
///
/// **더하기 24시간이 아니다.** 서머타임이 있는 지역에서는 하루가 23시간이거나
/// 25시간이라, 24시간을 더하면 자정을 놓치거나 한 시간 일찍 깬다. 그리고
/// 이것은 화면에 나타나지 않는 종류의 오차다 — 하루에 한 번, 그것도 1년에
/// 두 번만 틀리므로 눈으로는 영영 못 잡는다.
@Suite("다음 자정")
struct NextMidnightTests {
    private func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func date(
        _ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        )))
    }

    @Test("한낮에 물으면 그 날이 끝나는 자정을 준다")
    func returnsTonightsMidnight() throws {
        let seoul = calendar("Asia/Seoul")
        let noon = try date(seoul, 2026, 8, 29, 12)

        let midnight = try #require(CalendarDate.nextMidnight(after: noon, calendar: seoul))

        #expect(CalendarDate(midnight, calendar: seoul) == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(seoul.component(.hour, from: midnight) == 0)
    }

    @Test("자정 정각에 물어도 다음 자정이다 — 제자리에서 깨는 고리를 만들지 않는다")
    func doesNotReturnNow() throws {
        let seoul = calendar("Asia/Seoul")
        let midnight = try date(seoul, 2026, 8, 29)

        let next = try #require(CalendarDate.nextMidnight(after: midnight, calendar: seoul))

        #expect(next > midnight)
        #expect(next.timeIntervalSince(midnight) == 24 * 60 * 60)
    }

    @Test("달을 넘긴다")
    func crossesMonth() throws {
        let seoul = calendar("Asia/Seoul")
        let lastDay = try date(seoul, 2026, 8, 31, 23)

        let next = try #require(CalendarDate.nextMidnight(after: lastDay, calendar: seoul))

        #expect(CalendarDate(next, calendar: seoul) == CalendarDate(year: 2026, month: 9, day: 1))
    }

    @Test("서머타임으로 짧아진 하루는 23시간이다 — 24를 더하면 자정을 지나친다")
    func handlesShortDay() throws {
        // 미국 동부는 3월 둘째 일요일 새벽 2시에 한 시간을 건너뛴다.
        let newYork = calendar("America/New_York")
        let springForward = try date(newYork, 2026, 3, 8)

        let next = try #require(CalendarDate.nextMidnight(after: springForward, calendar: newYork))

        #expect(next.timeIntervalSince(springForward) == 23 * 60 * 60)
        #expect(CalendarDate(next, calendar: newYork) == CalendarDate(year: 2026, month: 3, day: 9))
    }

    @Test("서머타임으로 길어진 하루는 25시간이다 — 24를 더하면 한 시간 일찍 깬다")
    func handlesLongDay() throws {
        // 11월 첫째 일요일 새벽 2시에 한 시간을 되돌린다.
        let newYork = calendar("America/New_York")
        let fallBack = try date(newYork, 2026, 11, 1)

        let next = try #require(CalendarDate.nextMidnight(after: fallBack, calendar: newYork))

        #expect(next.timeIntervalSince(fallBack) == 25 * 60 * 60)
        #expect(CalendarDate(next, calendar: newYork) == CalendarDate(year: 2026, month: 11, day: 2))
    }
}
