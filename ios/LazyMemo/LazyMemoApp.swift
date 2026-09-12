import SwiftUI

/// 진입점만. 화면은 `RootView`, 자리와 저장소는 `AppModel` 이 맡는다.
@main
struct LazyMemoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task { await model.start() }
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
