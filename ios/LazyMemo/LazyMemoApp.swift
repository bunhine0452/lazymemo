import SwiftUI

/// 진입점만. 화면은 `RootView`, 자리와 저장소는 `AppModel` 이 맡는다.
@main
struct LazyMemoApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task { await model.start() }
        }
    }
}
