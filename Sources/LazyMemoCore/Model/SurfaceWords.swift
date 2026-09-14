import Foundation

/// 「나올 때」를 일정 옆에 적는 짧은 말.
///
/// 두 시각을 두 칩으로 나누어 놓으면 **무엇이 일정이고 무엇이 알림인지 매번
/// 읽어야 한다.** 종이의 꼬리는 이 앱에서 첫 줄 다음으로 비싼 줄이라(§14.10)
/// 거기에 조각을 하나 더 세울 여유가 없기도 하다. 그래서 한 조각으로 붙인다 —
/// `오후 3:00 · 30분 전`.
///
/// 「전」이 기본이고 「뒤」도 말할 수 있게 둔 이유는, 사람이 늘 미리 보고 싶어
/// 하는 것은 아니기 때문이다 — 회의가 끝날 즈음 꺼내고 싶은 종이도 있다.
public enum SurfaceWords {
    /// 이보다 가까우면 같은 시각으로 친다. 「1분 전」은 알려 주는 값이 없다.
    static let grain: TimeInterval = 60

    public static func lead(surface: Date, event: Date, locale: Locale = .current) -> String? {
        let seconds = event.timeIntervalSince(surface)
        guard abs(seconds) >= grain else { return nil }

        let before = seconds > 0
        let span = Int(abs(seconds).rounded())

        // 「전」·「뒤」를 꼬리로 이어 붙이지 않는다 — 말마다 앞뒤가 달라 문장째 표에 있어야 한다.
        if span < 3600 {
            let minutes = span / 60
            return before ? L("\(minutes)분 전", locale: locale) : L("\(minutes)분 뒤", locale: locale)
        }
        if span < 86_400 {
            let hours = span / 3600
            let minutes = (span % 3600) / 60
            if minutes == 0 {
                return before ? L("\(hours)시간 전", locale: locale) : L("\(hours)시간 뒤", locale: locale)
            }
            return before
                ? L("\(hours)시간 \(minutes)분 전", locale: locale)
                : L("\(hours)시간 \(minutes)분 뒤", locale: locale)
        }
        // 「3일 전」은 목록의 「3일 전(에 손댔다)」과 한국어로는 같은 말이지만 영어로는
        // before/ago 로 갈린다 — 열쇠를 달리 두고 ko.lproj 가 같은 한국어로 되돌린다.
        let days = span / 86_400
        return before ? L("나올 때 — \(days)일 전", locale: locale) : L("나올 때 — \(days)일 뒤", locale: locale)
    }
}
