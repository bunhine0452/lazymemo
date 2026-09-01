import CoreLocation
import Foundation
import LazyMemoCore

/// `⌥⌘L` — **지금 여기.** 「여기 주차했다」, 「이 가게 뭐지」.
///
/// `⌥⌘V`(클립보드)의 형제다. 창을 열지 않고 종이 한 장이 바탕화면에 꽂힌다.
///
/// ## 권한은 처음 누를 때만 묻는다
///
/// 첫 실행에서 사용자를 시스템 설정으로 보내지 않는다는 원칙(§8)이 여기서도
/// 그대로다 — 이 단축키를 한 번도 안 누르는 사람에게는 영영 물을 일이 없다.
/// **거절하면 그 단축키는 조용히 없는 것이 된다**: 다시 묻지 않고, 눌러도
/// 아무 일이 없으며, 그 사실은 설정 메뉴에 적힌다.
///
/// ## 주소로 바꾸는 데 네트워크를 쓴다
///
/// 좌표만 적어 두면 종이에 `37.4979,127.0276` 이 남는데 그건 사람이 읽는 글이
/// 아니다. 그래서 애플의 지오코딩에 **좌표를 보내 주소를 받는다** — §9.3 의
/// 세 번째 네트워크 경로다. 나가는 것은 좌표뿐이고 **메모 본문은 나가지 않는다.**
/// 실패하면 좌표만 적고 넘어간다 — 그것 때문에 메모를 못 만들지는 않는다.
@MainActor
final class HereCapture: NSObject, CLLocationManagerDelegate {
    enum Access: Sendable, Equatable {
        case notAsked, granted, denied

        /// 설정 메뉴에 적을 말. `nil` 이면 할 말이 없다.
        var note: String? {
            switch self {
            case .granted: "⌥⌘L 로 지금 있는 자리를 종이에 적습니다"
            case .notAsked: "처음 ⌥⌘L 을 누를 때 한 번 묻습니다"
            case .denied: "시스템 설정 → 개인정보 보호에서 위치를 허용하면 켜집니다"
            }
        }
    }

    private let door: InboundDoor
    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocation?, Never>?

    init(door: InboundDoor) {
        self.door = door
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    static var access: Access {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    /// 지금 자리를 종이 한 장으로.
    @discardableResult
    func capture() async -> Memo? {
        switch Self.access {
        case .denied: return nil
        case .notAsked: manager.requestWhenInUseAuthorization()
        case .granted: break
        }

        guard let location = await currentLocation() else { return nil }
        let point = Coordinate(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude
        )
        let address = await Self.address(of: location)

        // 적을 글이 없으면 자리 자체가 글이다 — 사람이 나중에 덧붙인다.
        return await door.receive(
            InboundNote(text: address ?? point?.description ?? "여기", place: address)
        )
    }

    /// 한 번만 재고 끊는다. 계속 켜 두면 배터리를 먹고, 이 기능에 필요한 것도 아니다.
    private func currentLocation() async -> CLLocation? {
        if let waiting {
            self.waiting = nil
            waiting.resume(returning: nil)
        }
        return await withCheckedContinuation { continuation in
            waiting = continuation
            manager.requestLocation()
        }
    }

    /// 좌표를 사람이 읽는 주소로. **나가는 것은 좌표뿐이다.**
    private static func address(of location: CLLocation) async -> String? {
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        else { return nil }
        let parts = [mark.administrativeArea, mark.locality, mark.subLocality, mark.thoroughfare]
        let joined = parts.compactMap { $0 }.joined(separator: " ")
        return joined.isEmpty ? mark.name : joined
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            let continuation = waiting
            waiting = nil
            continuation?.resume(returning: locations.last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let continuation = waiting
            waiting = nil
            continuation?.resume(returning: nil)
        }
    }
}
