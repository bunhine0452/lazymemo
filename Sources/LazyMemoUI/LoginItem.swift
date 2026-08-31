import Foundation
import ServiceManagement

/// 로그인할 때 스스로 뜨는가.
///
/// **이 앱은 켜져 있지 않으면 아무것도 아니다.** 바탕화면의 종이도, ⌥⌘N 도,
/// 시각이 되어 나오는 일정도 전부 앱이 살아 있어야 성립한다. 그런데 재부팅
/// 뒤에 앱을 다시 켜는 것은 게으른 사람이 **가장 안 하는 일**이다 — 그래서
/// 이 앱의 다른 모든 편안함보다 이 스위치 하나가 먼저다.
///
/// `SMAppService` 는 권한을 묻지 않는다. 첫 실행에서 사용자를 시스템 설정으로
/// 보내지 않는다는 §8 의 원칙을 지킨 채로 재부팅을 넘길 수 있다.
///
/// **켜는 것은 사용자가 정한다.** 시스템 상태를 말없이 바꾸지 않는다 — 대신
/// 첫 실행의 안내 종이가 이 스위치가 어디 있는지 적어 둔다 (`WelcomeNote`).
@MainActor
enum LoginItem {
    /// 등록할 몸이 있는가.
    ///
    /// `swift run` 으로 띄운 개발 빌드는 `.app` 번들이 아니라 등록할 수 없다.
    /// 그때 메뉴에 켤 수 없는 스위치를 보여 주면 그것부터가 거짓말이다.
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// 켜고 끈다.
    ///
    /// 실패해도 예외를 던지지 않는다 — 메뉴는 열 때마다 다시 지어지고 상태를
    /// `isEnabled` 로 되읽으므로, 실패하면 체크가 그냥 안 켜진다. 화면이
    /// 실제 상태를 말하는 것이 성공/실패를 따로 알리는 것보다 정확하다.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        guard isAvailable else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
