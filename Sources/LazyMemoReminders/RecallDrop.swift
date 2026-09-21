import Foundation
import LazyMemoCore
import UserNotifications

/// 앱 밖에서 적힌 메모의 다시 보기 알림을 **그 자리에서** 건다 — 그리고 영수증을 돌려준다.
///
/// 폰의 인텐트(`WriteMemoIntent`)가 쓴다. 인텐트는 파일 한 장만 떨구고 나오므로 `ReminderCenter` 의
/// 대조가 돌지 않는다 — 앱을 다음에 열어야 걸린다. 그 사이의 알림은 놓친다. 그래서 여기서
/// **앱과 같은 이름·같은 내용**으로 하나를 걸어 둔다 (`Recall.notificationID`·`memoKey`·`dateKey`):
/// 앱이 다음에 대조할 때 그것을 자기 것으로 알아보고 두 번 걸지 않는다 (같은 id 는 OS 가 갈아 끼운다).
///
/// 걸 수 있는 조건은 앱과 같다 — 이 기기가 「알림 받기」를 켰고(`RecallSwitch`), 권한이 있고, 앞으로 올
/// 시각이 있다. 하나라도 모르면 걸지 않고 영수증이 그렇게 말한다. 가짜 「예약됨」은 없다.
///
/// 공유 확장(`ios/LazyMemoShare/`)에 같은 것이 한 벌 더 있다 — 확장은 이 패키지를 들지 않는다. 한쪽을 고치면 다른 쪽도.
public enum RecallDrop {
    public static func leave(_ memo: Memo, group: URL?, now: Date = Date()) async -> ReservationReceipt {
        guard Recall.eligible(memo) else { return .notWanted }
        guard let at = memo.surfacesAt else { return memo.due == nil ? .noTime : .dateOnly }
        guard at > now else { return .passed }
        guard let enabled = RecallSwitch.isEnabled(in: group) else { return .needsApp }
        guard enabled else { return .off }
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        case .denied: return .denied
        default: return .needsApp
        }
        guard let reservation = Recall.reservations([memo], now: now).first else { return .passed }
        let content = UNMutableNotificationContent()
        content.title = reservation.title
        content.body = reservation.body ?? Recall.defaultNotificationBody
        content.sound = .default
        content.categoryIdentifier = reservation.body == nil ? Recall.recallCategory : Recall.departureCategory
        content.userInfo = [Recall.memoKey: memo.id.stringValue, Recall.dateKey: reservation.date.timeIntervalSince1970]
        let request = UNNotificationRequest(
            identifier: Recall.notificationID(for: memo.id), content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, reservation.date.timeIntervalSince(now)), repeats: false)
        )
        do {
            try await center.add(request)
            return .scheduled(reservation.date)
        } catch {
            return .failed
        }
    }
}
