import LazyMemoCore
import SwiftUI

/// 가는 길의 설정 — 물을지, 그리고 ODsay 키 (맥의 메뉴 「약속을 적으면 가는 길 묻기」·「대중교통 길찾기 키」와 같다).
///
/// 키는 이 기기의 `settings.json` 에만 남는다 — iCloud 로 건너가지 않으니 맥에도 따로 넣는다.
struct RouteSettingsView: View {
    let settings: SettingsStore

    @State private var asks = true
    @State private var key = ""

    var body: some View {
        Form {
            Section {
                Toggle("약속을 적으면 가는 길 묻기", isOn: $asks)
                    .onChange(of: asks) { _, value in settings.update { $0.asksRoutes = value } }
            } footer: {
                Text("「어디서 출발하시나요?」에 답할 때만 지도와 길찾기에 접속합니다. 묻지 않고 나가는 것은 없습니다.")
            }
            Section {
                TextField("API 키", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .onChange(of: key) { _, value in
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        settings.update { $0.transitKey = trimmed.isEmpty ? nil : trimmed }
                    }
                    .accessibilityIdentifier("transit-key")
            } header: {
                Text("대중교통 길찾기 키 (ODsay)")
            } footer: {
                Text("ODsay LAB(lab.odsay.com)에서 무료로 받은 키를 넣으면 버스 번호·지하철역·환승까지 적힙니다. 없으면 택시만 찾습니다. 키는 이 기기에만 남습니다.")
            }
        }
        .onAppear {
            asks = settings.current.asksRoutes ?? true
            key = settings.current.transitKey ?? ""
        }
    }
}
