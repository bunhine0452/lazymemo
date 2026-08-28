import Foundation

/// 사용자가 적은 한국어에서 날짜와 시각을 알아낸다.
///
/// **"정리를 대신 해준다"(설계문서 §1)가 UI 에서 처음 실현되는 지점이다.**
/// 사용자는 아무 형식도 배우지 않는다. "내일 오후 3시 치과" 라고 적으면
/// 그것이 곧 일정이 된다. LLM 없이, 네트워크 없이, 로컬에서.
///
/// 욕심내지 않는다. 자주 쓰는 표현만 확실히 잡고, 애매하면 **아무것도 하지
/// 않는다** — 틀린 날짜를 자동으로 붙이는 것이 날짜를 안 붙이는 것보다 나쁘다.
public enum KoreanDateParser {
    public struct Result: Sendable, Equatable {
        /// 날짜만 인식된 경우 (마감·목표).
        public var due: CalendarDate?
        /// 시각까지 인식된 경우 (약속).
        public var at: Date?
        /// 인식한 원문 조각들. 본문에서 덜어내는 데 쓴다.
        ///
        /// 하나로 합친 문자열이 아니라 조각 배열인 이유: "내일 치과 오후 3시"
        /// 처럼 날짜와 시각이 떨어져 있을 수 있다.
        public var phrases: [String]

        public init(due: CalendarDate? = nil, at: Date? = nil, phrases: [String]) {
            self.due = due
            self.at = at
            self.phrases = phrases
        }
    }

    /// 인식한 조각을 본문에서 덜어낸다.
    ///
    /// 날짜는 칩으로 따로 보이므로 본문에 남겨 둘 이유가 없고, "내일 오후 3시
    /// 치과" 가 내일이 지나면 거짓말이 되기 때문이다. 다만 덜어내서 아무것도
    /// 남지 않으면 원문을 그대로 둔다 — 빈 메모를 만드는 것이 더 나쁘다.
    public static func strip(_ phrases: [String], from text: String) -> String {
        var result = text
        for phrase in phrases {
            if let range = result.range(of: phrase) {
                result.replaceSubrange(range, with: " ")
            }
        }
        let collapsed = result
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? text : collapsed
    }

    /// 요일 이름 → `Calendar` 의 weekday (일요일 = 1).
    private static let weekdayNames: [(name: String, weekday: Int)] = [
        ("일요일", 1), ("월요일", 2), ("화요일", 3), ("수요일", 4),
        ("목요일", 5), ("금요일", 6), ("토요일", 7),
    ]

    private static let relativeDays: [(name: String, offset: Int)] = [
        // 긴 것부터 본다 — "모레" 를 보기 전에 "글피" 를 놓치지 않도록.
        ("글피", 3), ("모레", 2), ("내일", 1), ("오늘", 0),
    ]

    public static func parse(
        _ text: String,
        now: Date = Date(),
        calendar baseCalendar: Calendar = .current
    ) -> Result? {
        var calendar = baseCalendar
        calendar.firstWeekday = 2   // 한국에서 "이번 주"는 월요일에 시작한다

        guard let day = parseDay(text, now: now, calendar: calendar) else { return nil }
        let time = parseTime(text)

        guard let time else {
            return Result(due: day.date, phrases: [day.matchedText])
        }

        guard let midnight = day.date.startOfDay(calendar: calendar),
              let moment = calendar.date(
                  byAdding: DateComponents(hour: time.hour, minute: time.minute), to: midnight
              )
        else {
            return Result(due: day.date, phrases: [day.matchedText])
        }

        return Result(at: moment, phrases: [day.matchedText, time.matchedText])
    }

    // MARK: 날짜

    private struct DayMatch {
        let date: CalendarDate
        let matchedText: String
    }

    private static func parseDay(
        _ text: String, now: Date, calendar: Calendar
    ) -> DayMatch? {
        if let explicit = parseExplicitDate(text, now: now, calendar: calendar) { return explicit }
        if let relative = parseRelativeDay(text, now: now, calendar: calendar) { return relative }
        if let weekday = parseWeekday(text, now: now, calendar: calendar) { return weekday }
        if let counted = parseDayCount(text, now: now, calendar: calendar) { return counted }
        return nil
    }

    /// `9월 1일`
    ///
    /// `9/1` 같은 빗금 표기는 일부러 뺐다. "3/4 컵" 처럼 날짜가 아닌 쓰임과
    /// 구별할 방법이 없고, 애매하면 아무것도 하지 않는 편이 낫다.
    private static func parseExplicitDate(
        _ text: String, now: Date, calendar: Calendar
    ) -> DayMatch? {
        let currentYear = calendar.component(.year, from: now)

        if let match = text.firstMatch(of: /(\d{1,2})월\s*(\d{1,2})일/),
           let month = Int(match.1), let day = Int(match.2),
           (1...12).contains(month), (1...31).contains(day) {
            return DayMatch(
                date: CalendarDate(year: currentYear, month: month, day: day),
                matchedText: String(match.0)
            )
        }

        return nil
    }

    /// `오늘` · `내일` · `모레` · `글피`
    private static func parseRelativeDay(
        _ text: String, now: Date, calendar: Calendar
    ) -> DayMatch? {
        for entry in relativeDays where text.contains(entry.name) {
            guard let date = calendar.date(byAdding: .day, value: entry.offset, to: now)
            else { continue }
            return DayMatch(date: CalendarDate(date, calendar: calendar), matchedText: entry.name)
        }
        return nil
    }

    /// `화요일` · `이번 주 화요일` · `다음 주 화요일` · `담주 화요일`
    private static func parseWeekday(
        _ text: String, now: Date, calendar: Calendar
    ) -> DayMatch? {
        guard let entry = weekdayNames.first(where: { text.contains($0.name) }) else { return nil }

        let wantsNextWeek = ["다음 주", "다음주", "담주", "낼주"].contains { text.contains($0) }
        let prefix = wantsNextWeek ? "다음 주 " : ""

        let today = calendar.component(.weekday, from: now)
        // 오늘 포함, 앞으로 가장 가까운 그 요일.
        var forward = (entry.weekday - today + 7) % 7
        if wantsNextWeek { forward += 7 }

        guard let date = calendar.date(byAdding: .day, value: forward, to: now) else { return nil }
        return DayMatch(
            date: CalendarDate(date, calendar: calendar),
            matchedText: prefix + entry.name
        )
    }

    /// `3일 뒤` · `3일 후`
    private static func parseDayCount(
        _ text: String, now: Date, calendar: Calendar
    ) -> DayMatch? {
        guard let match = text.firstMatch(of: /(\d{1,3})일\s*(뒤|후)/),
              let count = Int(match.1),
              let date = calendar.date(byAdding: .day, value: count, to: now)
        else { return nil }

        return DayMatch(date: CalendarDate(date, calendar: calendar), matchedText: String(match.0))
    }

    // MARK: 시각

    private struct TimeMatch {
        let hour: Int
        let minute: Int
        let matchedText: String
    }

    /// `오후 3시` · `3시 30분` · `3시 반` · `15시`
    private static func parseTime(_ text: String) -> TimeMatch? {
        guard let match = text.firstMatch(of: /(오전|오후)?\s*(\d{1,2})시\s*(반|(\d{1,2})분)?/)
        else { return nil }

        guard var hour = Int(match.2), (0...23).contains(hour) else { return nil }

        let meridiem = match.1.map(String.init)
        switch meridiem {
        case "오후": if hour < 12 { hour += 12 }
        case "오전": if hour == 12 { hour = 0 }
        default:
            // 표기가 없으면 한국어 관행을 따른다 — "3시" 는 대개 오후 세 시다.
            // 8시부터 12시까지는 오전으로 읽는 편이 실제 쓰임에 가깝다.
            if (1...7).contains(hour) { hour += 12 }
        }

        var minute = 0
        if let suffix = match.3.map(String.init) {
            minute = suffix == "반" ? 30 : (match.4.flatMap { Int($0) } ?? 0)
        }
        guard (0...59).contains(minute) else { return nil }

        return TimeMatch(hour: hour, minute: minute, matchedText: String(match.0).trimmed)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
