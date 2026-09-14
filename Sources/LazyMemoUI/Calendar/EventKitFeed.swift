import EventKit
import Foundation
import LazyMemoCore

/// 시스템 캘린더를 **읽기만** 하는 문 (`CalendarFeed`).
///
/// ## 권한은 달력을 처음 열 때만 묻는다
///
/// 첫 실행에서 사용자를 시스템 설정으로 보내지 않는다는 원칙(§8)이 여기서도
/// 그대로다. 메모를 적으러 온 사람에게 캘린더를 내놓으라고 묻는 것은 «앱이
/// 자기를 드러내는» 일이고, 달력을 한 번도 안 여는 사람에게는 영영 물을 일이
/// 없다. 그래서 묻는 자리는 **달력 창이 처음 열릴 때** 하나뿐이다.
///
/// 거절하면 다시 묻지 않는다 — `EKEventStore.authorizationStatus` 가 그 상태를
/// 이미 기억하므로 우리가 따로 적어 둘 것이 없다. 대신 **거절했다는 사실이
/// 메뉴에 보인다**: 조용히 빈 달력을 내놓으면 사용자는 연동이 고장 난 줄 안다.
///
/// ## 쓰지 않는다
///
/// `EKEventStore` 를 들고 있지만 이 타입이 부르는 것은 조회뿐이다. 저장·삭제
/// 함수를 감싸지 않는 것이 규칙이 아니라 **배선**이다 (D6 과 같은 방식).
actor EventKitFeed: CalendarFeed {
    enum Access: Sendable, Equatable {
        case notAsked
        case granted
        case denied

        /// 사람에게 하는 말. `nil` 이면 할 말이 없다 — 잘 되고 있다.
        var note: String? {
            switch self {
            case .granted, .notAsked: nil
            case .denied: L("시스템 설정 → 개인정보 보호에서 캘린더를 허용하면 함께 보입니다")
            }
        }
    }

    private let store = EKEventStore()

    /// 지금 상태. 물어보지 않고 알 수 있다.
    static var access: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    /// 아직 안 물었으면 한 번 묻는다. 이미 정해졌으면 아무 일도 하지 않는다.
    @discardableResult
    func requestAccessIfNeeded() async -> Access {
        guard Self.access == .notAsked else { return Self.access }
        _ = try? await store.requestFullAccessToEvents()
        return Self.access
    }

    func events(from: CalendarDate, to: CalendarDate) async -> [ForeignEvent] {
        guard Self.access == .granted else { return [] }
        guard let start = from.startOfDay(),
              let endOfDay = to.startOfDay(),
              let end = Calendar.current.date(byAdding: .day, value: 1, to: endOfDay)
        else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            ForeignEvent(
                // 반복 일정은 회차마다 같은 eventIdentifier 를 쓴다. 시작 시각을
                // 붙여야 하루에 두 줄이 서도 서로 다른 줄로 센다.
                id: (event.eventIdentifier ?? event.title ?? "?")
                    + "@" + String(Int(event.startDate.timeIntervalSince1970)),
                title: event.title ?? L("제목 없는 일정"),
                start: event.startDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar?.title
            )
        }
    }
}
