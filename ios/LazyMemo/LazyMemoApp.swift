import LazyMemoReminders
import LazyMemoSpotlight
import SwiftUI
import UIKit

/// 진입점만. 화면은 `RootView`, 자리와 저장소는 `AppModel` 이 맡는다.
@main
struct LazyMemoApp: App {
    @UIApplicationDelegateAdaptor(PhoneDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task { await model.start() }
                // Spotlight 결과를 눌렀다 — 어느 메모인지 담아 두면 화면이 연다 (`HomeView`).
                .onContinueUserActivity(SpotlightCenter.activityType) { activity in
                    SpotlightCenter.shared.opened = SpotlightCenter.memoID(from: activity)
                }
                // 위젯·단축어의 `lazymemo://…` — 메모는 같은 시트로, 「적기」는 펜으로 (`AppModel.open`).
                .onOpenURL { url in model.open(url: url) }
        }
        // 뒤로 물러날 때 적던 글을 내리고, 앞으로 올 때 밖에서 온 변경을 본다 —
        // 폰이 자는 동안 맥에서 적은 것.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model.background()
            case .active: Task { await model.foreground() }
            default: break
            }
        }
    }
}

/// 알림 delegate 를 **앱이 뜨기 전에** 세운다. 그래야 꺼진 채 누른 알림이 어느 메모인지 도착한다
/// (`ReminderCenter.opened`). 그 밖의 일은 없다 — 화면은 SwiftUI 가 맡는다.
final class PhoneDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = ReminderCenter.shared
        return true
    }
}
