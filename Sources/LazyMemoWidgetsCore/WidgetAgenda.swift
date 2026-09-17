import Foundation
import LazyMemoCore

/// 위젯이 보여 주는 것과 그것이 바뀌는 순간 — WidgetKit 없이 도는 판단.
///
/// **앱과 같은 답을 낸다.** 「지금」 위젯은 폰의 띠(`Recall.nowCards`)를 그대로 옮긴 것이고,
/// 「다음 약속」은 알림이 거는 예약(`Recall.reservations`)과 같은 메모를 본다 — 위젯이
/// 따로 고르기 시작하면 홈 화면과 앱이 다른 말을 한다.
///
/// 위젯은 스스로 시계를 못 본다. 시간표(`moments`)에 「이때 화면이 바뀐다」를 미리 적어
/// 두면 시스템이 그 순간 다음 장면으로 넘긴다 — 시각이 지나 「지남」이 되는 순간, 자정에
/// 「오늘」이 바뀌는 순간.
public enum WidgetAgenda {
    // MARK: 「지금」

    /// 폰의 띠 그대로 — 최대 세 장, 다가오는 것부터. `seen` 은 「봤어요」로 내려놓은 것 (`NowSeen`).
    public static func nowCards(
        _ memos: [Memo], now: Date, calendar: Calendar = .current, seen: [ULID: Date] = [:]
    ) -> [Recall.Card] {
        Recall.nowCards(memos, now: now, calendar: calendar, seen: seen)
    }

    /// 오늘 뒤에 올 일정 하나 — 큰 위젯의 아래 절 「다음」에 서는 줄.
    public struct Upcoming: Equatable, Sendable, Identifiable {
        public let memo: Memo
        /// 달력이 놓는 날.
        public let day: CalendarDate
        /// 시각까지 적힌 약속이면 그 시각.
        public let at: Date?
        public var id: ULID { memo.id }

        public init(memo: Memo, day: CalendarDate, at: Date?) {
            self.memo = memo
            self.day = day
            self.at = at
        }
    }

    /// 오늘 **뒤**의 일정, 가까운 날부터 `limit` 줄. 오늘 것은 「지금」이 맡으므로 여기 없다 —
    /// 달력 위젯처럼 오늘부터 세고 싶으면 `includingToday`.
    ///
    /// 같은 날이면 시각 순(날짜만 있는 것이 먼저), 그래도 같으면 id — 두 기기가 같은 차례를 얻는다.
    public static func upcoming(
        _ memos: [Memo], now: Date, calendar: Calendar = .current, limit: Int = 4, includingToday: Bool = false
    ) -> [Upcoming] {
        let today = CalendarDate(now, calendar: calendar)
        return memos.compactMap { memo -> Upcoming? in
            guard Recall.eligible(memo), let day = memo.scheduledDate(calendar: calendar),
                  includingToday ? day >= today : day > today
            else { return nil }
            return Upcoming(memo: memo, day: day, at: memo.at)
        }
        .sorted { left, right in
            if left.day != right.day { return left.day < right.day }
            if left.at != right.at { return (left.at ?? .distantPast) < (right.at ?? .distantPast) }
            return left.id < right.id
        }
        .prefix(max(0, limit))
        .map { $0 }
    }

    // MARK: 달력

    /// 달 격자의 점 — 날짜별 일정 수. 폰 달력의 `marks`(`CalendarView`)와 같은 셈이다.
    ///
    /// 여기서는 `Recall.eligible` 을 **쓰지 않는다.** 달력은 물러난(`tidied`) 종이도 그대로
    /// 보여 주는 자리라(README 「끝난 것은 스스로 물러난다」) 「지금」과 기준이 다르다 —
    /// 휴지통에 든 것만 뺀다 (`WidgetVault` 는 애초에 휴지통을 읽지 않지만, 견본과 시험은 든다).
    public static func monthMarks(
        _ memos: [Memo], in grid: MonthGrid, calendar: Calendar = .current
    ) -> [CalendarDate: Int] {
        guard let range = grid.range else { return [:] }
        var counts: [CalendarDate: Int] = [:]
        for memo in memos where memo.deleted == nil {
            guard let day = memo.scheduledDate(calendar: calendar), range.contains(day) else { continue }
            counts[day, default: 0] += 1
        }
        return counts
    }

    /// 달력이 바뀌는 순간들 — `now` 와 그 뒤의 자정 `count` 개. 자정에 「오늘」이 옮겨 가고,
    /// 달이 넘어가면 격자가 통째로 바뀐다. 첫 원소는 늘 `now` 다 (`moments` 와 같은 꼴).
    ///
    /// 24시간 더하기가 아니라 `Calendar` 에게 다음 자정을 묻는다 — 서머타임 날은 하루가
    /// 23·25시간이다 (`CalendarDate.nextMidnight`).
    public static func dayChanges(now: Date, calendar: Calendar = .current, count: Int = 3) -> [Date] {
        var result = [now]
        var cursor = now
        for _ in 0..<max(0, count) {
            guard let midnight = CalendarDate.nextMidnight(after: cursor, calendar: calendar) else { break }
            result.append(midnight)
            cursor = midnight
        }
        return result
    }

    // MARK: 다음 약속

    /// 가는 길이 적힌 약속의 출발 — 「18:12 출발 · 2호선」의 재료.
    public struct Departure: Equatable, Sendable {
        public let at: Date
        /// 첫 탈것 — 「2호선」·「3314 버스」·「택시」. 걷기만 있는 길이면 nil.
        public let ride: String?

        public init(at: Date, ride: String?) {
            self.at = at
            self.ride = ride
        }
    }

    public struct NextAppointment: Equatable, Sendable {
        public let memo: Memo
        public let at: Date
        public let departure: Departure?

        public init(memo: Memo, at: Date, departure: Departure?) {
            self.memo = memo
            self.at = at
            self.departure = departure
        }
    }

    /// 시각이 적힌 약속 중 앞으로 올 가장 가까운 것. 날짜만 있는 것은 약속이 아니라 여기 없다 —
    /// 시각을 지어내지 않는다 (`Recall`).
    public static func next(_ memos: [Memo], now: Date, calendar: Calendar = .current) -> NextAppointment? {
        let coming = memos
            .filter { Recall.eligible($0) && ($0.at.map { $0 > now } ?? false) }
            .sorted { $0.at == $1.at ? $0.id < $1.id : $0.at! < $1.at! }
        guard let memo = coming.first, let at = memo.at else { return nil }
        return NextAppointment(memo: memo, at: at, departure: departure(memo, calendar: calendar))
    }

    /// 본문의 「가는 길」 절에서 출발 시각과 첫 탈것을 읽는다. 길이 없으면 nil.
    public static func departure(_ memo: Memo, calendar: Calendar = .current) -> Departure? {
        guard let at = memo.at, let route = RouteNote.read(memo.body, day: at, calendar: calendar) else { return nil }
        let ride: String? = route.rides.first.map { leg in
            switch leg.mode {
            case .bus: return [leg.line, "버스"].compactMap { $0 }.joined(separator: " ")
            case .subway: return leg.line ?? "지하철"
            case .taxi: return "택시"
            case .transit: return "대중교통"
            case .walk: return "걷기"
            }
        }
        return Departure(at: route.depart, ride: ride)
    }

    // MARK: 시간표

    /// 화면이 바뀌는 순간들 — `now` 뒤로 `limit` 개, `horizon` 안에서.
    ///
    /// 자정(「오늘」이 바뀐다)과 각 메모의 시각(`surface`·`at` — 다가오던 것이 「지남」이 되고,
    /// 다음 약속이 그다음으로 넘어간다). 첫 원소는 늘 `now` 다 — 지금 장면.
    public static func moments(
        _ memos: [Memo], now: Date, calendar: Calendar = .current,
        limit: Int = 12, horizon: TimeInterval = 36 * 60 * 60
    ) -> [Date] {
        var changes: Set<Date> = []
        if let midnight = calendar.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime
        ) {
            changes.insert(midnight)
        }
        for memo in memos where Recall.eligible(memo) {
            for date in [memo.surface, memo.at].compactMap({ $0 }) where date > now && date.timeIntervalSince(now) <= horizon {
                changes.insert(date)
            }
        }
        return [now] + changes.filter { $0 > now }.sorted().prefix(max(0, limit - 1))
    }
}
