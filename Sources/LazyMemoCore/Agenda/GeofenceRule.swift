import Foundation

/// **어느 자리를 지켜볼 것인가** (`{#geofence-surface}`).
///
/// 규칙을 뷰가 아니라 여기 두는 이유는 `Tidy` 와 같다 — 무엇을 언제 지켜보는지는
/// 화면의 사정이 아니라 데이터의 규칙이고, **위치를 다루는 규칙은 특히
/// 눈에 보이지 않는 곳에서 조용히 넓어지기 쉽다.**
///
/// ## 좌표가 있는 메모만
///
/// `@강남역` 처럼 이름만 적힌 장소는 지켜보지 않는다. 지켜보려면 이름을 좌표로
/// 바꿔야 하고 그건 **당신이 적어 둔 장소 이름을 전부 애플에 보내는 일**이다 —
/// 한 번도 안 켠 사람의 메모까지. 좌표는 `⌥⌘L`(지금 여기)과 아이폰 단축어가
/// 만들어 주고, 그 둘은 사람이 직접 누른 것이다.
///
/// ## 스무 개까지
///
/// CoreLocation 이 앱 하나에 허용하는 수다. 넘치면 **몇 장이 빠졌는지 세어
/// 둔다** — 조용히 자르면 「거기 갔는데 안 떴다」가 남고, 그건 이 기능을
/// 못 믿게 만드는 가장 빠른 길이다.
public enum GeofenceRule {
    /// CoreLocation 이 앱 하나에 허용하는 구역 수.
    public static let limit = 20
    /// 「도착했다」로 치는 반경(미터). 도시에서 가게 한 곳쯤 되는 크기다.
    public static let radius: Double = 150

    public struct Selection: Sendable, Equatable {
        public var watched: [Memo]
        /// 상한에 걸려 빠진 수. **0이 아니면 사람에게 말한다.**
        public var dropped: Int

        public init(watched: [Memo], dropped: Int) {
            self.watched = watched
            self.dropped = dropped
        }
    }

    public static func select(
        _ memos: [Memo], now: Date = Date(), calendar: Calendar = .current
    ) -> Selection {
        let eligible = memos
            .filter { watchable($0, now: now, calendar: calendar) }
            .sorted { left, right in
                if left.pinned != right.pinned { return left.pinned }
                return left.updated > right.updated
            }

        return Selection(
            watched: Array(eligible.prefix(limit)),
            dropped: max(0, eligible.count - limit)
        )
    }

    static func watchable(_ memo: Memo, now: Date, calendar: Calendar) -> Bool {
        guard memo.geo != nil, memo.deleted == nil, memo.tidied == nil else { return false }
        // 다 한 목록은 갈 일이 없다.
        guard !Tidy.isFinishedChecklist(memo.body) else { return false }
        // 지난 일정도 갈 일이 없다 — 되풀이하는 것은 다음 회차를 가리키므로 남는다.
        if let day = memo.scheduledDate(calendar: calendar),
           let ended = day.adding(days: 1, calendar: calendar).startOfDay(calendar: calendar),
           now >= ended {
            return false
        }
        return true
    }
}
