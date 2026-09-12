import LazyMemoCore
import SwiftUI

/// 첫 화면. 자리를 정하는 동안은 비어 있고, 정해지면 펜이다.
struct RootView: View {
    let model: AppModel

    var body: some View {
        switch model.phase {
        case .opening:
            Paper.surface.ignoresSafeArea()
        case .failed(let reason):
            ContentUnavailableView(reason, systemImage: "folder.badge.questionmark")
        case .ready(let session):
            HomeView(session: session)
        }
    }
}
