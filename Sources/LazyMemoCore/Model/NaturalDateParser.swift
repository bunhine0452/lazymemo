import Foundation

/// 사용자가 적은 글에서 날짜와 시각을 알아낸다.
///
/// **"정리를 대신 해준다"(설계문서 §1)가 UI 에서 처음 실현되는 지점이다.**
/// 사용자는 아무 형식도 배우지 않는다. "내일 오후 3시 치과" 라고 적으면
/// 그것이 곧 일정이 된다. LLM 없이, 네트워크 없이, 로컬에서.
///
/// 한국어·영어·일본어·중국어를 함께 읽는다 (`TimeWords`). 어느 말로 적었는지
/// 고르는 절차는 두지 않는다 — 고르게 하는 순간 "아무것도 배우지 않는다" 가
/// 깨진다. 낱말표만 보므로 섞어 적어도 상관없다.
///
/// 욕심내지 않는다. 자주 쓰는 표현만 확실히 잡고, 애매하면 **아무것도 하지
/// 않는다** — 틀린 날짜를 자동으로 붙이는 것이 날짜를 안 붙이는 것보다 나쁘다.
/// 시각만 있고 날짜가 없으면(`3시에 전화`) 어느 날인지 알 수 없으므로 넘긴다.
public enum NaturalDateParser {
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
        /// 글이 **어느 날인지를 직접 말했는가.**
        ///
        /// `새벽 2시` 처럼 시각만 적은 글에서도 날은 정해지지만(다음에 오는
        /// 그 시각), 그건 우리가 고른 날이지 사용자가 말한 날이 아니다.
        /// 달력에서 날을 골라 놓고 적는 자리(`QuickSchedule`)는 이 둘을
        /// 갈라야 한다 — 고른 날을 무시하면 안 되기 때문이다.
        public var namesDay: Bool

        public init(
            due: CalendarDate? = nil, at: Date? = nil, phrases: [String], namesDay: Bool = true
        ) {
            self.due = due
            self.at = at
            self.phrases = phrases
            self.namesDay = namesDay
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

    public static func parse(
        _ text: String,
        now: Date = Date(),
        calendar baseCalendar: Calendar = .current
    ) -> Result? {
        var calendar = baseCalendar
        calendar.firstWeekday = 2   // 한국에서 "이번 주"는 월요일에 시작한다

        // "3시간 뒤" 는 날짜 낱말 없이도 순간이 정해진다.
        if let soon = TimeParser.momentFromNow(text, now: now, calendar: calendar) {
            return Result(at: soon.date, phrases: soon.phrases)
        }

        guard let day = DayParser.parse(text, now: now, calendar: calendar) else {
            return nextOccurrence(in: text, now: now, calendar: calendar)
        }
        guard let time = TimeParser.parse(text) else {
            return Result(due: day.date, phrases: day.phrases)
        }

        guard let midnight = day.date.startOfDay(calendar: calendar),
              let moment = calendar.date(
                  byAdding: DateComponents(hour: time.hour, minute: time.minute), to: midnight
              )
        else {
            return Result(due: day.date, phrases: day.phrases)
        }

        return Result(at: moment, phrases: day.phrases + time.phrases)
    }

    /// 날짜 낱말이 없어도 **때를 말로 밝힌 시각**이면 다음에 오는 그 시각이다.
    ///
    /// `새벽 2시 기상` · `아침 회의` · `저녁 7시 약속` 을 그냥 넘기고 있었다.
    /// 이 앱이 시각을 읽지 않으면 그 메모는 달력에도 없고 아무 때에도 떠오르지
    /// 않는데, 사람이 "새벽 2시" 라고 적었다면 그건 명백히 일정이다.
    ///
    /// 그러면서도 맨 `3시에 전화` 는 여전히 넘긴다. 갈림길은 "어느 날인가" 가
    /// 아니라 **오전인가 오후인가** 다 — `새벽`·`저녁`·`pm`·`15:` 는 글이
    /// 직접 말했고(`TimeParser.Result.isExplicit`), 맨 `3시` 는 우리가
    /// 관행으로 고른 값이다. 짐작 위에 또 짐작을 얹지 않는다.
    ///
    /// 지난 시각이면 내일로 넘긴다. 오늘 아침 8시는 이미 지나갔으므로
    /// "아침 회의" 를 오후 3시에 적었다면 그것은 내일 아침을 뜻한다.
    private static func nextOccurrence(
        in text: String, now: Date, calendar: Calendar
    ) -> Result? {
        guard let time = TimeParser.parse(text), time.isExplicit else { return nil }
        guard let today = calendar.date(
            bySettingHour: time.hour, minute: time.minute, second: 0, of: now
        ) else { return nil }

        let moment = today > now
            ? today
            : calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return Result(at: moment, phrases: time.phrases, namesDay: false)
    }
}
