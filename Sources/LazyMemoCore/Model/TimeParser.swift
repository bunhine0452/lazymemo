import Foundation

/// 본문에서 **시각**을 알아낸다 (날짜는 `DayParser` 가 맡는다).
///
/// 숫자로 못 박은 시각(`3pm` · `오후 3시` · `15:30`)을 먼저 보고, 없으면
/// 하루 중 때(`아침` · `저녁` · `晚上`)를 대표 시각으로 읽는다.
enum TimeParser {

    struct Result {
        let hour: Int
        let minute: Int
        /// 본문에서 덜어낼 조각들. 때와 숫자가 떨어져 있으면 둘로 나뉜다.
        let phrases: [String]
        /// 오전인지 오후인지를 **글이 직접 말했는가.**
        ///
        /// `새벽 2시` · `저녁 7시` · `3pm` · `15:30` 은 말했고, 맨 `3시` 는
        /// 말하지 않았다 — 뒤엣것의 24시간제 값은 우리가 관행으로 고른 것이다
        /// (`byConvention`). 날짜 낱말이 없을 때 이 구분이 갈림길이 된다
        /// (`NaturalDateParser`).
        let isExplicit: Bool

        init(hour: Int, minute: Int, phrases: [String], isExplicit: Bool = true) {
            self.hour = hour
            self.minute = minute
            self.phrases = phrases
            self.isExplicit = isExplicit
        }
    }

    static func parse(_ text: String) -> Result? {
        meridiemClock(text)
            ?? cjkClock(text)
            ?? colonClock(text)
            ?? bareHour(text)
            ?? namedPeriod(text)
    }

    // MARK: 숫자로 못 박은 시각

    /// `3pm` · `at 3:30 p.m.`
    ///
    /// 뒤에 낱말 경계를 둔다 — 그러지 않으면 "3 amazing" 의 `am` 이 걸린다.
    private static func meridiemClock(_ text: String) -> Result? {
        guard TimeWords.hasDigit(text), TimeWords.hasAny(of: "mM", in: text) else { return nil }
        guard let match = text.firstMatch(
            of: /(?i)(?:\bat\s+)?\b(\d{1,2})(?::(\d{2}))?\s*(a|p)\.?\s?m\b\.?/
        ), var hour = Int(match.1), (0...23).contains(hour) else { return nil }

        let minute = match.2.flatMap { Int($0) } ?? 0
        guard (0...59).contains(minute) else { return nil }

        if String(match.3).lowercased() == "p" {
            if hour < 12 { hour += 12 }
        } else if hour == 12 {
            hour = 0
        }
        return Result(hour: hour, minute: minute, phrases: [String(match.0)])
    }

    /// `오후 3시` · `3시 30분` · `3시 반` · `15시` · `午後3時半` · `下午3点`
    ///
    /// `시(?!간)` 인 이유: "3시간 뒤" 의 `3시` 는 시각이 아니다.
    private static func cjkClock(_ text: String) -> Result? {
        guard TimeWords.hasDigit(text), TimeWords.hasAny(of: "시時时点點", in: text) else { return nil }
        guard let match = text.firstMatch(
            of: /(\d{1,2})\s*(?:시(?!간)|[時时点點])\s*(?:(반|半)|(\d{1,2})\s*[분分])?(?:\s*(?:에|쯤|경|頃|ごろ))?/
        ), let stated = Int(match.1), (0...23).contains(stated) else { return nil }

        let minute = match.2 != nil ? 30 : (match.3.flatMap { Int($0) } ?? 0)
        guard (0...59).contains(minute) else { return nil }

        return dressed(stated: stated, minute: minute, clock: match.0, in: text)
    }

    /// `15:30` · `at 9:00`
    private static func colonClock(_ text: String) -> Result? {
        guard text.contains(":"),
              let match = text.firstMatch(of: /(?i)(?:\bat\s+)?\b(\d{1,2}):(\d{2})\b/),
              let stated = Int(match.1), (0...23).contains(stated),
              let minute = Int(match.2), (0...59).contains(minute)
        else { return nil }
        return dressed(stated: stated, minute: minute, clock: match.0, in: text)
    }

    /// `at 7` — 영어는 시(時)에 해당하는 글자가 없어서 `at` 이 그 자리를 맡는다.
    ///
    /// `at` 을 요구하는 이유: 맨 숫자까지 시각으로 보면 "tomorrow 3 boxes" 가
    /// 세 시가 된다.
    private static func bareHour(_ text: String) -> Result? {
        guard TimeWords.mentions(["at "], in: text),
              let match = text.firstMatch(of: /(?i)\bat\s+(\d{1,2})\b/),
              let stated = Int(match.1), (0...23).contains(stated)
        else { return nil }
        return dressed(stated: stated, minute: 0, clock: match.0, in: text)
    }

    /// 숫자 없이 때만 적은 경우. `내일 저녁` · `tomorrow morning` · `明日の朝`
    private static func namedPeriod(_ text: String) -> Result? {
        guard let found = TimeWords.first(of: TimeWords.periods, in: text) else { return nil }
        return Result(hour: found.value.defaultHour, minute: 0, phrases: [found.text])
    }

    // MARK: 오전인가 오후인가

    /// 숫자 앞에 붙은 때를 찾아 24시간제로 옮긴다.
    private static func dressed(
        stated: Int, minute: Int, clock: Substring, in text: String
    ) -> Result {
        guard let part = period(before: clock.startIndex, in: text) else {
            // 13시를 넘는 수는 24시간제로 적은 것이라 그 자체로 오후를 말한다.
            return Result(
                hour: byConvention(stated), minute: minute, phrases: [String(clock)],
                isExplicit: stated == 0 || stated >= 13
            )
        }
        return Result(
            hour: part.value.hour(from: stated),
            minute: minute,
            phrases: [part.text, String(clock)]
        )
    }

    /// 표기가 없으면 관행을 따른다 — "3시" 는 대개 오후 세 시다.
    /// 8시부터 12시까지는 오전으로 읽는 편이 실제 쓰임에 가깝다.
    private static func byConvention(_ stated: Int) -> Int {
        (1...7).contains(stated) ? stated + 12 : stated
    }

    /// 시각 바로 앞에 붙은 때. "오후 3시" 의 `오후`, "tomorrow morning at 7" 의 `morning`.
    ///
    /// 사이에 다른 말이 끼면 그 때는 이 시각을 꾸미는 말이 아니다 —
    /// "아침에 산 우유 3시에 마시기" 의 `아침` 이 3시를 오전으로 만들면 안 된다.
    private static func period(
        before start: String.Index, in text: String
    ) -> TimeWords.Match<TimeWords.DayPart>? {
        let head = String(text[..<start])
        guard let found = TimeWords.last(of: TimeWords.periods, in: head) else { return nil }
        let gap = head[found.range.upperBound...]
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return bridges.contains(gap) ? found : nil
    }

    /// 때와 숫자 사이에 놓여도 좋은 말들.
    private static let bridges: Set<String> = ["", "at", "에", "쯤", "경", "の", "ごろ", "頃"]

    // MARK: 지금으로부터

    /// `3시간 뒤` · `20분 후` · `in 2 hours` · `30分後` · `一小时后`
    ///
    /// 날짜 낱말 없이도 순간이 정해지는 유일한 표현이라 따로 본다.
    static func momentFromNow(
        _ text: String, now: Date, calendar: Calendar
    ) -> (date: Date, phrases: [String])? {
        // "뒤·후" 나 "in" 이 없으면 지금으로부터를 말한 것이 아니다.
        let counts = TimeWords.hasAny(of: "뒤후後后", in: text)
            || (TimeWords.hasLatinLetter(text) && TimeWords.mentions(["in "], in: text))
        guard counts else { return nil }

        if TimeWords.mentions(["시간", "時間", "小时", "小時", "hour", "hr"], in: text) {
            if let found = counted(in: text, /(?:지금\s*(?:부터\s*)?)?(\d{1,3})\s*(?:시간|時間|小时|小時)\s*(?:뒤|후|後|后|이후|以後|以后)/)
                ?? counted(in: text, /(?i)\bin\s+(\d{1,3})\s+(?:hours?|hrs?)\b/) {
                return moment(byAdding: found.count * 60, phrase: found.phrase, now: now, calendar: calendar)
            }
            if let match = text.firstMatch(of: /(?i)\bin\s+an?\s+(hour|hr)\b/) {
                return moment(byAdding: 60, phrase: String(match.0), now: now, calendar: calendar)
            }
            if let match = text.firstMatch(of: /(?:지금\s*(?:부터\s*)?)?(한|두|세|네)\s*시간\s*(?:뒤|후|이후)/),
               let hours = nativeHours[String(match.1)] {
                return moment(byAdding: hours * 60, phrase: String(match.0), now: now, calendar: calendar)
            }
        }

        if TimeWords.hasAny(of: "분分", in: text) || TimeWords.mentions(["minute", "min"], in: text),
           let found = counted(in: text, /(?:지금\s*(?:부터\s*)?)?(\d{1,3})\s*(?:분|分鐘|分钟|分)\s*(?:뒤|후|後|后|이후|以後|以后)/)
            ?? counted(in: text, /(?i)\bin\s+(\d{1,3})\s+(?:minutes?|mins?)\b/) {
            return moment(byAdding: found.count, phrase: found.phrase, now: now, calendar: calendar)
        }

        return nil
    }

    private static let nativeHours = ["한": 1, "두": 2, "세": 3, "네": 4]

    private static func counted(
        in text: String, _ regex: Regex<(Substring, Substring)>
    ) -> (count: Int, phrase: String)? {
        guard let match = text.firstMatch(of: regex), let count = Int(match.1) else { return nil }
        return (count, String(match.0))
    }

    private static func moment(
        byAdding minutes: Int, phrase: String, now: Date, calendar: Calendar
    ) -> (date: Date, phrases: [String])? {
        guard let date = calendar.date(byAdding: .minute, value: minutes, to: now) else { return nil }
        return (date, [phrase])
    }
}
