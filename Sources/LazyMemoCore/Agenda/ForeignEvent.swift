import Foundation

/// 시스템 캘린더에서 빌려 온 일정 한 줄.
///
/// **우리 것이 아니다.** 이 타입에는 고칠 수 있는 것이 하나도 없고, 이것을
/// 만들어 주는 `CalendarFeed` 에도 읽는 함수 하나뿐이다 — D6 이 하드 삭제
/// 함수를 아예 안 만든 것과 같은 배선이다. 규칙으로 «건드리지 말자» 고 적어
/// 두면 언젠가 한쪽이 어긴다.
public struct ForeignEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    /// 시작. 종일 일정이면 그 날 0시다.
    public let start: Date
    public let isAllDay: Bool
    /// 어느 캘린더에서 왔는가 (「직장」, 「가족」). 없을 수도 있다.
    public let calendarName: String?

    public init(
        id: String, title: String, start: Date, isAllDay: Bool, calendarName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.isAllDay = isAllDay
        self.calendarName = calendarName
    }

    public func day(calendar: Calendar = .current) -> CalendarDate {
        CalendarDate(start, calendar: calendar)
    }
}

/// 남의 일정을 **읽기만** 하는 문.
///
/// 쓰는 함수를 두지 않는다. 이 앱의 정본은 마크다운 파일이고(D4), 시스템
/// 캘린더는 **곁에 놓고 보는 것**이지 우리가 관리하는 것이 아니다. 양쪽에
/// 쓰기 시작하면 어느 쪽이 정본인지가 매일 흔들린다.
public protocol CalendarFeed: Sendable {
    func events(from: CalendarDate, to: CalendarDate) async -> [ForeignEvent]
}

/// 아무것도 돌려주지 않는 문. 권한이 없거나 사용자가 껐을 때 이것이 선다 —
/// 갈래를 뷰에 두지 않으려고 «없음» 도 하나의 문으로 만든다.
public struct EmptyCalendarFeed: CalendarFeed {
    public init() {}
    public func events(from: CalendarDate, to: CalendarDate) async -> [ForeignEvent] { [] }
}
