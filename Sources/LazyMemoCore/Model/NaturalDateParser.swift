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

        guard let day = DayParser.parse(text, now: now, calendar: calendar) else { return nil }
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
}
