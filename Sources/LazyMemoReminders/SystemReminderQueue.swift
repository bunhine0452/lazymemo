import Foundation
import UserNotifications

/// `UNUserNotificationCenter` 를 `ReminderQueue` 의 모양으로.
///
/// **앱 번들 안에서만 만든다.** `UNUserNotificationCenter.current()` 는 번들 id 가
/// 없는 실행 파일(bare `swift run`·`swift test`)에서 곧바로 죽는다. 그 자리에는
/// `nil` 이 서고, 설정 화면은 「설치된 앱에서만」이라고 적는다.
///
/// 앱이 뜨기 전에 delegate 가 서 있어야 **꺼진 채 누른 알림**이 도착한다. 그래서
/// `ReminderCenter.shared` 를 앱 delegate 의 첫 줄에서 건드린다.
@MainActor final class SystemReminderQueue: NSObject, ReminderQueue, UNUserNotificationCenterDelegate {
    static func ifBundled() -> SystemReminderQueue? {
        guard Bundle.main.bundleURL.pathExtension == "app", Bundle.main.bundleIdentifier != nil else { return nil }
        return SystemReminderQueue()
    }

    var onTap: ((String) -> Void)?
    private let center = UNUserNotificationCenter.current()
    private nonisolated static let memoKey = "memo"
    private nonisolated static let dateKey = "date"

    override init() {
        super.init()
        center.delegate = self
    }

    func authorization() async -> ReminderAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        case .notDetermined: .undecided
        @unknown default: .undecided
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pending() async -> [ReminderRequest] {
        await center.pendingNotificationRequests().compactMap { request in
            guard let seconds = request.content.userInfo[Self.dateKey] as? Double else { return nil }
            return ReminderRequest(
                id: request.identifier, title: request.content.title, body: request.content.body,
                date: Date(timeIntervalSince1970: seconds)
            )
        }
    }

    func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = [
            Self.memoKey: String(request.id.dropFirst(ReminderCenter.prefix.count)),
            Self.dateKey: request.date.timeIntervalSince1970,
        ]
        // 절대 시각 하나다 — 달력 성분으로 풀면 시간대가 바뀐 기기에서 다른 순간이 된다.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, request.date.timeIntervalSinceNow), repeats: false
        )
        try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    func removePending(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func delivered() async -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    func removeDelivered(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: UNUserNotificationCenterDelegate — 어느 스레드에서 오든 메인으로 건넨다

    /// 앱이 앞에 있어도 배너는 뜬다 — 다시 볼 시각에 다른 종이를 보고 있을 수 있다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo[Self.memoKey] as? String
        if let raw {
            Task { @MainActor [weak self] in self?.onTap?(raw) }
        }
        completionHandler()
    }
}
