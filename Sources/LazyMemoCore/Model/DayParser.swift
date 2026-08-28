import Foundation

/// 본문에서 **날짜**를 알아낸다 (시각은 `TimeParser` 가 맡는다).
///
/// 보는 순서가 곧 우선순위다. 못 박힌 날짜(`9월 1일`)가 상대 표현(`내일`)을
/// 이기고, 상대 표현이 요일(`화요일`)을 이긴다. 하나 걸리면 거기서 멈춘다 —
/// 한 메모에 날짜가 둘 있으면 앞의 것이 대개 그 메모의 날짜다.
enum DayParser {

    struct Result {
        let date: CalendarDate
        /// 본문에서 덜어낼 조각들. "다음 주 화요일" 처럼 둘로 나뉠 수 있다.
        let phrases: [String]
    }

    static func parse(_ text: String, now: Date, calendar: Calendar) -> Result? {
        explicitDate(text, now: now, calendar: calendar)
            ?? relativeDay(text, now: now, calendar: calendar)
            ?? namedWeekday(text, now: now, calendar: calendar)
            ?? wholeWeekOrMonth(text, now: now, calendar: calendar)
            ?? counted(text, now: now, calendar: calendar)
    }

    // MARK: 못 박힌 날짜

    /// `2026-09-01` · `9월 1일` · `9月1日` · `9月1号` · `Sep 1` · `1st of September`
    ///
    /// `9/1` 같은 빗금 표기는 일부러 뺐다. "3/4 컵" 처럼 날짜가 아닌 쓰임과
    /// 구별할 방법이 없고, 애매하면 아무것도 하지 않는 편이 낫다.
    private static func explicitDate(
        _ text: String, now: Date, calendar: Calendar
    ) -> Result? {
        let thisYear = calendar.component(.year, from: now)

        if let match = text.firstMatch(of: /\b(\d{4})-(\d{1,2})-(\d{1,2})\b/),
           let year = Int(match.1), let month = Int(match.2), let day = Int(match.3) {
            return made(year: year, month: month, day: day, phrase: String(match.0))
        }

        // 한국어·일본어·중국어가 같은 꼴을 쓴다: (해) 달 날.
        if let match = text.firstMatch(
            of: /(?:(\d{4})\s*[년年]\s*)?(\d{1,2})\s*[월月]\s*(\d{1,2})\s*[일日号號]/
        ), let month = Int(match.2), let day = Int(match.3) {
            return made(
                year: match.1.flatMap { Int($0) } ?? thisYear,
                month: month, day: day, phrase: String(match.0)
            )
        }

        // 영어 달 이름. 긴 이름을 먼저 적어야 짧은 쪽에서 잘리지 않는다.
        if let match = text.firstMatch(
            of: /(?i)\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b/
        ), let month = monthNumber(String(match.1)), let day = Int(match.2) {
            return made(year: thisYear, month: month, day: day, phrase: String(match.0))
        }

        if let match = text.firstMatch(
            of: /(?i)\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec)\.?\b/
        ), let day = Int(match.1), let month = monthNumber(String(match.2)) {
            return made(year: thisYear, month: month, day: day, phrase: String(match.0))
        }

        return nil
    }

    private static let monthHeads = [
        "jan", "feb", "mar", "apr", "may", "jun",
        "jul", "aug", "sep", "oct", "nov", "dec",
    ]

    private static func monthNumber(_ name: String) -> Int? {
        let head = String(name.lowercased().prefix(3))
        return monthHeads.firstIndex(of: head).map { $0 + 1 }
    }

    private static func made(year: Int, month: Int, day: Int, phrase: String) -> Result? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return Result(date: CalendarDate(year: year, month: month, day: day), phrases: [phrase])
    }

    // MARK: 상대 표현

    /// `오늘` · `내일` · `모레` · `tomorrow` · `明後日` · `后天`
    private static func relativeDay(
        _ text: String, now: Date, calendar: Calendar
    ) -> Result? {
        guard let found = TimeWords.first(of: TimeWords.relativeDays, in: text),
              let date = calendar.date(byAdding: .day, value: found.value, to: now)
        else { return nil }
        return Result(date: CalendarDate(date, calendar: calendar), phrases: [found.text])
    }

    /// `화요일` · `다음 주 화요일` · `next friday` · `来週月曜日` · `下周一` · `주말`
    ///
    /// 오늘을 포함해 **앞으로 가장 가까운** 그 요일로 읽는다. 지난 요일을 뜻하려면
    /// "지난 주" 를 함께 적어야 한다.
    private static func namedWeekday(
        _ text: String, now: Date, calendar: Calendar
    ) -> Result? {
        guard let day = TimeWords.first(of: TimeWords.weekdays, in: text) else { return nil }

        let week = TimeWords.first(of: TimeWords.weekModifiers, in: text)
        let today = calendar.component(.weekday, from: now)
        var forward = (day.value - today + 7) % 7
        forward += (week?.value ?? 0) * 7

        guard let date = calendar.date(byAdding: .day, value: forward, to: now) else { return nil }
        return Result(
            date: CalendarDate(date, calendar: calendar),
            phrases: phrases(joining: week, and: day, in: text)
        )
    }

    /// 주 표현과 요일이 `下周一` 처럼 붙어 있으면 한 조각으로 덜어낸다.
    private static func phrases(
        joining week: TimeWords.Match<Int>?, and day: TimeWords.Match<Int>, in text: String
    ) -> [String] {
        guard let week else { return [day.text] }
        guard week.range.overlaps(day.range) else { return [week.text, day.text] }
        let joined = min(week.range.lowerBound, day.range.lowerBound)
            ..< max(week.range.upperBound, day.range.upperBound)
        return [String(text[joined])]
    }

    /// 요일 없이 주·달만 적은 경우. `다음 주` · `next month` · `来週` · `下个月`
    ///
    /// "이번 주"·"이번 달" 은 **오늘**로 읽는다 — 그 주의 첫날은 이미 지났을 수
    /// 있어서 뒤로 돌리면 거짓말이 된다. 다른 주·달은 그 첫날을 가리킨다.
    private static func wholeWeekOrMonth(
        _ text: String, now: Date, calendar: Calendar
    ) -> Result? {
        if let week = TimeWords.first(of: TimeWords.weekModifiers, in: text) {
            guard week.value != 0 else {
                return Result(date: CalendarDate(now, calendar: calendar), phrases: [week.text])
            }
            guard let start = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ), let date = calendar.date(byAdding: .day, value: week.value * 7, to: start)
            else { return nil }
            return Result(date: CalendarDate(date, calendar: calendar), phrases: [week.text])
        }

        guard let month = TimeWords.first(of: TimeWords.monthModifiers, in: text) else { return nil }
        guard month.value != 0 else {
            return Result(date: CalendarDate(now, calendar: calendar), phrases: [month.text])
        }
        guard let shifted = calendar.date(byAdding: .month, value: month.value, to: now),
              let date = calendar.date(from: calendar.dateComponents([.year, .month], from: shifted))
        else { return nil }
        return Result(date: CalendarDate(date, calendar: calendar), phrases: [month.text])
    }

    // MARK: 세어서 미루기

    /// `3일 뒤` · `이틀 후` · `in 3 days` · `3日後` · `3天后` · `2주 뒤` · `3개월 후`
    ///
    /// 달 → 주 → 날 순으로 본다. "1주일 뒤" 에서 날(`일`)이 먼저 걸리면 안 된다.
    private static func counted(_ text: String, now: Date, calendar: Calendar) -> Result? {
        if let found = number(in: text, /(\d{1,2})\s*(?:개월|달|ヶ月|か月|个月|個月)\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? number(in: text, /(?i)\bin\s+(\d{1,2})\s+months?\b/) {
            return shifted(.month, by: found, now: now, calendar: calendar)
        }

        if let found = number(in: text, /(\d{1,2})\s*(?:주일|주|週間|週|周)\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? number(in: text, /(?i)\bin\s+(\d{1,2})\s+weeks?\b/) {
            return shifted(.weekOfYear, by: found, now: now, calendar: calendar)
        }

        if let found = number(in: text, /(\d{1,3})\s*[일日天]\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? number(in: text, /(?i)\bin\s+(\d{1,3})\s+days?\b/)
            ?? number(in: text, /(?i)\b(\d{1,3})\s+days?\s+(?:later|from now)\b/) {
            return shifted(.day, by: found, now: now, calendar: calendar)
        }

        // 숫자로 적지 않는 한국어 날수 — "이틀 뒤".
        if let match = text.firstMatch(
            of: /(하루|이틀|사흘|나흘|닷새|엿새|이레|여드레|아흐레|열흘)\s*(?:뒤|후|있다가|지나서)/
        ), let entry = TimeWords.nativeDayCounts.first(where: { $0.text == String(match.1) }) {
            return shifted(
                .day, by: (entry.value, String(match.0)), now: now, calendar: calendar
            )
        }

        return nil
    }

    private static func number(
        in text: String, _ regex: Regex<(Substring, Substring)>
    ) -> (count: Int, phrase: String)? {
        guard let match = text.firstMatch(of: regex), let count = Int(match.1) else { return nil }
        return (count, String(match.0))
    }

    private static func shifted(
        _ unit: Calendar.Component,
        by found: (count: Int, phrase: String),
        now: Date,
        calendar: Calendar
    ) -> Result? {
        guard let date = calendar.date(byAdding: unit, value: found.count, to: now) else { return nil }
        return Result(date: CalendarDate(date, calendar: calendar), phrases: [found.phrase])
    }
}
