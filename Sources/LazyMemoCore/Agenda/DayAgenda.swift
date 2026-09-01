import Foundation

/// 달력의 하루에 서는 한 줄. 우리 종이이거나, 남의 일정이다.
public enum AgendaRow: Sendable, Equatable, Identifiable {
    case memo(Memo)
    case foreign(ForeignEvent)

    public var id: String {
        switch self {
        case .memo(let memo): "memo:" + memo.id.stringValue
        case .foreign(let event): "event:" + event.id
        }
    }

    public var title: String {
        switch self {
        case .memo(let memo): memo.title
        case .foreign(let event): event.title
        }
    }

    /// 시각이 있는 줄인가. 종일 일정과 날짜만 있는 메모는 `nil` 이다.
    public var moment: Date? {
        switch self {
        case .memo(let memo): memo.at
        case .foreign(let event): event.isAllDay ? nil : event.start
        }
    }

    /// 우리 것인가. 남의 일정에는 조작을 붙이지 않는다.
    public var isOurs: Bool {
        if case .memo = self { return true }
        return false
    }
}

public enum DayAgenda {
    /// 하루의 줄을 한 줄기로 세운다.
    ///
    /// **시각이 있는 것부터, 그 다음 최근에 손댄 순.** 이 앱이 이미 쓰던 규칙을
    /// 그대로 쓴다 (`CalendarModel.sortWithinDay`) — 남의 일정이 들어왔다고
    /// 하루를 읽는 순서가 달라지면, 캘린더 권한을 준 날부터 화면이 낯설어진다.
    ///
    /// 같은 시각이면 **우리 것이 먼저**다. 그 줄에만 조작이 붙으므로, 손이
    /// 가는 것이 위에 있는 편이 낫다.
    public static func rows(memos: [Memo], events: [ForeignEvent]) -> [AgendaRow] {
        let all = memos.map(AgendaRow.memo) + events.map(AgendaRow.foreign)

        return all.sorted { left, right in
            switch (left.moment, right.moment) {
            case (let l?, let r?):
                if l != r { return l < r }
                return left.isOurs && !right.isOurs
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil):
                if left.isOurs != right.isOurs { return left.isOurs }
                return untimedOrder(left) > untimedOrder(right)
            }
        }
    }

    /// 시각 없는 줄끼리의 순서. 메모는 최근에 손댄 것부터.
    private static func untimedOrder(_ row: AgendaRow) -> Date {
        if case .memo(let memo) = row { return memo.updated }
        return .distantPast
    }
}
