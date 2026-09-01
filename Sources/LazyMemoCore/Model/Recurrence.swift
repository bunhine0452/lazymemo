import Foundation

/// 되풀이하는 일 — 분리수거·약·정기결제·주간 보고.
///
/// **주기만 말하고 언제인지는 말하지 않는다.** 「매주」이면 지금 적힌 날짜의
/// 요일이 그 요일이고, 「매월」이면 그 날짜의 일(日)이 그 날이다. 규칙이
/// 스스로 «화요일» 을 들고 있으면 날짜와 규칙이 서로 다른 말을 하는 날이 오고,
/// 그때 어느 쪽이 옳은지 정할 방법이 없다.
///
/// 그래서 이 타입은 낱말 네 개가 전부다. 파일에도 그 낱말이 그대로 적힌다 —
/// `every: 매주`.
public enum Recurrence: Sendable, Equatable, CaseIterable {
    case daily, weekly, monthly, yearly

    public var label: String {
        switch self {
        case .daily: "매일"
        case .weekly: "매주"
        case .monthly: "매월"
        case .yearly: "매년"
        }
    }

    public init?(_ raw: String) {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "매일", "daily", "every day": self = .daily
        case "매주", "weekly", "every week": self = .weekly
        case "매월", "매달", "monthly", "every month": self = .monthly
        case "매년", "해마다", "yearly", "annually", "every year": self = .yearly
        default: return nil
        }
    }

    private var step: DateComponents {
        switch self {
        case .daily: DateComponents(day: 1)
        case .weekly: DateComponents(day: 7)
        case .monthly: DateComponents(month: 1)
        case .yearly: DateComponents(year: 1)
        }
    }

    public func next(after moment: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: step, to: moment)
    }

    public func next(after day: CalendarDate, calendar: Calendar = .current) -> CalendarDate? {
        guard let midnight = day.startOfDay(calendar: calendar),
              let moved = next(after: midnight, calendar: calendar)
        else { return nil }
        return CalendarDate(moved, calendar: calendar)
    }

    /// `moment` 가 `limit` 을 넘어설 때까지 걸어간다.
    ///
    /// 한 걸음이 아니라 여러 걸음인 이유: 앱을 몇 주 안 켰을 수 있다. 그때
    /// 한 회차만 옮기면 여전히 지난 일정이고, 다음 날 또 한 걸음 — 밀린 만큼
    /// 날이 걸린다. 걸음 수에 상한을 둔 것은 규칙이 잘못돼 제자리를 돌 때
    /// 여기서 영영 안 돌아오는 것을 막기 위한 것뿐이다.
    public func walk(_ moment: Date, past limit: Date, calendar: Calendar = .current) -> Date? {
        guard moment <= limit else { return nil }
        var cursor = moment
        for _ in 0..<Self.maximumSteps {
            guard let moved = next(after: cursor, calendar: calendar), moved > cursor else { return nil }
            cursor = moved
            if cursor > limit { return cursor }
        }
        return nil
    }

    /// 하루 주기로 400년을 걸어도 닿는 수. 실제로는 이만큼 갈 일이 없다.
    static let maximumSteps = 150_000

    /// 사람이 적은 글에서 되풀이하는 낱말을 찾는다.
    ///
    /// 날짜 낱말과 같은 방식이다 (`TimeWords`) — 형식을 배우게 하지 않는다.
    /// 「매주 화요일 8시 분리수거」에서 «매주» 만 떼어 내면 나머지는 이미
    /// 읽을 줄 아는 글이 되고, **요일은 그 나머지가 정해 준다.**
    public static func find(in text: String) -> (recurrence: Recurrence, phrase: String)? {
        for word in searchWords {
            guard let range = text.range(of: word, options: [.caseInsensitive]),
                  let recurrence = Recurrence(word)
            else { continue }
            return (recurrence, String(text[range]))
        }
        return nil
    }

    /// 긴 것부터 본다 — 짧은 것이 긴 것 안에 들어 있으면 안 되기 때문이다.
    private static let searchWords = [
        "해마다", "매일", "매주", "매달", "매월", "매년",
        "every day", "every week", "every month", "every year",
        "daily", "weekly", "monthly", "yearly",
    ]
}
