import Foundation

/// 메모가 달력 위에서 차지하는 자리 — `due` 와 `at` 을 한 덩어리로 다룬다.
///
/// 두 필드를 따로 만지면 옮기기가 조용히 어긋난다. "31일로 옮겨" 라고 했는데
/// `at` 만 바꾸고 `due` 를 두면 한 메모가 달력 두 칸에 서고, 반대로 `due` 만
/// 바꾸면 시각이 사라진다. **옮기기는 언제나 자리 전체를 통째로 쓴다.**
///
/// 되돌리기가 한 줄로 끝나는 것도 이 덩어리 덕분이다 — 옮기기 전의 `Schedule`
/// 을 들고 있다가 그대로 되쓰면 된다.
public struct Schedule: Sendable, Equatable {
    /// 날짜만 — 마감·목표.
    public var due: CalendarDate?
    /// 시각까지 — 약속.
    public var at: Date?

    public init(due: CalendarDate? = nil, at: Date? = nil) {
        self.due = due
        self.at = at?.truncatingSubsecond
    }

    /// 메모가 지금 있는 자리.
    public init(_ memo: Memo) {
        self.init(due: memo.due, at: memo.at)
    }

    public var isEmpty: Bool { due == nil && at == nil }

    /// 달력이 이 일정을 놓는 칸. `at` 이 있으면 그 날, 없으면 `due`.
    public func day(calendar: Calendar = .current) -> CalendarDate? {
        if let at { return CalendarDate(at, calendar: calendar) }
        return due
    }

    /// 하루 중 몇 시인가. 시각이 없으면 `nil`.
    public func timeOfDay(calendar: Calendar = .current) -> DateComponents? {
        guard let at else { return nil }
        return calendar.dateComponents([.hour, .minute, .second], from: at)
    }

    /// 다른 날로 옮긴 자리.
    ///
    /// **시:분은 지키고 날짜만 바꾼다.** "3시 치과" 를 내일로 미루면 내일 3시여야
    /// 한다. 채워져 있던 칸만 따라 움직이므로, 시각 없는 마감은 시각을 얻지
    /// 않고 약속은 시각을 잃지 않는다.
    ///
    /// 아무 날짜도 없던 메모를 옮기면 마감이 된다 — 달력 위에 놓았다는 것
    /// 자체가 "그 날" 이라는 뜻이고, 사용자가 시각을 말한 적은 없기 때문이다.
    public func moved(to day: CalendarDate, calendar: Calendar = .current) -> Schedule {
        guard !isEmpty else { return Schedule(due: day) }

        var moved = Schedule()
        if due != nil { moved.due = day }
        if let time = timeOfDay(calendar: calendar) {
            moved.at = calendar.date(from: DateComponents(
                year: day.year, month: day.month, day: day.day,
                hour: time.hour, minute: time.minute, second: time.second
            ))
        }
        return moved
    }

    /// 하루 미룬 자리 — 게으른 사람이 달력에 가장 자주 하는 일.
    ///
    /// 그냥 "+1일" 이 아니다. 이미 지나 버린 일정을 하루 미루면 **여전히 과거**라
    /// 아무것도 달라지지 않는다. 미루기는 언제나 앞으로 가야 하므로 내일보다
    /// 이르게 떨어지지 않는다.
    public func postponed(
        notBefore today: CalendarDate,
        calendar: Calendar = .current
    ) -> Schedule {
        let base = day(calendar: calendar) ?? today
        let next = base.adding(days: 1, calendar: calendar)
        let tomorrow = today.adding(days: 1, calendar: calendar)
        return moved(to: max(next, tomorrow), calendar: calendar)
    }
}

// MARK: - 고른 날에 한 줄 적기

/// 달력에서 날을 고르고 한 줄 적었을 때, 그것이 어떤 일정이 되는가.
///
/// 규칙은 하나다 — **날짜를 적지 않으면 고른 날에 붙고, 적으면 적은 쪽이 이긴다.**
/// 30일 칸을 열어 두고 "내일 3시" 라고 적었다면 사용자는 내일을 말한 것이다.
/// 고른 날을 우선하면 사용자가 방금 친 글자를 앱이 무시하는 셈이 된다.
public enum QuickSchedule {
    public struct Draft: Sendable, Equatable {
        public var schedule: Schedule
        /// 날짜 조각을 덜어낸 본문. 인식한 말은 칩이 대신 말하므로 남길 이유가 없다.
        public var body: String
    }

    public static func make(
        from text: String,
        on day: CalendarDate,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Draft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Draft(schedule: Schedule(due: day), body: "")
        }

        if let parsed = NaturalDateParser.parse(trimmed, now: now, calendar: calendar) {
            let body = NaturalDateParser.strip(parsed.phrases, from: trimmed)

            // ① 사용자가 날짜를 직접 말했다 — 그대로 따른다.
            if parsed.namesDay {
                return Draft(schedule: Schedule(due: parsed.due, at: parsed.at), body: body)
            }

            // ② 시각만 말했다 ("오후 3시 치과"). 파서는 다음에 오는 그 시각으로
            //    읽지만, 여기서는 사용자가 **날을 이미 골라 놓았다.** 시:분만
            //    떼어 고른 날에 옮겨 심는다.
            if let at = parsed.at {
                return Draft(
                    schedule: Schedule(at: at).moved(to: day, calendar: calendar), body: body
                )
            }
        }

        // ③ 아무 말도 없다 — 고른 날의 마감이다.
        return Draft(schedule: Schedule(due: day), body: trimmed)
    }
}
