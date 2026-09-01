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

    public static func lead(surface: Date, event: Date) -> String? {
        let seconds = event.timeIntervalSince(surface)
        guard abs(seconds) >= grain else { return nil }

        let tail = seconds > 0 ? "전" : "뒤"
        let span = Int(abs(seconds).rounded())

        if span < 3600 {
            return "\(span / 60)분 \(tail)"
        }
        if span < 86_400 {
            let hours = span / 3600
            let minutes = (span % 3600) / 60
            return minutes == 0 ? "\(hours)시간 \(tail)" : "\(hours)시간 \(minutes)분 \(tail)"
        }
        return "\(span / 86_400)일 \(tail)"
    }
}
