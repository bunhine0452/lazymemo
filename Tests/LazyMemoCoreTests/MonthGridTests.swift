import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MonthGrid")
struct MonthGridTests {
    @Test("칸 수는 항상 7의 배수다")
    func alwaysFullWeeks() {
        for month in 1...12 {
            let grid = MonthGrid.make(year: 2026, month: month)
            #expect(grid.days.count % 7 == 0, "\(month)월이 \(grid.days.count)칸")
        }
    }

    @Test("2026년 8월은 토요일에 시작한다")
    func placesFirstDayOnCorrectWeekday() {
        let grid = MonthGrid.make(year: 2026, month: 8)
        let firstOfMonth = grid.days.firstIndex { !$0.isOverflow }

        // 일요일 시작 격자에서 토요일은 7번째 칸(인덱스 6)
        #expect(firstOfMonth == 6)
        #expect(grid.days[6].date == CalendarDate(year: 2026, month: 8, day: 1))
    }

    @Test("앞뒤 달에서 넘어온 칸에 표시가 붙는다")
    func marksOverflowDays() {
        let grid = MonthGrid.make(year: 2026, month: 8)

        #expect(grid.days.first?.isOverflow == true)
        #expect(grid.days.first?.date == CalendarDate(year: 2026, month: 7, day: 26))
        #expect(grid.days.filter { !$0.isOverflow }.count == 31)
    }

    @Test("주 시작을 월요일로 바꾸면 배치가 따라간다")
    func respectsFirstWeekday() {
        let grid = MonthGrid.make(year: 2026, month: 8, firstWeekday: 2)
        // 월요일 시작 격자에서 토요일은 6번째 칸(인덱스 5)
        #expect(grid.days.firstIndex { !$0.isOverflow } == 5)
    }

    @Test("윤년 2월은 29일까지다")
    func handlesLeapFebruary() {
        let leap = MonthGrid.make(year: 2028, month: 2)
        let normal = MonthGrid.make(year: 2026, month: 2)

        #expect(leap.days.filter { !$0.isOverflow }.count == 29)
        #expect(normal.days.filter { !$0.isOverflow }.count == 28)
    }

    @Test("범위가 앞뒤 달 넘침까지 덮는다 — 그 칸의 일정도 보여야 한다")
    func rangeCoversOverflowDays() {
        let grid = MonthGrid.make(year: 2026, month: 8)
        let range = grid.range

        #expect(range?.lowerBound == CalendarDate(year: 2026, month: 7, day: 26))
        #expect(range?.upperBound.month == 9)
    }

    @Test("12월 다음은 다음 해 1월이다")
    func advancesAcrossYearBoundary() {
        let december = MonthGrid.make(year: 2026, month: 12)
        #expect(december.advanced(by: 1).year == 2027)
        #expect(december.advanced(by: 1).month == 1)

        let january = MonthGrid.make(year: 2026, month: 1)
        #expect(january.advanced(by: -1).year == 2025)
        #expect(january.advanced(by: -1).month == 12)
    }

    @Test("여러 달을 건너뛰어도 맞는다")
    func advancesByManyMonths() {
        let grid = MonthGrid.make(year: 2026, month: 8)
        let ko = Locale(identifier: "ko_KR")
        #expect(grid.advanced(by: 17).title(locale: ko) == "2028년 1월")
        #expect(grid.advanced(by: -20).title(locale: ko) == "2024년 12월")
    }

    @Test("머리글은 그 말의 어순으로 — 「2026년 9월」은 영어에서 「September 2026」")
    func titleFollowsLocale() {
        let grid = MonthGrid.make(year: 2026, month: 9)
        #expect(grid.title(locale: Locale(identifier: "en_US")) == "September 2026")
        #expect(grid.title(locale: Locale(identifier: "ko_KR")) == "2026년 9월")
    }
}
