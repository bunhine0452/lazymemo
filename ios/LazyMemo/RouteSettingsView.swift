import LazyMemoCore
import SwiftUI

/// 가는 길의 설정 — 물을지 (맥의 메뉴 「약속을 적으면 가는 길 묻기」와 같다). 키는 없다 — 대중교통은 네이버 지도 웹이 키 없이 답한다.
struct RouteSettingsView: View {
    let settings: SettingsStore

    @State private var asks = true

    var body: some View {
        Form {
            Section {
                Toggle("약속을 적으면 가는 길 묻기", isOn: $asks)
                    .onChange(of: asks) { _, value in settings.update { $0.asksRoutes = value } }
            } footer: {
                Text("「어디서 출발하시나요?」에 답할 때만 지도와 길찾기에 접속합니다. 묻지 않고 나가는 것은 없습니다. 대중교통은 네이버 지도, 택시는 애플 지도의 어림입니다.")
            }
        }
        .onAppear { asks = settings.current.asksRoutes ?? true }
    }
}
