import Foundation

/// 아침 브리핑이 오는 시각 (`{#claude-morning-brief}`).
///
/// **자정이 아니라 아침이다.** `DayClock` 은 하루가 바뀌는 순간에 돌지만,
/// 자정에 놓인 종이는 아무도 안 본 채 아침을 맞는다 — 그리고 이 앱에서
/// 아무도 안 본 종이는 곧 낡은 종이다 (철학 3).
public enum BriefClock {
    /// 여덟 시. 사람이 책상에 앉기 전에 이미 놓여 있어야 «놓고 간 것» 이다.
    public static let hour = 8

    /// `moment` 다음에 오는 브리핑 시각.
    public static func next(after moment: Date, calendar: Calendar = .current) -> Date? {
        guard let today = calendar.date(
            bySettingHour: hour, minute: 0, second: 0, of: moment
        ) else { return nil }
        if today > moment { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }
}
