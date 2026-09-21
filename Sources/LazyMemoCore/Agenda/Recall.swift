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

    // MARK: OS 예약의 이름과 내용 — 앱·공유 시트·인텐트가 **같은 자리**를 찾는다

    /// OS 예약의 id 머리 — `recall.<ulid>`. 「어디서 출발하시나요?」(`RouteAsk.notificationPrefix`)와 갈린다.
    /// 앱 밖(공유 시트)이 같은 이름으로 걸어 두면 앱의 대조가 그것을 **자기 것**으로 알아보고 두 번 걸지 않는다.
    public static let notificationPrefix = "recall."
    public static func notificationID(for id: ULID) -> String { notificationPrefix + id.stringValue }
    /// 알림 `userInfo` 의 열쇠 — 메모 id 와 걸려 있던 시각(초). 누를 때 어느 메모를 열지, 「봤어요」의 이름표가 무엇인지.
    public static let memoKey = "memo"
    public static let dateKey = "date"
    /// 알림 종류의 이름 — 단추 묶음이 다르다 (`ReminderCategory` 의 rawValue 와 같아야 한다).
    public static let recallCategory = "recall"
    public static let departureCategory = "departure"
    /// 다시 보기 알림의 둘째 줄 — 길이 적히지 않았을 때.
    public static var defaultNotificationBody: String { L("다시 볼 시간이에요. 눌러서 메모를 펼치세요.") }

    /// 지운 것·치워 둔 것·보관한 것·끝낸 것·다 체크한 목록은 다시 펼치지 않는다.
    ///
    /// 체크리스트를 다 지운 사람은 그 일을 끝낸 것이다 — 끝난 일의 알림은 방해다.
    /// 일반 글의 완료 여부는 추측하지 않는다 — 사람이 「완료」라 했을 때만이다 (`Memo.done`).
    public static func eligible(_ memo: Memo) -> Bool {
        memo.deleted == nil && !memo.isPutAway && memo.done == nil && !Tidy.isFinishedChecklist(memo.body)
    }

    /// OS 에 걸 예약 하나. `id` 는 메모의 것이라 수정·미루기·삭제가 같은 자리를 찾는다.
    public struct Reservation: Equatable, Sendable, Identifiable {
        public let id: ULID
        public let date: Date
        public let title: String
        /// 알림의 둘째 줄. 가는 길이 적힌 약속이면 「18:09 출발 — 잠실여고후문에서 3314 버스 · 21분」,
        /// 아니면 nil — 알림이 「다시 볼 시간이에요」를 쓴다.
        public let body: String?

        public init(id: ULID, date: Date, title: String, body: String? = nil) {
            self.id = id
            self.date = date
            self.title = title
            self.body = body
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
            return Reservation(id: memo.id, date: date, title: String(memo.title.prefix(180)), body: departureLine(memo))
        }
        .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        .prefix(max(0, limit))
        .map { $0 }
    }

    /// 가는 길이 적힌 약속의 알림 둘째 줄 — 출발 시각과 첫 탈것. 길이 없으면 nil.
    ///
    /// 알림이 오는 때는 다시 볼 시각(`surface`)인데, 길이 적힌 메모는 그것이 출발 10분 전이다
    /// (`RoutePlanner.lead`). 그 순간 사람에게 필요한 것은 「다시 보라」가 아니라 **몇 시에 무엇을
    /// 타는가**다.
    public static func departureLine(_ memo: Memo, calendar: Calendar = .current) -> String? {
        guard let at = memo.at, let route = RouteNote.read(memo.body, day: at, calendar: calendar) else { return nil }
        var parts = ["\(RouteNote.clock(route.depart, calendar: calendar)) 출발"]
        if let ride = route.rides.first {
            switch ride.mode {
            case .bus: parts.append([ride.from.map { "\($0)에서" }, ride.line.map { "\($0) 버스" }].compactMap { $0 }.joined(separator: " "))
            // 「강남역」처럼 「역」이 이미 붙어 있으면 다시 붙이지 않는다.
            case .subway: parts.append([ride.from.map { ($0.hasSuffix("역") ? $0 : $0 + "역") + "에서" }, ride.line].compactMap { $0 }.joined(separator: " "))
            case .taxi: parts.append("택시")
            case .transit: parts.append("대중교통")
            case .walk: break
            }
        }
        let head = parts.filter { !$0.isEmpty }.joined(separator: " — ")
        return "\(head) · \(route.minutes)분"
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
        /// **이 등장의 이름표.** 시각이 있으면 그 시각, 없으면 오늘의 시작. 「봤어요」는
        /// 이것을 적어 두고, 이름표가 같은 동안만 내려놓은 채로 있다 — 시각을 미루면
        /// 다른 이름표라 다시 오르고, 날이 바뀌어도 그렇다.
        public let stamp: Date
        public var id: ULID { memo.id }

        public init(memo: Memo, reason: Reason, moment: Date?, stamp: Date) {
            self.memo = memo
            self.reason = reason
            self.moment = moment
            self.stamp = stamp
        }
    }

    /// 지금 펼쳐 둘 최대 세 장.
    ///
    /// **다가오는 것이 먼저다.** 아침에 지나간 셋이 오후에 곧 올 하나를 밀어내면
    /// 띠는 「지금」이 아니라 「오늘 아침」이다. 그래서 차례는 시각이 정한다 —
    /// 앞으로 올 것은 가까운 순, 그다음 지나간 것은 방금 지난 순, 시각이 없는 것
    /// (날짜만 있는 오늘 일정·고정)은 이유 순에 최근 손댄 순. 같은 자리면 이유
    /// (다시 보기 → 오늘 일정 → 고정), 그래도 같으면 id.
    ///
    /// `seen` 은 「봤어요」로 내려놓은 것 — 메모 id 마다 그때의 `stamp`. 이름표가
    /// 같은 동안만 빠진다. 자정이 지나면 「오늘」이 바뀌므로 부르는 쪽이 시계를 다시 대야 한다.
    public static func nowCards(
        _ memos: [Memo], now: Date = Date(), calendar: Calendar = .current, limit: Int = nowLimit,
        seen: [ULID: Date] = [:]
    ) -> [Card] {
        let today = CalendarDate(now, calendar: calendar)
        let dayStart = calendar.startOfDay(for: now)
        return memos.compactMap { memo -> Card? in
            guard eligible(memo) else { return nil }
            let card: Card
            if let surface = memo.surface, CalendarDate(surface, calendar: calendar) == today {
                card = Card(memo: memo, reason: .revisit, moment: surface, stamp: surface)
            } else if memo.scheduledDate(calendar: calendar) == today {
                card = Card(memo: memo, reason: .today, moment: memo.at, stamp: memo.at ?? dayStart)
            } else if memo.pinned {
                card = Card(memo: memo, reason: .pinned, moment: nil, stamp: dayStart)
            } else {
                return nil
            }
            return seen[memo.id] == card.stamp ? nil : card
        }
        .sorted { left, right in
            let (lb, rb) = (band(left, now: now), band(right, now: now))
            if lb != rb { return lb < rb }
            switch lb {
            case 0:
                // 다가오는 것 — 가까운 순.
                if left.moment != right.moment { return (left.moment ?? .distantFuture) < (right.moment ?? .distantFuture) }
            case 1:
                // 지나간 것 — 방금 지난 순.
                if left.moment != right.moment { return (left.moment ?? .distantPast) > (right.moment ?? .distantPast) }
            default:
                break
            }
            let (lp, rp) = (priority(left.reason), priority(right.reason))
            if lp != rp { return lp < rp }
            if left.memo.updated != right.memo.updated { return left.memo.updated > right.memo.updated }
            return left.id < right.id
        }
        .prefix(max(0, limit))
        .map { $0 }
    }

    // MARK: 놓친 것·오늘·나중에 — 세 장이 전부가 아니다 (인계서 묶음 4 `#unfinished-recall`)

    /// 「지금」의 세 장 곁에 서는 요약 — 놓친 것·오늘·나중에의 수와 그 목록. 세 장이 전부라고 오해하지 않게 하고,
    /// 놓친 미처리는 날이 바뀌어도 여기서 찾는다. 푸시는 없다 — 화면의 조용한 요약이다.
    public struct Summary: Sendable, Equatable {
        /// 지난 날에 다시 보기로 했거나 시각이 적혀 있었는데 끝내지도 보지도 않은 것, 그리고 마감이 지난 칸 남은 목록.
        /// 방금 지난 것이 먼저.
        public let missed: [Memo]
        /// 오늘 오를 것 전부 — 「지금」이 세 장으로 줄이기 전의 수.
        public let today: [Memo]
        /// 앞으로 올 것 — 내일부터.
        public let later: [Memo]

        public init(missed: [Memo], today: [Memo], later: [Memo]) {
            self.missed = missed
            self.today = today
            self.later = later
        }

        public var isEmpty: Bool { missed.isEmpty && today.isEmpty && later.isEmpty }
    }

    public static func summary(
        _ memos: [Memo], now: Date = Date(), calendar: Calendar = .current, seen: [ULID: Date] = [:]
    ) -> Summary {
        let today = CalendarDate(now, calendar: calendar)
        let dayStart = calendar.startOfDay(for: now)
        let todays = nowCards(memos, now: now, calendar: calendar, limit: Int.max, seen: seen).map(\.memo)
        var missed: [(Memo, Date)] = []
        var later: [Memo] = []
        for memo in memos where eligible(memo) {
            if let stamp = missedStamp(memo, dayStart: dayStart, today: today, calendar: calendar) {
                if seen[memo.id] != stamp { missed.append((memo, stamp)) }
                continue
            }
            let revisit = memo.surface.map { CalendarDate($0, calendar: calendar) }
            let event = memo.scheduledDate(calendar: calendar)
            if let day = [revisit, event].compactMap({ $0 }).max(), day > today { later.append(memo) }
        }
        return Summary(
            missed: missed.sorted { $0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 > $1.1 }.map(\.0),
            today: todays,
            later: later.sorted { ($0.surfacesAt ?? $0.due?.startOfDay(calendar: calendar) ?? .distantFuture)
                < ($1.surfacesAt ?? $1.due?.startOfDay(calendar: calendar) ?? .distantFuture) }
        )
    }

    /// 이 메모가 놓친 것이면 그 등장의 이름표 (`Card.stamp` 와 같은 값 — 「봤어요」가 이것을 적는다). 아니면 `nil`.
    ///
    /// 놓친 것은 둘이다: 지난 날의 다시 볼 시각·일정 시각(그날 안 봤고 안 끝냈다), 그리고 마감이 지난 칸 남은 목록.
    /// 미래에 다시 보기로 한 지난 일정은 놓친 것이 아니다 — 그날 다시 오른다.
    private static func missedStamp(_ memo: Memo, dayStart: Date, today: CalendarDate, calendar: Calendar) -> Date? {
        if let surface = memo.surface {
            return surface < dayStart ? surface : nil
        }
        if let at = memo.at { return at < dayStart ? at : nil }
        if let due = memo.due, due < today, MarkdownScanner.checkboxes(in: memo.body).contains(false) {
            return due.startOfDay(calendar: calendar)
        }
        return nil
    }

    /// 0 다가오는 것 · 1 지나간 것 · 2 시각이 없는 것.
    private static func band(_ card: Card, now: Date) -> Int {
        guard let moment = card.moment else { return 2 }
        return moment > now ? 0 : 1
    }

    private static func priority(_ reason: Reason) -> Int {
        Reason.allCases.firstIndex(of: reason) ?? Reason.allCases.count
    }
}
