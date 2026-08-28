import Foundation
import Testing
@testable import LazyMemoCore

@Suite("KoreanDateParser")
struct KoreanDateParserTests {
    /// 2026년 8월 28일 금요일 오전 10시를 "지금"으로 고정한다.
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 28, hour: 10)
        )!
    }

    private func parse(_ text: String) -> KoreanDateParser.Result? {
        KoreanDateParser.parse(text, now: now)
    }

    // MARK: 날짜만

    @Test("내일·모레·글피를 읽는다")
    func readsRelativeDays() {
        #expect(parse("내일 장보기")?.due == CalendarDate(year: 2026, month: 8, day: 29))
        #expect(parse("모레 회의")?.due == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(parse("글피까지 제출")?.due == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(parse("오늘 안에 끝내기")?.due == CalendarDate(year: 2026, month: 8, day: 28))
    }

    @Test("N월 N일을 읽는다")
    func readsExplicitDate() {
        #expect(parse("9월 1일 치과")?.due == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(parse("12월 25일 약속")?.due == CalendarDate(year: 2026, month: 12, day: 25))
    }

    @Test("요일은 앞으로 가장 가까운 날로 읽는다")
    func readsUpcomingWeekday() {
        // 2026-08-28 은 금요일. 다음 화요일은 9월 1일.
        #expect(parse("화요일 회의")?.due == CalendarDate(year: 2026, month: 9, day: 1))
        // 오늘이 금요일이므로 "금요일"은 오늘.
        #expect(parse("금요일 마감")?.due == CalendarDate(year: 2026, month: 8, day: 28))
    }

    @Test("다음 주 요일은 한 주 더 간다")
    func readsNextWeekWeekday() {
        #expect(parse("다음 주 화요일 치과")?.due == CalendarDate(year: 2026, month: 9, day: 8))
        #expect(parse("담주 월요일 보고")?.due == CalendarDate(year: 2026, month: 9, day: 7))
    }

    @Test("N일 뒤를 읽는다")
    func readsDayCount() {
        #expect(parse("3일 뒤 결과 확인")?.due == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(parse("10일 후 재방문")?.due == CalendarDate(year: 2026, month: 9, day: 7))
    }

    // MARK: 시각까지

    @Test("시각이 있으면 due 가 아니라 at 이 된다")
    func timeProducesAppointment() throws {
        let result = try #require(parse("내일 오후 3시 치과"))
        #expect(result.due == nil)

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: try #require(result.at))
        #expect(parts.month == 8 && parts.day == 29)
        #expect(parts.hour == 15 && parts.minute == 0)
    }

    @Test("오전과 오후를 구분한다")
    func distinguishesMeridiem() throws {
        let morning = try #require(parse("내일 오전 9시 회의")?.at)
        #expect(Calendar.current.component(.hour, from: morning) == 9)

        let evening = try #require(parse("내일 오후 9시 산책")?.at)
        #expect(Calendar.current.component(.hour, from: evening) == 21)
    }

    @Test("표기가 없는 이른 숫자는 오후로 읽는다 — 한국어 관행")
    func bareAfternoonHours() throws {
        let three = try #require(parse("내일 3시 미팅")?.at)
        #expect(Calendar.current.component(.hour, from: three) == 15)

        let nine = try #require(parse("내일 9시 출근")?.at)
        #expect(Calendar.current.component(.hour, from: nine) == 9)
    }

    @Test("분과 '반'을 읽는다")
    func readsMinutes() throws {
        let half = try #require(parse("내일 2시 반 통화")?.at)
        #expect(Calendar.current.component(.minute, from: half) == 30)

        let exact = try #require(parse("내일 오후 2시 40분 통화")?.at)
        #expect(Calendar.current.component(.minute, from: exact) == 40)
    }

    // MARK: 안 읽는 것

    @Test("날짜가 없으면 아무것도 만들지 않는다")
    func returnsNilWithoutDate() {
        #expect(parse("우유 사기") == nil)
        #expect(parse("") == nil)
        // 시각만 있고 날짜가 없으면 어느 날인지 알 수 없다.
        #expect(parse("3시에 전화") == nil)
    }

    @Test("애매한 빗금 표기는 날짜로 보지 않는다")
    func ignoresSlashNotation() {
        #expect(parse("우유 3/4 컵") == nil)
    }

    // MARK: 본문 정리

    @Test("인식한 조각을 본문에서 덜어낸다")
    func stripsRecognizedPhrases() throws {
        let result = try #require(parse("내일 오후 3시 치과 예약"))
        #expect(KoreanDateParser.strip(result.phrases, from: "내일 오후 3시 치과 예약") == "치과 예약")
    }

    @Test("떨어져 있는 조각도 각각 덜어낸다")
    func stripsSeparatedPhrases() throws {
        let text = "내일 치과 오후 3시"
        let result = try #require(parse(text))
        #expect(KoreanDateParser.strip(result.phrases, from: text) == "치과")
    }

    @Test("덜어내서 빈 문자열이 되면 원문을 지킨다")
    func keepsTextWhenStrippingEmptiesIt() throws {
        let result = try #require(parse("내일"))
        #expect(KoreanDateParser.strip(result.phrases, from: "내일") == "내일")
    }
}
