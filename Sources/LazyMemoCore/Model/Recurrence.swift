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

    /// 파일과 MCP 에 적히는 낱말. **바꾸지 않는다** — 이미 적힌 파일이 못 읽게 된다.
    public var label: String {
        switch self {
        case .daily: "매일"
        case .weekly: "매주"
        case .monthly: "매월"
        case .yearly: "매년"
        }
    }

    /// 화면에 적히는 말. 사용자의 말을 따른다.
    public func text(locale: Locale = Words.locale) -> String {
        switch self {
        case .daily: L("매일", locale: locale)
        case .weekly: L("매주", locale: locale)
        case .monthly: L("매월", locale: locale)
        case .yearly: L("매년", locale: locale)
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

    /// `count` 걸음. 달·해 걸음은 짧은 달에서 잘리므로(1월 31일 + 1달 = 2월 28일) 한 걸음씩 쌓지 않고
    /// 처음 날에서 n 걸음을 한 번에 잰다 — 그래야 2월 28일 다음이 3월 28일이 아니라 3월 31일이다.
    private func step(_ count: Int) -> DateComponents {
        switch self {
        case .daily: DateComponents(day: count)
        case .weekly: DateComponents(day: 7 * count)
        case .monthly: DateComponents(month: count)
        case .yearly: DateComponents(year: count)
        }
    }

    /// 걸음이 짧은 달에서 잘릴 수 있는가 — 잘리는 주기만 처음 날(`Memo.anchor`)을 기억한다.
    public var clips: Bool {
        switch self {
        case .daily, .weekly: false
        case .monthly, .yearly: true
        }
    }

    public func next(after moment: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: step(1), to: moment)
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
    ///
    /// 걸음은 **`anchor` 에서** 잰다 — 없으면 `moment` 가 처음이다. 달·해 걸음은 짧은 달에서
    /// 잘려서(1월 31일 → 2월 28일), 잘린 날에서 다시 재면 날이 영영 앞당겨진다(→ 3월 28일).
    /// 처음 날에서 n 걸음으로 재면 2월 28일 다음은 도로 3월 31일이다. 시각은 `moment` 의 것이다 —
    /// 사람이 시각만 고쳤을 수 있고, 그것은 처음 날과 상관없다.
    public func walk(
        _ moment: Date, past limit: Date, anchor: CalendarDate? = nil, calendar: Calendar = .current
    ) -> Date? {
        guard moment <= limit else { return nil }
        let origin = anchor.flatMap { first -> Date? in
            guard let day = first.startOfDay(calendar: calendar) else { return nil }
            let time = calendar.dateComponents([.hour, .minute, .second], from: moment)
            return calendar.date(
                bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day
            )
        } ?? moment
        for count in 1...Self.maximumSteps {
            guard let moved = calendar.date(byAdding: step(count), to: origin) else { return nil }
            if moved > limit { return moved }
        }
        return nil
    }

    /// 이 처음 날이 지금 적힌 날을 설명하는가 — 잘린 걸음이라면 그렇다.
    ///
    /// 「매월 31일」의 처음 날 31일은 2월 28일·3월 31일·4월 30일을 설명하지만 3월 28일은 설명하지
    /// 못한다: 그것은 사람이 옮긴 날이거나, 처음 날을 모르던 판이 잘린 채로 걸어간 것이다. 어느 쪽이든
    /// 그 날이 새 처음이다 (`Tidy.rolled`).
    public func explains(_ anchor: CalendarDate, _ day: CalendarDate, calendar: Calendar = .current) -> Bool {
        switch self {
        case .daily, .weekly:
            return true
        case .monthly:
            return day.day == Self.clampedDay(anchor.day, in: day, calendar: calendar)
        case .yearly:
            return day.month == anchor.month && day.day == Self.clampedDay(anchor.day, in: day, calendar: calendar)
        }
    }

    /// 그 달에 있는 날로 자른 날 — 2월의 31일은 28일.
    private static func clampedDay(_ day: Int, in month: CalendarDate, calendar: Calendar) -> Int {
        guard let start = month.startOfDay(calendar: calendar),
              let days = calendar.range(of: .day, in: .month, for: start)
        else { return day }
        return min(day, days.count)
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
