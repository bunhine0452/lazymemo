import Foundation
import Testing
@testable import LazyMemoCore

/// 날짜를 손으로 이어 붙이지 않는다 — 「9월 14일」을 영어로 옮기면 어순이 뒤집힌다.
@Suite("DateWords — 날짜는 그 말의 어순으로")
struct DateWordsTests {
    private let ko = Locale(identifier: "ko_KR")
    private let en = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
    private let day = CalendarDate(year: 2026, month: 9, day: 14)  // 월요일

    @Test("달·날")
    func monthDay() {
        #expect(DateWords.monthDay(day, calendar: calendar, locale: ko) == "9월 14일")
        #expect(DateWords.monthDay(day, calendar: calendar, locale: en) == "Sep 14")
    }

    @Test("달·날·요일 — 칩과 머리글의 긴 자리")
    func monthDayWeekday() {
        #expect(DateWords.monthDayWeekday(day, calendar: calendar, locale: ko) == "9월 14일 (월)")
        #expect(DateWords.monthDayWeekday(day, calendar: calendar, locale: en) == "Mon, Sep 14")
    }

    @Test("해·달 — 달력 머리글")
    func yearMonth() {
        #expect(DateWords.yearMonth(year: 2026, month: 9, calendar: calendar, locale: ko) == "2026년 9월")
        #expect(DateWords.yearMonth(year: 2026, month: 9, calendar: calendar, locale: en) == "September 2026")
        #expect(DateWords.month(9, calendar: calendar, locale: ko) == "9월")
        #expect(DateWords.month(9, calendar: calendar, locale: en) == "September")
    }

    @Test("요일 머리글은 일요일부터 한 글자씩")
    func weekdayLetters() {
        #expect(DateWords.weekdayLetters(calendar: calendar, locale: ko) == ["일", "월", "화", "수", "목", "금", "토"])
        #expect(DateWords.weekdayLetters(calendar: calendar, locale: en) == ["S", "M", "T", "W", "T", "F", "S"])
    }

    @Test("표에 없는 말은 원문 그대로 — 한국어 사용자는 아무것도 잃지 않는다")
    func koreanKeysStayKorean() {
        #expect(L("오늘", locale: ko) == "오늘")
        #expect(L("오늘", locale: en) == "Today")
        #expect(L("표에 없는 말", locale: en) == "표에 없는 말")
    }
}
