import CoreLocation
import Foundation
import LazyMemoCore
import Observation

/// 「지금 여기」 — 펜 왼쪽 끝의 시스템 위치 단추 뒤 (MOBILE_DESIGN §9). 맥의
/// `HereCapture` 와 같은 규칙.
///
/// - 첫 실행에는 아무것도 묻지 않는다. `LocationButton` 을 누르는 순간 시스템이
///   한 번 허용을 준다 — 우리가 권한 창을 띄우지 않는다.
/// - 거절돼 있으면 「설정에서 위치를 켜야 합니다」 한 줄. 다시 묻지 않는다.
/// - 한 번 재고 끊는다. 「항상」 권한은 요구하지 않는다.
/// - 좌표를 주소로 바꾸려고 애플 지오코딩에 **좌표만** 보낸다 — 메모 본문은 나가지 않는다.
@Observable
final class HereFix {
    private(set) var fixing = false
    /// 칩 자리에 한 번 적을 말. 없으면 `nil`.
    private(set) var trouble: String?

    private static let patience: Duration = .seconds(12)

    static var denied: Bool {
        switch CLLocationManager().authorizationStatus {
        case .denied, .restricted: true
        default: false
        }
    }

    func fix() async -> PenModel.Here? {
        trouble = nil
        guard !Self.denied else {
            trouble = String(localized: "설정에서 위치를 켜야 합니다")
            return nil
        }
        fixing = true
        defer { fixing = false }

        let location = await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { await Self.firstFix() }
            group.addTask {
                try? await Task.sleep(for: Self.patience)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        guard let location else {
            trouble = Self.denied ? String(localized: "설정에서 위치를 켜야 합니다") : String(localized: "위치를 못 잡았습니다")
            return nil
        }
        let point = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let address = await Self.address(of: location)
        return PenModel.Here(place: address ?? point?.description ?? String(localized: "여기"), geo: point)
    }

    /// 권한이 아직이면 시스템이 여기서 묻는다. 첫 좌표 하나로 끝.
    private static func firstFix() async -> CLLocation? {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied { return nil }
                if let location = update.location { return location }
            }
        } catch {}
        return nil
    }

    /// 좌표를 사람이 읽는 주소로. **나가는 것은 좌표뿐이다.**
    private static func address(of location: CLLocation) async -> String? {
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let parts = [mark.administrativeArea, mark.locality, mark.subLocality, mark.thoroughfare]
        let joined = parts.compactMap { $0 }.joined(separator: " ")
        return joined.isEmpty ? mark.name : joined
    }
}
