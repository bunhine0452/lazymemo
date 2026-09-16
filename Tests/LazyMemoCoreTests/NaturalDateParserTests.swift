import Foundation
import Testing
@testable import LazyMemoCore

@Suite("NaturalDateParser")
struct NaturalDateParserTests {
    /// 2026년 8월 28일 금요일 오전 10시를 "지금"으로 고정한다.
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 28, hour: 10)
        )!
    }

    private func parse(_ text: String) -> NaturalDateParser.Result? {
        NaturalDateParser.parse(text, now: now)
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

    // MARK: 지금

    @Test("「지금」·「당장」은 날이 아니라 이 순간이다 — 시각까지 붙는다")
    func readsNowAsThisMoment() throws {
        let nowish = try #require(parse("지금 치과 전화"))
        #expect(nowish.at == now)
        #expect(nowish.phrases == ["지금"])
        #expect(NaturalDateParser.strip(nowish.phrases, from: "지금 치과 전화") == "치과 전화")
        #expect(parse("당장 우유 사기")?.at == now)
        #expect(parse("지금 당장 전화")?.phrases == ["지금 당장"])
        #expect(parse("call mom right now")?.at == now)
        #expect(parse("send the file asap")?.at == now)
    }

    @Test("「지금 3시」는 오늘 그 시각이다 — 낱말은 오늘을 뜻할 뿐")
    func nowWithClockMeansTodayAtThatClock() throws {
        let three = try #require(parse("지금 3시 회의")?.at)
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: three)
        #expect(parts.day == 28 && parts.hour == 15 && parts.minute == 0)
        #expect(parse("지금 3시 회의")?.phrases.contains("지금") == true)
    }

    @Test("「지금부터 2시간 뒤」는 낱말째 덜어낸다")
    func stripsNowFromRelativeOffsets() throws {
        let later = try #require(parse("지금부터 2시간 뒤 알람"))
        #expect(later.at == now.addingTimeInterval(2 * 3600))
        #expect(NaturalDateParser.strip(later.phrases, from: "지금부터 2시간 뒤 알람") == "알람")
        #expect(NaturalDateParser.strip(parse("지금 30분 뒤 확인")!.phrases, from: "지금 30분 뒤 확인") == "확인")
    }

    @Test("붙어 쓴 「지금은」·「식당장」은 지금이 아니다")
    func nowNeedsToStandAlone() {
        #expect(parse("지금은 바쁨") == nil)
        #expect(parse("식당장 부르기") == nil)
        #expect(parse("I know nowhere") == nil)
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
        #expect(NaturalDateParser.strip(result.phrases, from: "내일 오후 3시 치과 예약") == "치과 예약")
    }

    @Test("떨어져 있는 조각도 각각 덜어낸다")
    func stripsSeparatedPhrases() throws {
        let text = "내일 치과 오후 3시"
        let result = try #require(parse(text))
        #expect(NaturalDateParser.strip(result.phrases, from: text) == "치과")
    }

    @Test("덜어내서 빈 문자열이 되면 원문을 지킨다")
    func keepsTextWhenStrippingEmptiesIt() throws {
        let result = try #require(parse("내일"))
        #expect(NaturalDateParser.strip(result.phrases, from: "내일") == "내일")
    }

    // MARK: 달 없는 날 — 「22일」

    @Test("달을 안 적은 날은 앞으로 가장 가까운 그 날 — 오늘 포함")
    func bareDayOfMonth() {
        // 지금은 8월 28일.
        #expect(parse("22일 오후 3시 밥약속")?.at.map { CalendarDate($0) } == CalendarDate(year: 2026, month: 9, day: 22))
        #expect(parse("22일 오후 3시 밥약속")?.phrases.contains("22일") == true)
        #expect(parse("28일 회의")?.due == CalendarDate(year: 2026, month: 8, day: 28))
        #expect(parse("31일 월세")?.due == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(parse("3일에 병원")?.due == CalendarDate(year: 2026, month: 9, day: 3))
        #expect(parse("22일")?.due == CalendarDate(year: 2026, month: 9, day: 22))
    }

    @Test("그 달에 없는 날은 그다음 달로 — 9월에 적은 「31일」은 10월 31일")
    func bareDaySkipsShortMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 10))!
        #expect(NaturalDateParser.parse("31일 정산", now: september)?.due == CalendarDate(year: 2026, month: 10, day: 31))
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 30, hour: 10))!
        #expect(NaturalDateParser.parse("3일 여행", now: december)?.due == CalendarDate(year: 2027, month: 1, day: 3))
    }

    @Test("세는 말·빈도·요일의 「일」은 날이 아니다")
    func bareDayNotCounting() {
        #expect(parse("3일 동안 여행")?.due == nil)
        #expect(parse("3일째 단식") == nil)
        #expect(parse("1일 2회 복용") == nil)
        #expect(parse("일요일 등산")?.due != CalendarDate(year: 2026, month: 9, day: 1))
        // 세는 표현이 먼저다.
        #expect(parse("3일 뒤 결과 확인")?.due == CalendarDate(year: 2026, month: 8, day: 31))
        // 못 박힌 날짜가 먼저다.
        #expect(parse("9월 3일 점심")?.at.map { CalendarDate($0) } == CalendarDate(year: 2026, month: 9, day: 3))
    }

    @Test("「매달 22일」— 되풀이와 달 없는 날이 함께")
    func bareDayWithRecurrence() {
        let result = parse("매달 22일 월세")
        #expect(result?.every == .monthly)
        #expect(result?.due == CalendarDate(year: 2026, month: 9, day: 22))
    }
}
