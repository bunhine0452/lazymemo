import CoreLocation
import Foundation
import LazyMemoCore
import Observation

/// 「가면 떠오른다」 — 마트 근처에 가면 장보기 종이가 스스로 나온다.
///
/// **이 앱에서 가능한 가장 게으른 기능**이다. 시간 알림은 자리를 비우면 놓치지만
/// 장소는 그 자리에 갔을 때 오므로 놓칠 수가 없다. `DueClock` 의 짝이고, 꺼내는
/// 방식도 같다 — 시스템 알림이 아니라 **바탕화면의 종이가 앞으로 나온다.**
///
/// ## 그리고 이 계획에서 신뢰 비용이 가장 큰 자리다
///
/// `Always` 위치 권한은 링크 카드(§9.3)나 업데이트 확인과 비교가 안 되는 무게다.
/// 그쪽은 «주소 하나가 나간다» 지만 이것은 **앱을 안 보고 있을 때도 시스템이
/// 당신의 자리를 앱에 알려 준다.** 그래서 조건을 넷으로 늘렸다.
///
/// 1. **기본은 꺼짐.** 켜는 것을 사람이 직접 해야 한다 (아침 브리핑과 같은 잠금).
/// 2. **켜져 있다는 사실이 메뉴에 보인다.** 몇 자리를 지켜보는지까지 적는다 —
///    켜 둔 것을 잊은 채로 두면 약속을 지킨 것이 아니다.
/// 3. **좌표가 이미 적힌 메모만** (`GeofenceRule`). 장소 이름을 좌표로 바꾸려고
///    당신이 적어 둔 이름을 바깥에 보내지 않는다.
/// 4. **도착만 센다.** 떠나는 것은 지켜보지 않는다 — 알아야 할 것이 아니다.
///
/// 위치는 **어디에도 저장하지 않는다.** 들어왔다는 사실만 받아 종이를 꺼내고,
/// 그 좌표는 우리 손에 남지 않는다.
@MainActor
@Observable
final class PlaceWatcher: NSObject, CLLocationManagerDelegate {
    /// 이 자리에 도착했다.
    var onArrival: (ULID) -> Void = { _ in }

    private let store: MemoStore
    private let settings: SettingsStore
    private let manager = CLLocationManager()
    private(set) var watching = 0
    private(set) var dropped = 0

    init(store: MemoStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        super.init()
        manager.delegate = self
    }

    var isEnabled: Bool { settings.current.watchesPlaces ?? false }

    static var access: Bool {
        CLLocationManager().authorizationStatus == .authorizedAlways
    }

    /// 설정 메뉴에 적는 말. **켜 둔 것을 잊게 두지 않는다.**
    var note: String {
        guard isEnabled else { return "기본은 꺼져 있습니다 · 켜면 항상 위치 권한을 묻습니다" }
        guard Self.access else { return "시스템 설정에서 «항상» 위치를 허용해야 켜집니다" }
        if dropped > 0 { return "\(watching)자리를 지켜보는 중 · 상한을 넘겨 \(dropped)장은 빠졌습니다" }
        return "\(watching)자리를 지켜보는 중 · 도착하면 그 종이가 나옵니다"
    }

    func setEnabled(_ enabled: Bool) {
        settings.update { $0.watchesPlaces = enabled }
        if enabled {
            manager.requestAlwaysAuthorization()
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard isEnabled else { return }
        sync()
        observeStore()
    }

    func stop() {
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
        watching = 0
        dropped = 0
    }

    /// 지켜볼 자리를 다시 건다. 메모가 바뀌면 지켜볼 것도 바뀐다.
    private func sync() {
        guard isEnabled, Self.access else {
            watching = 0
            dropped = 0
            return
        }

        let selection = GeofenceRule.select(store.active)
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }

        for memo in selection.watched {
            guard let point = memo.geo else { continue }
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: point.latitude, longitude: point.longitude
                ),
                radius: GeofenceRule.radius,
                identifier: memo.id.stringValue
            )
            // **도착만 센다.** 떠나는 것은 알아야 할 것이 아니다.
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }

        watching = selection.watched.count
        dropped = selection.dropped
    }

    private func observeStore() {
        withObservationTracking {
            _ = store.memos
        } onChange: {
            Task { @MainActor [weak self] in
                self?.sync()
                self?.observeStore()
            }
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager, didEnterRegion region: CLRegion
    ) {
        guard let id = ULID(region.identifier) else { return }
        Task { @MainActor in onArrival(id) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in sync() }
    }
}
