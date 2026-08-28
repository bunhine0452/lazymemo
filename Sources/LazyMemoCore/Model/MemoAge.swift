import Foundation

/// 메모가 화면에서 얼마나 앞에 나설지 (설계문서 §14 「바램」).
///
/// **디자인 철학의 세 번째 문장 — "오래된 것은 스스로 물러난다" — 의 구현이다.**
/// 게으른 사람은 메모를 지우지도 정리하지도 않는다. 그러면 바탕화면은 결국
/// 낡은 종이로 덮인다. 사용자가 아무것도 하지 않아도 화면이 스스로 정돈되려면,
/// 시간이 지난 것이 조용히 물러나야 한다.
///
/// UI 밖에 두는 이유는 규칙이 눈으로 확인하기 어렵고 경계에서 틀리기 쉬워서다.
public enum MemoAge: Sendable, Hashable, CaseIterable, Comparable {
    /// 오늘 손댔거나, 아직 오지 않은 일정.
    case fresh
    /// 일주일 이내.
    case recent
    /// 한 달 이내.
    case settled
    /// 그보다 오래된 것.
    case faded

    private static let recentDays = 7
    private static let settledDays = 30

    public static func of(
        _ memo: Memo,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MemoAge {
        // 고정한 메모는 바래지 않는다. 사용자가 직접 "이건 계속 앞에 둬" 라고
        // 말한 것이라, 시간이 그 뜻을 덮으면 안 된다.
        if memo.pinned { return .fresh }

        let today = CalendarDate(now, calendar: calendar)

        // 다가오는 일정은 언제 적었든 또렷하다. 앞으로 벌어질 일이기 때문이다.
        if let scheduled = memo.scheduledDate(calendar: calendar), scheduled >= today {
            return .fresh
        }

        let elapsed = calendar.dateComponents([.day], from: memo.updated, to: now).day ?? 0
        switch elapsed {
        case ..<1: return .fresh
        case ..<recentDays: return .recent
        case ..<settledDays: return .settled
        default: return .faded
        }
    }

    /// 화면에 얼마나 드러날지. 1이 온전한 상태다.
    public var presence: Double {
        switch self {
        case .fresh: 1.0
        case .recent: 0.88
        case .settled: 0.72
        case .faded: 0.55
        }
    }
}
