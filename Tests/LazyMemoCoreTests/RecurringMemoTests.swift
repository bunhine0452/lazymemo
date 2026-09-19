import Foundation
import Testing
@testable import LazyMemoCore

/// 되풀이하는 일과 「지난 일정은 물러난다」의 충돌 (`{#recurring-vs-tidy}`).
@Suite("되풀이하는 일")
struct RecurringMemoTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: 파일

    @Test("주기를 낱말로 적고 왕복해도 변하지 않는다")
    func roundTrips() throws {
        let text = """
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            due: 2026-09-01
            every: 매주
            ---
            분리수거
            """
        let memo = try MemoFile.decode(text)
        #expect(memo.every == .weekly)
        #expect(MemoFile.encode(memo).contains("every: 매주"))
        #expect(try MemoFile.decode(MemoFile.encode(memo)).every == .weekly)
    }

    // MARK: 치우기와의 충돌

    @Test("되풀이하는 일은 물러나지 않는다 — 분리수거가 한 번 하고 사라지면 안 된다")
    func neverTidiedAway() {
        let past = CalendarDate(year: 2026, month: 8, day: 4)
        let now = date(2026, 8, 31, 12)

        // 같은 메모라도 주기가 없으면 물러난다.
        #expect(Tidy.reason(for: Memo(due: past), now: now, calendar: calendar) == .past)
        // 주기가 있으면 물러나지 않는다.
        #expect(Tidy.reason(for: Memo(due: past, every: .weekly), now: now, calendar: calendar) == nil)
    }

    @Test("대신 다음 회차로 걸어간다")
    func rollsForward() {
        let memo = Memo(at: date(2026, 8, 4, 8), every: .weekly)   // 화요일 8시
        let rolled = Tidy.rolled(memo, now: date(2026, 8, 31, 12), calendar: calendar)
        #expect(rolled?.at == date(2026, 9, 1, 8))                  // 다음 화요일
        #expect(calendar.component(.weekday, from: rolled!.at!) == 3)
    }

    @Test("나올 때도 함께 걸어간다 — 다음 회차에 종이가 안 나오면 소용이 없다")
    func carriesSurfaceForward() {
        let at = date(2026, 8, 4, 8)
        let memo = Memo(at: at, every: .weekly, surface: at.addingTimeInterval(-1800))
        let rolled = Tidy.rolled(memo, now: date(2026, 8, 31, 12), calendar: calendar)
        #expect(rolled?.surface == rolled!.at!.addingTimeInterval(-1800))
        #expect(rolled?.surfaceLead == "30분 전")
    }

    @Test("아직 안 지난 회차는 그대로 둔다")
    func leavesUpcomingAlone() {
        let memo = Memo(at: date(2026, 9, 15, 8), every: .weekly)
        #expect(Tidy.rolled(memo, now: date(2026, 8, 31, 12), calendar: calendar) == nil)
    }

    @Test("날짜만 있는 것은 그 날이 끝나야 걸어간다")
    func dateOnlyWaitsForTheDayToEnd() {
        let today = Memo(due: CalendarDate(year: 2026, month: 8, day: 31), every: .daily)
        // 오늘 것은 아직 지나지 않았다.
        #expect(Tidy.rolled(today, now: date(2026, 8, 31, 12), calendar: calendar) == nil)

        let yesterday = Memo(due: CalendarDate(year: 2026, month: 8, day: 30), every: .daily)
        #expect(Tidy.rolled(yesterday, now: date(2026, 8, 31, 12), calendar: calendar)?.due
            == CalendarDate(year: 2026, month: 8, day: 31))
    }

    @Test("「매월 31일」은 2월을 지나도 31일로 돌아온다 — 처음 날을 적어 두고 거기서 잰다")
    func monthlyReturnsToTheAnchorDay() throws {
        let rent = Memo(at: date(2026, 1, 31, 9), every: .monthly)
        let february = try #require(Tidy.rolled(rent, now: date(2026, 2, 1, 12), calendar: calendar))
        #expect(february.at == date(2026, 2, 28, 9))
        #expect(february.anchor == CalendarDate(year: 2026, month: 1, day: 31))
        // 파일을 오간 뒤에도 처음 날은 남는다.
        let reread = try MemoFile.decode(MemoFile.encode(february))
        #expect(reread.anchor == february.anchor)

        let march = try #require(Tidy.rolled(reread, now: date(2026, 3, 1, 12), calendar: calendar))
        #expect(march.at == date(2026, 3, 31, 9))
        let april = try #require(Tidy.rolled(march, now: date(2026, 4, 1, 12), calendar: calendar))
        #expect(april.at == date(2026, 4, 30, 9))
    }

    @Test("처음 날이 지금 날을 설명하지 못하면 지금 날이 새 처음이다 — 사람이 옮긴 날")
    func movedDayBecomesTheNewAnchor() throws {
        var memo = Memo(due: CalendarDate(year: 2026, month: 3, day: 15), every: .monthly)
        memo.anchor = CalendarDate(year: 2026, month: 1, day: 31)   // 옛 처음 날 — 15일과 무관하다
        let rolled = try #require(Tidy.rolled(memo, now: date(2026, 3, 16, 12), calendar: calendar))
        #expect(rolled.due == CalendarDate(year: 2026, month: 4, day: 15))
        #expect(rolled.anchor == CalendarDate(year: 2026, month: 3, day: 15))
    }

    @Test("매주·매일은 처음 날을 적지 않는다 — 잘릴 일이 없다")
    func weeklyNeedsNoAnchor() {
        let memo = Memo(at: date(2026, 8, 4, 8), every: .weekly)
        #expect(Tidy.rolled(memo, now: date(2026, 8, 31, 12), calendar: calendar)?.anchor == nil)
    }

    @Test("걸어간 것은 다시 산 것이다 — 치워 뒀더라도 도로 나온다")
    func revivesTidied() {
        var memo = Memo(at: date(2026, 8, 4, 8), every: .weekly)
        memo.tidied = date(2026, 8, 6)
        #expect(Tidy.rolled(memo, now: date(2026, 8, 31, 12), calendar: calendar)?.tidied == nil)
    }

    @Test("평일 되풀이는 금요일에서 월요일로 걸어간다")
    func weekdaysRollOverTheWeekend() {
        let memo = Memo(at: date(2026, 9, 4, 8), every: .weekdays)   // 금요일 8시
        let rolled = Tidy.rolled(memo, now: date(2026, 9, 5, 12), calendar: calendar)
        #expect(rolled?.at == date(2026, 9, 7, 8))
        #expect(rolled?.anchor == nil, "잘리지 않는 주기는 처음 날을 적지 않는다")
    }

    @Test("날짜가 없으면 걸어갈 자리도 없다")
    func nothingToRollWithoutADate() {
        #expect(Tidy.rolled(Memo(every: .daily, body: "물 마시기"), now: date(2026, 8, 31)) == nil)
    }
}

@Suite("되풀이를 글에서 읽기")
struct RecurrenceParsingTests {
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
    }

    @Test("「매주 화요일 8시」에서 주기와 요일과 시각을 함께 읽는다")
    func readsWeeklyWithWeekday() {
        let result = NaturalDateParser.parse("매주 화요일 8시 분리수거", now: now)
        #expect(result?.every == .weekly)
        // 요일은 규칙이 아니라 **나머지 글**이 정한다 — 2026-08-28 은 금요일.
        #expect(result?.at != nil)
        #expect(NaturalDateParser.strip(result!.phrases, from: "매주 화요일 8시 분리수거")
            == "분리수거")
    }

    @Test("주기만 적고 날짜를 안 적었으면 오늘부터로 친다")
    func startsTodayWithoutADate() {
        let result = NaturalDateParser.parse("매일 물 마시기", now: now)
        #expect(result?.every == .daily)
        #expect(result?.due == CalendarDate(year: 2026, month: 8, day: 28))
    }

    @Test("주기가 없는 글은 예전과 똑같이 읽힌다")
    func unchangedWithoutRecurrence() {
        let result = NaturalDateParser.parse("내일 장보기", now: now)
        #expect(result?.every == nil)
        #expect(result?.due == CalendarDate(year: 2026, month: 8, day: 29))
    }

    @Test("「격주 화요일 8시」— 두 주에 한 번, 요일은 글이 정한다")
    func readsBiweekly() {
        let result = NaturalDateParser.parse("격주 화요일 8시 회의", now: now)
        #expect(result?.every == .biweekly)
        #expect(result?.at != nil)
        #expect(NaturalDateParser.strip(result!.phrases, from: "격주 화요일 8시 회의") == "회의")
    }

    @Test("「평일 아침 8시 약」을 주말에 적으면 첫 회차는 월요일이다")
    func weekdaysSkipTheWeekend() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // 2026-08-29 는 토요일.
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 10))!
        let result = NaturalDateParser.parse("평일 아침 8시 약", now: saturday, calendar: calendar)
        #expect(result?.every == .weekdays)
        #expect(result?.namesDay == false)
        let landed = result?.at.map { CalendarDate($0, calendar: calendar) }
        #expect(landed == CalendarDate(year: 2026, month: 8, day: 31))
        #expect(result?.at.map { calendar.component(.hour, from: $0) } == 8)
        #expect(NaturalDateParser.strip(result!.phrases, from: "평일 아침 8시 약") == "약")

        // 날짜 없이 주기만 — 오늘이 주말이면 월요일부터.
        let daily = NaturalDateParser.parse("평일 물 마시기", now: saturday, calendar: calendar)
        #expect(daily?.due == CalendarDate(year: 2026, month: 8, day: 31))
        // 평일에 적으면 그날부터.
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
        #expect(NaturalDateParser.parse("평일 물 마시기", now: friday, calendar: calendar)?.due
            == CalendarDate(year: 2026, month: 8, day: 28))
        // 사람이 날을 직접 말했으면 고쳐 쓰지 않는다.
        let named = NaturalDateParser.parse("평일 토요일 8시 약", now: friday, calendar: calendar)
        #expect(named?.at.map { calendar.isDateInWeekend($0) } == true)
    }

    @Test("문으로 들어온 글도 되풀이를 읽는다")
    func doorsReadItToo() {
        let note = NoteReader.read("매주 금요일 재활용", now: now)
        #expect(note.every == .weekly)
        #expect(note.body == "재활용")
    }
}
