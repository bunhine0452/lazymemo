import Foundation
import Testing
@testable import LazyMemoCore

/// 날짜 낱말 없이 시각만 적은 글.
///
/// "새벽 2시 기상" 을 그냥 넘기고 있었다 — 사람이 그렇게 적었으면 그건
/// 명백히 일정인데, 앱이 못 읽으면 달력에도 없고 아무 때에도 떠오르지 않는다.
/// 그러면서 맨 "3시" 는 여전히 넘겨야 한다. 갈림길은 "어느 날인가" 가 아니라
/// **오전인가 오후인가** 다.
@Suite("날짜 없는 시각")
struct DaylessTimeTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// 2026-08-28 (금) 10:00. 아침은 이미 지났고 저녁은 아직 오지 않았다.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
    }

    private func parse(_ text: String) -> NaturalDateParser.Result? {
        NaturalDateParser.parse(text, now: now, calendar: calendar)
    }

    private func moment(_ text: String) throws -> DateComponents {
        let at = try #require(parse(text)?.at, "\(text) 에서 시각을 못 읽었다")
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at)
    }

    @Test("때를 말로 밝히면 날짜가 없어도 읽는다")
    func readsNamedDayParts() throws {
        #expect(try moment("새벽 2시 기상").hour == 2)
        #expect(try moment("저녁 7시 약속").hour == 19)
        #expect(try moment("아침 회의").hour == 8)
        #expect(try moment("밤 11시 마감").hour == 23)
    }

    @Test("아직 오지 않은 시각은 오늘이다")
    func staysTodayWhenAhead() throws {
        let evening = try moment("저녁 7시 약속")
        #expect(evening.day == 28)
        #expect(evening.hour == 19)
    }

    @Test("이미 지난 시각은 내일이다 — 오늘 아침 8시는 다시 오지 않는다")
    func rollsToTomorrowWhenPast() throws {
        let morning = try moment("아침 회의")
        #expect(morning.day == 29)
        #expect(morning.hour == 8)

        // 새벽 2시는 오늘 것이 이미 지났으므로 내일 새벽이다.
        let dawn = try moment("새벽 2시 기상")
        #expect(dawn.day == 29)
    }

    @Test("영어·일본어·중국어도 같은 규칙을 탄다")
    func readsOtherLanguages() throws {
        #expect(try moment("meeting at 3pm").hour == 15)
        #expect(try moment("夕方に散歩").hour == 19)
        #expect(try moment("晚上7点吃饭").hour == 19)
    }

    @Test("24시간제로 적은 시각도 그 자체로 오후를 말한다")
    func readsTwentyFourHourClock() throws {
        #expect(try moment("15:30 회의").hour == 15)
        #expect(try moment("18시 퇴근").hour == 18)
    }

    @Test("때를 안 밝힌 맨 시각은 여전히 넘긴다 — 짐작 위에 짐작을 얹지 않는다")
    func staysSilentOnAmbiguousHour() {
        #expect(parse("3시에 전화") == nil)
        #expect(parse("7시 미팅") == nil)
        #expect(parse("우유 사기") == nil)
    }

    @Test("이렇게 읽은 날은 사용자가 말한 날이 아니다")
    func doesNotClaimToNameTheDay() throws {
        let named = try #require(parse("내일 새벽 2시"))
        #expect(named.namesDay)

        let inferred = try #require(parse("새벽 2시"))
        #expect(!inferred.namesDay)
    }

    @Test("달력에서 날을 골라 놓았으면 고른 날이 이긴다")
    func selectedDayWinsOverInference() {
        let day = CalendarDate(year: 2026, month: 9, day: 3)
        let draft = QuickSchedule.make(from: "새벽 2시 기상", on: day, now: now, calendar: calendar)

        #expect(draft.schedule.day(calendar: calendar) == day)
        #expect(calendar.dateComponents([.hour], from: draft.schedule.at!).hour == 2)
        #expect(draft.body == "기상")
    }
}
