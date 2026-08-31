import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 하루가 바뀌는 것을 앱이 알아채는가 (`DayClock`).
///
/// v1 에는 이 부품이 없었고 — `Sources` 전체에 타이머가 0개였다 — 그래서
/// 상주 앱이면서 시간에 따라 스스로 하는 일이 하나도 없었다. 자정이 지나도
/// 달력의 오늘은 켠 날에 멈춰 있었다.
///
/// 깨우는 길이 둘이라(시스템 알림 + 우리가 잰 잠) **두 번 깨는 일이 정상**
/// 이므로, 여러 번 불려도 한 번만 일하는 것이 이 부품의 계약이다.
@MainActor
@Suite("하루 시계")
struct DayClockTests {
    private func seoul() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ calendar: Calendar, month: Int = 8, day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test("날짜가 그대로면 아무 일도 안 한다 — 두 길이 같은 자정에 함께 와도 된다")
    func staysQuietWithinTheSameDay() {
        let calendar = seoul()
        var now = date(calendar, day: 29, hour: 10)
        var days: [CalendarDate] = []

        let clock = DayClock(now: { now }, calendar: calendar)
        clock.onNewDay = { days.append($0) }

        now = date(calendar, day: 29, hour: 23)
        clock.tick()
        clock.tick()

        #expect(days.isEmpty)
    }

    @Test("자정을 넘기면 한 번 알린다 — 두 번 불려도 한 번")
    func announcesOncePerDay() {
        let calendar = seoul()
        var now = date(calendar, day: 29, hour: 23)
        var days: [CalendarDate] = []

        let clock = DayClock(now: { now }, calendar: calendar)
        clock.onNewDay = { days.append($0) }

        now = date(calendar, day: 30, hour: 0)
        clock.tick()
        clock.tick()

        #expect(days == [CalendarDate(year: 2026, month: 8, day: 30)])
        #expect(clock.today == CalendarDate(year: 2026, month: 8, day: 30))
    }

    @Test("자리를 비운 사이 여러 날이 지나도 지금 날짜로 한 번 알린다")
    func catchesUpAfterSleep() {
        let calendar = seoul()
        var now = date(calendar, day: 29, hour: 23)
        var days: [CalendarDate] = []

        let clock = DayClock(now: { now }, calendar: calendar)
        clock.onNewDay = { days.append($0) }

        // 뚜껑을 닫아 둔 나흘. 밀린 자정마다 한 번씩 알리는 것이 아니라
        // **지금이 며칠인지**를 한 번 알린다 — 받는 쪽은 전부 "지금 오늘이
        // 며칠인가" 만 쓰므로 중간 날짜는 아무 뜻이 없다.
        now = date(calendar, month: 9, day: 2, hour: 9)
        clock.tick()

        #expect(days == [CalendarDate(year: 2026, month: 9, day: 2)])
    }

    @Test("만들 때의 오늘을 그대로 든다 — 첫 tick 이 헛되이 울리지 않게")
    func startsFromTheInjectedDay() {
        let calendar = seoul()
        let now = date(calendar, day: 29, hour: 23)
        var days: [CalendarDate] = []

        let clock = DayClock(now: { now }, calendar: calendar)
        clock.onNewDay = { days.append($0) }

        #expect(clock.today == CalendarDate(year: 2026, month: 8, day: 29))
        clock.tick()
        #expect(days.isEmpty)
    }
}
