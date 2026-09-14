import Foundation

/// 목록에서 메모를 알아보게 하는 유일한 곁글 (철학 2 — 시간이 유일한 구조다).
///
/// 제목만 있는 목록에서는 "빈 메모" 가 세 줄 늘어서고 어느 것이 어느 것인지
/// 알 수 없다. 폴더도 태그도 유지하지 않는 사람이 받아들이는 단서는 "언제" 뿐이라
/// 그 한 조각만 오른쪽에 붙인다. **짧아야 한다** — 길면 제목 자리를 먹는다.
///
/// 맥의 메뉴 목록에서 시작해 폰의 목록까지 같은 낱말을 쓴다 — 「오늘 15:00」이
/// 한쪽에서는 「오늘 오후 3시」로 보이면 사람은 두 앱을 쓰는 것이 된다.
public enum MemoTimeLabel {
    public static func text(
        for memo: Memo, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        if let at = memo.at {
            let day = relativeDay(CalendarDate(at, calendar: calendar), now: now, calendar: calendar, locale: locale)
            return "\(day) \(clock(at, calendar: calendar))"
        }
        if let due = memo.due {
            return relativeDay(due, now: now, calendar: calendar, locale: locale)
        }
        return elapsed(memo.updated, now: now, calendar: calendar, locale: locale)
    }

    /// 앞으로 올 날. 일정이 적힌 메모에 쓴다.
    private static func relativeDay(
        _ target: CalendarDate, now: Date, calendar: Calendar, locale: Locale
    ) -> String {
        guard let offset = dayOffset(target, from: now, calendar: calendar) else {
            return short(target)
        }
        switch offset {
        case 0: return L("오늘", locale: locale)
        case 1: return L("내일", locale: locale)
        case -1: return L("어제", locale: locale)
        case 2...6: return L("\(offset)일 뒤", locale: locale)
        case -6 ... -2: return L("\(-offset)일 전", locale: locale)
        default: return short(target)
        }
    }

    /// 지나간 날. 일정이 없는 메모는 마지막으로 손댄 때를 보인다. 휴지통은
    /// 「N일 전 지움」에 같은 낱말을 쓴다.
    public static func elapsed(
        _ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        let target = CalendarDate(date, calendar: calendar)
        guard let offset = dayOffset(target, from: now, calendar: calendar) else {
            return short(target)
        }
        switch offset {
        case 0: return L("오늘", locale: locale)
        case -1: return L("어제", locale: locale)
        case -6 ... -2: return L("\(-offset)일 전", locale: locale)
        default: return short(target)
        }
    }

    private static func dayOffset(
        _ target: CalendarDate, from now: Date, calendar: Calendar
    ) -> Int? {
        guard let today = CalendarDate(now, calendar: calendar).startOfDay(calendar: calendar),
              let day = target.startOfDay(calendar: calendar)
        else { return nil }
        return calendar.dateComponents([.day], from: today, to: day).day
    }

    private static func short(_ date: CalendarDate) -> String {
        "\(date.month)/\(date.day)"
    }

    /// 24시로 적는다. "오후 3:00" 은 목록의 오른쪽 끝에 두기에 너무 길다.
    private static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
