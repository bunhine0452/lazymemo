import Foundation

/// 저장 직후의 알림 영수증 — **이 기기에서 확인한 사실만.** 가짜 「예약 완료」로 덮지 않는다 (인계서 §4).
///
/// 같은 낱말을 맥의 달력 줄·폰의 펜·공유 시트·인텐트가 쓴다 — 어디서 적었든 알림의 상태는 한 말로 온다.
/// 그래서 `LazyMemoReminders` 가 아니라 여기(Core)에 있다: 공유 시트는 그 패키지를 들지 않는다.
public enum ReservationReceipt: Equatable, Sendable {
    /// 이 기기의 OS 큐에 들어갔다 — 그 시각에.
    case scheduled(Date)
    /// 시각이 없는 그냥 글 — 알림 이야기를 꺼내지 않는다.
    case noTime
    /// 날짜만 있다 — 아침 알림을 지어내지 않는다 (`Recall`). 시각을 적으면 걸린다고 말해 준다.
    case dateOnly
    /// 시각이 이미 지났다 — 걸 것이 없다.
    case passed
    /// 지운 것·치워 둔 것·다 체크한 목록 — 걸지 않는다.
    case notWanted
    /// 이 기기에서 「알림 받기」를 켜지 않았다.
    case off
    /// 시스템 권한이 거절돼 있다.
    case denied
    /// 이 실행 파일은 알림을 걸 수 없다 (번들 밖).
    case unavailable
    /// 한도(`Recall.reservationLimit`) 밖 — 앞의 것이 지나면 그 자리를 메운다.
    case overflow
    /// OS 가 받지 않았다.
    case failed
    /// 대조가 아직 안 돌았다.
    case pending
    /// 앱 밖에서는 확인할 수 없다 — 앱을 열면 대조가 건다 (공유 시트·인텐트).
    case needsApp

    /// 사람의 말 한 조각 — 「이 기기에 알림 예약됨 · 9월 25일 9:00」. 그냥 글이면 `nil` (알림 이야기가 없다).
    public func line(calendar: Calendar = .current) -> String? {
        switch self {
        case .scheduled(let date):
            let day = CalendarDate(date, calendar: calendar)
            let clock = calendar.dateComponents([.hour, .minute], from: date)
            let time = String(format: "%d:%02d", clock.hour ?? 0, clock.minute ?? 0)
            return L("이 기기에 알림 예약됨 · \(DateWords.monthDay(day, calendar: calendar)) \(time)")
        case .noTime, .notWanted: return nil
        case .dateOnly: return L("날짜만 적혀 알림 없음 — 시각을 적으면 걸려요")
        case .passed: return L("시각이 지나 알림 없음")
        case .off: return L("알림 꺼짐 — 이 기기에서 알림 받기를 켜면 걸려요")
        case .denied: return L("알림 권한 없음 — 시스템 설정에서 허용해야 걸려요")
        case .unavailable: return L("설치된 앱에서만 알림이 걸려요")
        case .overflow: return L("알림 한도 밖 — 앞의 것이 지나면 걸려요")
        case .failed: return L("알림 예약 실패 · 다시 시도")
        case .pending: return L("알림 확인 중")
        case .needsApp: return L("알림은 앱을 열면 걸려요")
        }
    }

    /// 달력 줄 꼬리의 짧은 말 — 「알림」「알림 꺼짐」「알림 실패」. 시각이 없으면 `nil`.
    public var mark: String? {
        switch self {
        case .scheduled: L("알림")
        case .noTime, .dateOnly, .notWanted, .passed: nil
        case .off, .denied, .unavailable: L("알림 꺼짐")
        case .overflow: L("알림 대기")
        case .failed: L("알림 실패")
        case .pending, .needsApp: L("알림 확인 중")
        }
    }
}
