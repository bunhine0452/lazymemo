import Foundation

/// 다시 보기 — 「대충 적어두세요. 필요할 때 다시 펼쳐드릴게요」의 규칙.
///
/// 시스템 알림(`ReminderCenter`)과 폰의 「지금」 띠가 **같은 답**을 보도록 대상과
/// 차례를 여기 한 곳에 둔다. 보는 시각은 `Memo.surfacesAt` 하나다 — 따로 정한
/// 다시 볼 시각(`surface`)이 있으면 그것, 없으면 일정 시각(`at`). `DueClock` 이
/// 종이를 꺼내는 규칙과 같아서, 맥의 종이가 나오는 순간과 폰의 알림이 울리는
/// 순간이 어긋나지 않는다.
///
/// **날짜만 있는 메모에는 시각을 지어내지 않는다.** 「내일 치과」에 아침 아홉 시
/// 알림을 만들면 그것은 사람이 정한 시각이 아니다. 날짜만 있는 것은 달력과
/// 「지금」 띠가 보여 주고, 알림은 시각이 적힌 것만 건다.
public enum Recall {
    /// 한 기기가 OS 에 걸어 두는 예약 수. iOS 는 앱마다 64개까지만 받는다 — 그 안에서
    /// 가까운 것부터 채우고, 지나간 자리는 앱이 다시 읽을 때 뒤의 것이 메운다.
    public static let reservationLimit = 60

    /// 「지금」 띠에 올리는 수. 셋을 넘으면 띠가 아니라 또 하나의 목록이다.
    public static let nowLimit = 3

    /// 지운 것·치워 둔 것·다 체크한 목록은 다시 펼치지 않는다.
    ///
    /// 체크리스트를 다 지운 사람은 그 일을 끝낸 것이다 — 끝난 일의 알림은 방해다.
    /// 일반 글의 완료 여부는 추측하지 않는다.
    public static func eligible(_ memo: Memo) -> Bool {
        memo.deleted == nil && memo.tidied == nil && !Tidy.isFinishedChecklist(memo.body)
    }

    /// OS 에 걸 예약 하나. `id` 는 메모의 것이라 수정·미루기·삭제가 같은 자리를 찾는다.
    public struct Reservation: Equatable, Sendable, Identifiable {
        public let id: ULID
        public let date: Date
        public let title: String

        public init(id: ULID, date: Date, title: String) {
            self.id = id
            self.date = date
            self.title = title
        }
    }

    /// 앞으로 올 시각만, 가까운 것부터 `limit` 장.
    ///
    /// 같은 시각이면 id 순 — 두 기기가 같은 파일을 보면 같은 차례를 얻는다.
    public static func reservations(
        _ memos: [Memo], now: Date = Date(), limit: Int = reservationLimit
    ) -> [Reservation] {
        memos.compactMap { memo -> Reservation? in
            guard eligible(memo), let date = memo.surfacesAt, date > now else { return nil }
            return Reservation(id: memo.id, date: date, title: String(memo.title.prefix(180)))
        }
        .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        .prefix(max(0, limit))
        .map { $0 }
    }

    /// 「지금」 띠에 오른 이유. 이 차례가 곧 띠의 차례다.
    public enum Reason: Sendable, Equatable, CaseIterable {
        /// 오늘 다시 보기로 한 메모.
        case revisit
        /// 오늘 일정 — 시각이 있든 날짜만 있든.
        case today
        /// 고정한 메모.
        case pinned
    }

    public struct Card: Identifiable, Sendable, Equatable {
        public let memo: Memo
        public let reason: Reason
        /// 이유에 붙는 시각 — 다시 볼 시각이거나 일정 시각. 날짜만 있는 일정과 고정에는 없다.
        public let moment: Date?
        public var id: ULID { memo.id }

        public init(memo: Memo, reason: Reason, moment: Date?) {
            self.memo = memo
            self.reason = reason
            self.moment = moment
        }
    }

    /// 지금 펼쳐 둘 최대 세 장 — 오늘 다시 볼 것 → 오늘 일정 → 고정.
    ///
    /// 같은 이유 안에서는 시각이 가까운 것, 시각이 없으면 최근에 손댄 것이 먼저다.
    /// 자정이 지나면 「오늘」이 바뀌므로 부르는 쪽이 시계를 다시 대야 한다.
    public static func nowCards(
        _ memos: [Memo], now: Date = Date(), calendar: Calendar = .current, limit: Int = nowLimit
    ) -> [Card] {
        let today = CalendarDate(now, calendar: calendar)
        return memos.compactMap { memo -> Card? in
            guard eligible(memo) else { return nil }
            if let surface = memo.surface, CalendarDate(surface, calendar: calendar) == today {
                return Card(memo: memo, reason: .revisit, moment: surface)
            }
            if memo.scheduledDate(calendar: calendar) == today {
                return Card(memo: memo, reason: .today, moment: memo.at)
            }
            if memo.pinned { return Card(memo: memo, reason: .pinned, moment: nil) }
            return nil
        }
        .sorted { left, right in
            let (lp, rp) = (priority(left.reason), priority(right.reason))
            if lp != rp { return lp < rp }
            let (lm, rm) = (left.moment ?? .distantFuture, right.moment ?? .distantFuture)
            if lm != rm { return lm < rm }
            if left.memo.updated != right.memo.updated { return left.memo.updated > right.memo.updated }
            return left.id < right.id
        }
        .prefix(max(0, limit))
        .map { $0 }
    }

    private static func priority(_ reason: Reason) -> Int {
        Reason.allCases.firstIndex(of: reason) ?? Reason.allCases.count
    }
}
