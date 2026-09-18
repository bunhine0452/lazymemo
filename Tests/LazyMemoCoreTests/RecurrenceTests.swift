import Foundation
import Testing
@testable import LazyMemoCore

@Suite("Recurrence")
struct RecurrenceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("낱말을 읽고 그대로 되쓴다")
    func readsWords() {
        #expect(Recurrence("매주") == .weekly)
        #expect(Recurrence("매달") == .monthly)
        #expect(Recurrence("weekly") == .weekly)
        #expect(Recurrence("매주")?.label == "매주")
        #expect(Recurrence("weekly")?.label == "매주", "파일에 적히는 낱말은 어느 말로 읽었든 하나다")
        #expect(Recurrence.weekly.text(locale: Locale(identifier: "en_US")) == "Weekly")
        #expect(Recurrence.weekly.text(locale: Locale(identifier: "ko_KR")) == "매주")
        #expect(Recurrence("가끔") == nil)
        #expect(Recurrence("") == nil)
    }

    @Test("한 걸음씩 걸어간다")
    func steps() {
        #expect(Recurrence.daily.next(after: date(2026, 8, 31), calendar: calendar) == date(2026, 9, 1))
        #expect(Recurrence.weekly.next(after: date(2026, 8, 31), calendar: calendar) == date(2026, 9, 7))
        #expect(Recurrence.monthly.next(after: date(2026, 8, 31), calendar: calendar) == date(2026, 9, 30))
        #expect(Recurrence.yearly.next(after: date(2026, 8, 31), calendar: calendar) == date(2027, 8, 31))
    }

    @Test("매주는 요일을 지킨다 — 규칙이 요일을 들고 있지 않아도")
    func weeklyKeepsWeekday() {
        let tuesday = date(2026, 9, 1)
        #expect(calendar.component(.weekday, from: tuesday) == 3)
        let next = Recurrence.weekly.next(after: tuesday, calendar: calendar)
        #expect(calendar.component(.weekday, from: next!) == 3)
    }

    @Test("밀린 만큼 한 번에 걸어간다 — 몇 주 안 켰을 수 있다")
    func walksPastTheBacklog() {
        let anchor = date(2026, 8, 4)          // 화요일
        let now = date(2026, 8, 31, 12)        // 넷째 주가 지난 뒤
        let landed = Recurrence.weekly.walk(anchor, past: now, calendar: calendar)
        #expect(landed == date(2026, 9, 1))    // 다음 화요일 하나
    }

    @Test("아직 안 지난 것은 그대로 둔다")
    func leavesFutureAlone() {
        let future = date(2026, 12, 25)
        #expect(Recurrence.weekly.walk(future, past: date(2026, 8, 31), calendar: calendar) == nil)
    }

    @Test("달 걸음은 처음 날에서 잰다 — 1월 31일이 2월을 지나도 28일이 되지 않는다")
    func monthlyKeepsTheAnchorDay() {
        let anchor = CalendarDate(year: 2026, month: 1, day: 31)
        // 2월 28일에 서 있다(잘린 걸음). 3월 1일에 재면 3월 28일이 아니라 3월 31일이어야 한다.
        #expect(Recurrence.monthly.walk(date(2026, 2, 28, 9), past: date(2026, 3, 1), anchor: anchor, calendar: calendar)
            == date(2026, 3, 31, 9))
        // 몇 달 밀렸어도 잘린 날에서 쌓지 않는다 — 1월 31일에서 곧장 4월 30일.
        #expect(Recurrence.monthly.walk(date(2026, 1, 31, 9), past: date(2026, 4, 1), anchor: anchor, calendar: calendar)
            == date(2026, 4, 30, 9))
        // 시각은 지금 것 — 처음 날의 것이 아니다.
        #expect(Recurrence.monthly.walk(date(2026, 2, 28, 18), past: date(2026, 3, 1), anchor: anchor, calendar: calendar)
            == date(2026, 3, 31, 18))
        // 해 걸음도 같다 — 2월 29일은 윤년에 돌아온다.
        let leap = CalendarDate(year: 2028, month: 2, day: 29)
        #expect(Recurrence.yearly.walk(date(2031, 2, 28), past: date(2031, 3, 1), anchor: leap, calendar: calendar)
            == date(2032, 2, 29))
    }

    @Test("처음 날이 지금 날을 설명하는가 — 잘린 날은 설명하고, 옮긴 날은 못 한다")
    func anchorExplainsClippedDays() {
        let anchor = CalendarDate(year: 2026, month: 1, day: 31)
        #expect(Recurrence.monthly.explains(anchor, CalendarDate(year: 2026, month: 2, day: 28), calendar: calendar))
        #expect(Recurrence.monthly.explains(anchor, CalendarDate(year: 2026, month: 4, day: 30), calendar: calendar))
        #expect(!Recurrence.monthly.explains(anchor, CalendarDate(year: 2026, month: 3, day: 28), calendar: calendar))
        let leap = CalendarDate(year: 2028, month: 2, day: 29)
        #expect(Recurrence.yearly.explains(leap, CalendarDate(year: 2029, month: 2, day: 28), calendar: calendar))
        #expect(!Recurrence.yearly.explains(leap, CalendarDate(year: 2029, month: 3, day: 1), calendar: calendar))
    }

    @Test("날짜로도 걸어간다")
    func walksCalendarDates() {
        let tuesday = CalendarDate(year: 2026, month: 9, day: 1)
        #expect(Recurrence.weekly.next(after: tuesday, calendar: calendar)
            == CalendarDate(year: 2026, month: 9, day: 8))
        #expect(Recurrence.monthly.next(after: CalendarDate(year: 2026, month: 1, day: 31), calendar: calendar)
            == CalendarDate(year: 2026, month: 2, day: 28))
    }
}
