import Foundation
import Testing
@testable import LazyMemoCore

/// 옮기기·미루기는 **화면에서 검증할 수 없는 규칙**이다. 하루 밀린 것과 맞는
/// 것이 달력에서 똑같이 그럴듯해 보이고, 시각이 사라진 것은 다음 날에야 안다.
@Suite("Schedule")
struct ScheduleTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    @Test("약속을 옮기면 시:분은 그대로 따라간다")
    func keepsTimeOfDay() {
        let schedule = Schedule(at: date(2026, 8, 28, 14, 30))
        let moved = schedule.moved(to: CalendarDate(year: 2026, month: 9, day: 1), calendar: calendar)

        #expect(moved.day(calendar: calendar) == CalendarDate(year: 2026, month: 9, day: 1))
        let parts = calendar.dateComponents([.hour, .minute], from: moved.at!)
        #expect(parts.hour == 14)
        #expect(parts.minute == 30)
        #expect(moved.due == nil)
    }

    @Test("시각 없는 마감을 옮겨도 시각이 생기지 않는다")
    func doesNotInventTime() {
        let schedule = Schedule(due: CalendarDate(year: 2026, month: 8, day: 25))
        let moved = schedule.moved(to: CalendarDate(year: 2026, month: 8, day: 30), calendar: calendar)

        #expect(moved.due == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(moved.at == nil)
    }

    @Test("두 칸이 다 차 있으면 둘 다 같은 날로 간다")
    func movesBothFields() {
        let schedule = Schedule(
            due: CalendarDate(year: 2026, month: 8, day: 28),
            at: date(2026, 8, 28, 9, 0)
        )
        let moved = schedule.moved(to: CalendarDate(year: 2026, month: 8, day: 31), calendar: calendar)

        #expect(moved.due == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(CalendarDate(moved.at!, calendar: calendar) == CalendarDate(year: 2026, month: 8, day: 31))
    }

    @Test("날짜가 없던 메모를 달력에 놓으면 그 날의 마감이 된다")
    func placesUndatedMemo() {
        let moved = Schedule().moved(to: CalendarDate(year: 2026, month: 9, day: 3), calendar: calendar)

        #expect(moved.due == CalendarDate(year: 2026, month: 9, day: 3))
        #expect(moved.at == nil)
    }

    @Test("앞으로의 일정을 미루면 그 다음 날이다")
    func postponesFutureByOneDay() {
        let today = CalendarDate(year: 2026, month: 8, day: 28)
        let schedule = Schedule(due: CalendarDate(year: 2026, month: 9, day: 10))

        let postponed = schedule.postponed(notBefore: today, calendar: calendar)
        #expect(postponed.due == CalendarDate(year: 2026, month: 9, day: 11))
    }

    @Test("이미 지나 버린 일정을 미루면 과거가 아니라 내일로 간다")
    func neverPostponesIntoThePast() {
        let today = CalendarDate(year: 2026, month: 8, day: 28)
        let schedule = Schedule(at: date(2026, 8, 20, 11, 0))

        let postponed = schedule.postponed(notBefore: today, calendar: calendar)

        #expect(postponed.day(calendar: calendar) == CalendarDate(year: 2026, month: 8, day: 29))
        // 미루는 것은 날짜지 시각이 아니다.
        #expect(calendar.dateComponents([.hour], from: postponed.at!).hour == 11)
    }

    @Test("오늘 것을 미루면 내일이다")
    func postponesTodayToTomorrow() {
        let today = CalendarDate(year: 2026, month: 8, day: 31)
        let postponed = Schedule(due: today).postponed(notBefore: today, calendar: calendar)

        // 달을 넘기는 계산도 함께 확인한다.
        #expect(postponed.due == CalendarDate(year: 2026, month: 9, day: 1))
    }
}

@Suite("QuickSchedule")
struct QuickScheduleTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let day = CalendarDate(year: 2026, month: 8, day: 30)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
    }

    @Test("날짜를 안 적으면 고른 날의 마감이 된다")
    func fallsBackToSelectedDay() {
        let draft = QuickSchedule.make(from: "분리수거", on: day, now: now, calendar: calendar)

        #expect(draft.schedule.due == day)
        #expect(draft.schedule.at == nil)
        #expect(draft.body == "분리수거")
    }

    @Test("시각만 적으면 고른 날의 그 시각이 된다")
    func graftsTimeOntoSelectedDay() {
        let draft = QuickSchedule.make(from: "오후 3시 치과", on: day, now: now, calendar: calendar)

        #expect(draft.schedule.day(calendar: calendar) == day)
        let parts = calendar.dateComponents([.hour, .minute], from: draft.schedule.at!)
        #expect(parts.hour == 15)
        #expect(parts.minute == 0)
        // 인식한 말은 칩이 대신하므로 본문에서 덜어낸다.
        #expect(draft.body == "치과")
    }

    @Test("날짜를 직접 적으면 고른 날보다 그쪽이 이긴다")
    func explicitDateWins() {
        let draft = QuickSchedule.make(from: "내일 은행", on: day, now: now, calendar: calendar)

        #expect(draft.schedule.due == CalendarDate(year: 2026, month: 8, day: 29))
        #expect(draft.body == "은행")
    }

    @Test("빈 줄은 아무것도 만들지 않는다")
    func ignoresEmptyText() {
        let draft = QuickSchedule.make(from: "   ", on: day, now: now, calendar: calendar)
        #expect(draft.body.isEmpty)
    }
}
