import Foundation
import Testing
@testable import LazyMemoCore

/// 한국어 말고도 읽는가, 그리고 "새벽·아침·저녁" 처럼 숫자 없는 때를 읽는가.
@Suite("NaturalDateParser — 여러 나라 말과 하루 중 때")
struct NaturalDateParserLanguagesTests {
    /// 2026년 8월 28일 금요일 오전 10시를 "지금"으로 고정한다.
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
    }

    private func parse(_ text: String) -> NaturalDateParser.Result? {
        NaturalDateParser.parse(text, now: now)
    }

    /// 인식한 순간의 (월, 일, 시, 분).
    private func moment(_ text: String) throws -> (month: Int, day: Int, hour: Int, minute: Int) {
        let at = try #require(parse(text)?.at, "\(text) 에서 시각을 못 읽었다")
        let parts = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: at)
        return (parts.month!, parts.day!, parts.hour!, parts.minute!)
    }

    private func due(_ text: String) throws -> CalendarDate {
        try #require(parse(text)?.due, "\(text) 에서 날짜를 못 읽었다")
    }

    // MARK: 하루 중 때 — 숫자 없이

    @Test("새벽·아침·낮·저녁·밤·자정을 대표 시각으로 읽는다")
    func readsDayParts() throws {
        #expect(try moment("내일 새벽 산책").hour == 5)
        #expect(try moment("내일 아침 회의").hour == 8)
        #expect(try moment("내일 오전 접수").hour == 9)
        #expect(try moment("내일 점심 약속").hour == 12)
        #expect(try moment("내일 낮에 전화").hour == 12)
        #expect(try moment("내일 오후 미팅").hour == 14)
        #expect(try moment("내일 저녁 산책").hour == 19)
        #expect(try moment("내일 밤 마감").hour == 21)
        #expect(try moment("내일 자정 배포").hour == 0)
    }

    @Test("때가 숫자를 오전·오후로 갈라준다")
    func dayPartDressesTheHour() throws {
        #expect(try moment("내일 새벽 2시 기상").hour == 2)
        #expect(try moment("내일 아침 8시 출발").hour == 8)
        #expect(try moment("내일 점심 1시 약속").hour == 13)
        #expect(try moment("내일 저녁 7시 저녁밥").hour == 19)
        #expect(try moment("내일 밤 11시 마감").hour == 23)
        #expect(try moment("내일 밤 12시 배포").hour == 0)
    }

    @Test("때는 시각에 붙어 있을 때만 시각을 꾸민다")
    func dayPartMustTouchTheHour() throws {
        // "아침" 은 우유를 꾸미는 말이지 3시를 꾸미는 말이 아니다.
        #expect(try moment("내일 아침에 산 우유 3시에 마시기").hour == 15)
    }

    // MARK: 영어

    @Test("영어 날짜를 읽는다")
    func readsEnglishDates() throws {
        #expect(try due("dentist tomorrow") == CalendarDate(year: 2026, month: 8, day: 29))
        #expect(try due("yesterday's note") == CalendarDate(year: 2026, month: 8, day: 27))
        #expect(try due("friday deadline") == CalendarDate(year: 2026, month: 8, day: 28))
        #expect(try due("next tuesday dentist") == CalendarDate(year: 2026, month: 9, day: 8))
        #expect(try due("in 3 days") == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(try due("Sep 1 dentist") == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(try due("1st of September") == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(try due("this weekend cleaning") == CalendarDate(year: 2026, month: 8, day: 29))
    }

    @Test("영어 시각을 읽는다")
    func readsEnglishTimes() throws {
        let pm = try moment("meeting tomorrow at 3pm")
        #expect(pm.day == 29 && pm.hour == 15 && pm.minute == 0)

        let am = try moment("call today at 9:30 a.m.")
        #expect(am.hour == 9 && am.minute == 30)

        #expect(try moment("tomorrow morning").hour == 8)
        #expect(try moment("tonight").hour == 21)
        #expect(try moment("tomorrow afternoon").hour == 14)
        #expect(try moment("dinner tomorrow at 7").hour == 19)
    }

    // MARK: 일본어

    @Test("일본어 날짜를 읽는다")
    func readsJapaneseDates() throws {
        #expect(try due("明日 歯医者") == CalendarDate(year: 2026, month: 8, day: 29))
        #expect(try due("明後日 会議") == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(try due("昨日のメモ") == CalendarDate(year: 2026, month: 8, day: 27))
        #expect(try due("来週火曜日 打ち合わせ") == CalendarDate(year: 2026, month: 9, day: 8))
        #expect(try due("9月1日 歯医者") == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(try due("3日後 再訪") == CalendarDate(year: 2026, month: 8, day: 31))
    }

    @Test("일본어 시각을 읽는다")
    func readsJapaneseTimes() throws {
        let afternoon = try moment("明日の午後3時 歯医者")
        #expect(afternoon.day == 29 && afternoon.hour == 15)

        #expect(try moment("明日の朝 出発").hour == 8)
        #expect(try moment("明日の夕方 散歩").hour == 19)
        #expect(try moment("今夜 締め切り").hour == 21)
        #expect(try moment("明日 9時半 電話").minute == 30)
    }

    // MARK: 중국어

    @Test("중국어 날짜를 읽는다")
    func readsChineseDates() throws {
        #expect(try due("明天 看牙") == CalendarDate(year: 2026, month: 8, day: 29))
        #expect(try due("后天 开会") == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(try due("昨天的笔记") == CalendarDate(year: 2026, month: 8, day: 27))
        #expect(try due("下周二 复诊") == CalendarDate(year: 2026, month: 9, day: 8))
        #expect(try due("9月1号 看牙") == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(try due("3天后 复查") == CalendarDate(year: 2026, month: 8, day: 31))
    }

    @Test("중국어 시각을 읽는다")
    func readsChineseTimes() throws {
        let afternoon = try moment("明天下午3点 看牙")
        #expect(afternoon.day == 29 && afternoon.hour == 15)

        #expect(try moment("明天早上 出发").hour == 8)
        #expect(try moment("今晚8点 开会").hour == 20)
        #expect(try moment("明天晚上 散步").hour == 19)
        #expect(try moment("明天中午 吃饭").hour == 12)
    }

    // MARK: 지금으로부터

    @Test("지금으로부터 몇 시간·몇 분 뒤를 읽는다")
    func readsOffsetsFromNow() throws {
        let hours = try moment("3시간 뒤 알람")
        #expect(hours.day == 28 && hours.hour == 13)

        #expect(try moment("20분 뒤 확인").minute == 20)
        #expect(try moment("in 30 minutes").minute == 30)
        #expect(try moment("30分後 確認").minute == 30)
        #expect(try moment("in 2 hours").hour == 12)
    }

    // MARK: 주·달

    @Test("주와 달을 통째로 읽는다")
    func readsWholeWeekAndMonth() throws {
        #expect(try due("다음 주 정산") == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(try due("다음 달 여행") == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(try due("이번 주 안에 정리") == CalendarDate(year: 2026, month: 8, day: 28))
        #expect(try due("다음 주말 대청소") == CalendarDate(year: 2026, month: 9, day: 5))
        #expect(try due("2주 뒤 재방문") == CalendarDate(year: 2026, month: 9, day: 11))
        #expect(try due("이틀 뒤 결과") == CalendarDate(year: 2026, month: 8, day: 30))
    }

    // MARK: 안 읽는 것

    @Test("낱말 속에 우연히 든 글자는 날짜가 아니다")
    func ignoresLookalikes() {
        #expect(parse("money 정산") == nil)          // monday 가 아니다
        #expect(parse("satisfying work") == nil)     // saturday 도 sat 도 아니다
        #expect(parse("우유 사기") == nil)
    }

    @Test("맨 숫자는 시각이 아니다")
    func bareNumbersAreNotTimes() throws {
        // "3 amazing" 의 am 은 오전이 아니고, "3 boxes" 의 3 은 세 시가 아니다.
        let boxes = try #require(parse("tomorrow 3 boxes"))
        #expect(boxes.at == nil)
        #expect(boxes.due == CalendarDate(year: 2026, month: 8, day: 29))

        let ideas = try #require(parse("tomorrow 3 amazing ideas"))
        #expect(ideas.at == nil)
    }

    // MARK: 타자마다 도는 값

    @Test("한 번 읽는 데 드는 값이 타자 사이에 묻혀야 한다")
    func staysCheapEnoughForEveryKeystroke() {
        // 빠른 입력 상자는 글자를 칠 때마다 이 함수를 부른다. 정규식 리터럴은
        // 쓸 때마다 새로 짜여서 한 번에 0.1ms 씩 드니, 문 앞에서 값싼 검사로
        // 거르지 않으면 금세 손에 느껴진다. 지금은 한 번에 0.3ms 아래다.
        let samples = [
            "내", "내일 오후 3시 치과 예약", "meeting tomorrow at 3pm with the team",
            "明天下午3点 看牙", "우유랑 계란 사기", "3시간 뒤 알람",
        ]
        for text in samples { _ = parse(text) }   // 워밍업

        let rounds = 200
        let start = Date()
        for _ in 0..<rounds {
            for text in samples { _ = parse(text) }
        }
        let each = Date().timeIntervalSince(start) / Double(rounds * samples.count)
        #expect(each < 0.002, "한 번에 \(each * 1000)ms — 정규식을 거르는 문이 열렸는지 본다")
    }

    // MARK: 본문 정리

    @Test("어느 말이든 인식한 조각을 덜어낸다")
    func stripsPhrasesInEveryLanguage() throws {
        func stripped(_ text: String) throws -> String {
            let result = try #require(parse(text))
            return NaturalDateParser.strip(result.phrases, from: text)
        }

        #expect(try stripped("dentist tomorrow at 3pm") == "dentist")
        #expect(try stripped("明日の午後3時 歯医者") == "の 歯医者")
        #expect(try stripped("下周二 复诊") == "复诊")
        #expect(try stripped("내일 저녁 7시 저녁밥") == "저녁밥")
    }
}
