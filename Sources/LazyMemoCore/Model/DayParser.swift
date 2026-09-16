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
            ?? bareDayOfMonth(text, now: now, calendar: calendar)
    }

    // MARK: 못 박힌 날짜

    /// `2026-09-01` · `9월 1일` · `9月1日` · `9月1号` · `Sep 1` · `1st of September`
    ///
    /// `9/1` 같은 빗금 표기는 일부러 뺐다. "3/4 컵" 처럼 날짜가 아닌 쓰임과
    /// 구별할 방법이 없고, 애매하면 아무것도 하지 않는 편이 낫다.
    private static func explicitDate(
        _ text: String, now: Date, calendar: Calendar
    ) -> Result? {
        guard TimeWords.hasDigit(text) else { return nil }
        let thisYear = calendar.component(.year, from: now)

        if text.contains("-"),
           let match = text.firstMatch(of: /\b(\d{4})-(\d{1,2})-(\d{1,2})\b/),
           let year = Int(match.1), let month = Int(match.2), let day = Int(match.3) {
            return made(year: year, month: month, day: day, phrase: String(match.0))
        }

        // 한국어·일본어·중국어가 같은 꼴을 쓴다: (해) 달 날.
        if TimeWords.hasAny(of: "월月", in: text), let match = text.firstMatch(
            of: /(?:(\d{4})\s*[년年]\s*)?(\d{1,2})\s*[월月]\s*(\d{1,2})\s*[일日号號]/
        ), let month = Int(match.2), let day = Int(match.3) {
            return made(
                year: match.1.flatMap { Int($0) } ?? thisYear,
                month: month, day: day, phrase: String(match.0)
            )
        }

        // 달 이름이 아예 없으면 아래 두 정규식은 꺼낼 값어치가 없다 — 낱말이
        // 스물넷씩 늘어선 정규식이라 짜는 데만 0.4ms 씩 든다.
        guard TimeWords.hasLatinLetter(text), TimeWords.mentions(monthHeads, in: text)
        else { return nil }

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

        let week = weekShift(for: day, in: text)
        let today = calendar.component(.weekday, from: now)
        var forward = (day.value - today + 7) % 7
        forward += week.weeks * 7

        guard let date = calendar.date(byAdding: .day, value: forward, to: now) else { return nil }
        return Result(date: CalendarDate(date, calendar: calendar), phrases: week.phrases)
    }

    /// 요일 앞에 붙어 주를 옮기는 말. `다음 주 화요일` · `next friday` · `下周一`
    private static func weekShift(
        for day: TimeWords.Match<Int>, in text: String
    ) -> (weeks: Int, phrases: [String]) {
        if let week = TimeWords.first(of: TimeWords.weekModifiers, in: text) {
            return (week.value, phrases(joining: week, and: day, in: text))
        }

        // 혼자서는 아무 뜻도 아닌 말들 — "next friday" 의 next. 요일에 딱 붙어
        // 있을 때만 센다.
        let head = String(text[..<day.range.lowerBound])
        if let prefix = TimeWords.last(of: TimeWords.weekdayPrefixes, in: head),
           head[prefix.range.upperBound...].allSatisfy(\.isWhitespace) {
            return (prefix.value, [prefix.text, day.text])
        }

        return (0, [day.text])
    }

    /// 주 표현과 요일이 `下周一` 처럼 붙어 있으면 한 조각으로 덜어낸다.
    private static func phrases(
        joining week: TimeWords.Match<Int>, and day: TimeWords.Match<Int>, in text: String
    ) -> [String] {
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
        // 세는 표현에는 반드시 "뒤·후·後·后" 나 "in ... later" 가 붙는다.
        // 그 표식이 없으면 정규식을 꺼낼 일도 없다.
        let counts = TimeWords.hasAny(of: "뒤후後后", in: text)
            || TimeWords.mentions(["있다가", "지나서"], in: text)
        let english = TimeWords.hasLatinLetter(text)
            && TimeWords.mentions(["in ", "later", "from now"], in: text)
        guard counts || english else { return nil }

        if TimeWords.mentions(["개월", "달", "ヶ月", "か月", "个月", "個月", "month"], in: text),
           let found = number(in: text, /(\d{1,2})\s*(?:개월|달|ヶ月|か月|个月|個月)\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? number(in: text, /(?i)\bin\s+(\d{1,2})\s+months?\b/) {
            return shifted(.month, by: found, now: now, calendar: calendar)
        }

        if TimeWords.hasAny(of: "주週周", in: text) || TimeWords.mentions(["week"], in: text),
           let found = number(in: text, /(\d{1,2})\s*(?:주일|주|週間|週|周)\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? number(in: text, /(?i)\bin\s+(\d{1,2})\s+weeks?\b/) {
            return shifted(.weekOfYear, by: found, now: now, calendar: calendar)
        }

        if TimeWords.hasAny(of: "일日天", in: text) || TimeWords.mentions(["day"], in: text),
           let found = number(in: text, /(\d{1,3})\s*[일日天]\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? number(in: text, /(?i)\bin\s+(\d{1,3})\s+days?\b/)
            ?? number(in: text, /(?i)\b(\d{1,3})\s+days?\s+(?:later|from now)\b/) {
            return shifted(.day, by: found, now: now, calendar: calendar)
        }

        // 숫자로 적지 않는 한국어 날수 — "이틀 뒤".
        if TimeWords.first(of: TimeWords.nativeDayCounts, in: text) != nil,
           let match = text.firstMatch(
            of: /(하루|이틀|사흘|나흘|닷새|엿새|이레|여드레|아흐레|열흘)\s*(?:뒤|후|있다가|지나서)/
           ), let entry = TimeWords.nativeDayCounts.first(where: { $0.text == String(match.1) }) {
            return shifted(
                .day, by: (entry.value, String(match.0)), now: now, calendar: calendar
            )
        }

        return nil
    }

    // MARK: 달 없는 날

    /// `22일` — 달을 안 적은 날. 오늘부터 앞으로 가장 가까운 그 날(오늘 포함)로 읽는다 (2026-09-16, 사용자:
    /// 「월 입력 없이 22일이래도 해당 월 22일로 알아먹어야 해」). 지난 날이면 다음 달, 그 달에 없는 날(30일 달의 31일)이면 그다음 달.
    ///
    /// 맨 뒤에 두는 이유는 위의 것들이 전부 이보다 분명해서다 — 「3일 뒤」는 세는 표현이고, 「9월 3일」은 못 박힌 날짜다.
    /// 세는 말·되풀이·빈도가 뒤에 붙은 「3일 동안」「3일째」「1일 2회」와 「일요일」은 날이 아니다.
    private static func bareDayOfMonth(_ text: String, now: Date, calendar: Calendar) -> Result? {
        guard TimeWords.hasDigit(text), text.contains("일") else { return nil }
        // Swift 의 정규식 리터럴은 뒤돌아보기(lookbehind)를 모른다 — NSRegularExpression 으로.
        let pattern = #"(?<![\d월月년年./:-])(\d{1,2})\s*일(?![\d일日요]|\s*(?:동안|간|째|차|마다|정도|쯤|치|이내|안에|뒤|후|전|앞|이후|만에|씩|분|시간|\d+\s*(?:회|번|개|명|잔|알|정|병|장|팩|끼)))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole) {
            guard let dayRange = Range(match.range(at: 1), in: text), let phraseRange = Range(match.range, in: text),
                  let day = Int(text[dayRange]), (1...31).contains(day) else { continue }
            let today = calendar.dateComponents([.year, .month, .day], from: now)
            var year = today.year ?? 1970, month = today.month ?? 1
            if day < (today.day ?? 1) { month += 1; if month > 12 { month = 1; year += 1 } }
            for _ in 0..<3 {
                let candidate = CalendarDate(year: year, month: month, day: day)
                if let start = candidate.startOfDay(calendar: calendar), calendar.component(.day, from: start) == day {
                    return Result(date: candidate, phrases: [String(text[phraseRange])])
                }
                month += 1
                if month > 12 { month = 1; year += 1 }
            }
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
