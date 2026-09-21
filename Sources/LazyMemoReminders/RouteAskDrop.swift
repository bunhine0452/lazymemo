import Foundation
import LazyMemoCore
import UserNotifications

/// 앱 밖에서 적힌 약속 메모가 「어디서 출발하시나요?」를 앱에 남기는 길 — 알림 하나와 앱 그룹의 표 (`RouteAsk`).
///
/// 폰의 인텐트(`WriteMemoIntent`)가 쓴다. 인텐트는 파일 한 장만 떨구고 나오므로 펜이 없고, 그래서
/// ① 알림으로 「눌러서 답해 주세요」 하고 ② 표에 id 를 적어 앱이 켜지면 펜이 묻게 한다. 알림은 앱이
/// 「이 기기에서 알림 받기」로 권한을 받아 둔 기기에서만 걸린다 — 권한이 없으면 표만 남는다.
///
/// 공유 확장(`ios/LazyMemoShare/ShareViewController.swift`)에 같은 것이 한 벌 더 있다 — 확장은 메모리
/// 한도가 빡빡해 이 패키지를 들지 않는다. 한쪽을 고치면 다른 쪽도 같이.
public enum RouteAskDrop {
    public static func leave(_ memo: Memo, group: URL?) async {
        RouteAsk.remember(memo.id, in: group)
        let center = UNUserNotificationCenter.current()
        guard case .authorized = await center.notificationSettings().authorizationStatus else { return }
        let content = UNMutableNotificationContent()
        content.title = memo.title
        content.body = RouteAsk.notificationBody
        content.sound = .default
        content.userInfo = ["memo": memo.id.stringValue, RouteAsk.askKey: RouteAsk.askValue]
        let request = UNNotificationRequest(
            identifier: RouteAsk.notificationPrefix + memo.id.stringValue, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        try? await center.add(request)
    }
}
