import CoreLocation
import Foundation
import LazyMemoCore
import MapKit
import Observation

/// 메모의 자리들을 지도 위의 점으로.
///
/// 「강남역」이 어디인지는 애플 지도에 물어야 안다 (`MKLocalSearch`). 파일에 좌표가
/// 있으면 묻지 않고, 한 번 안 이름은 이 실행 안에서 다시 묻지 않는다. 첫 자리의
/// 좌표는 파일의 `geo:` 에 적어 둔다 — 다음엔 폰도 맥도 안 묻고, 「가면 떠오르기」도
/// 그 자리를 안다. **길은 재지 않는다** — 가는 길은 사용자가 쓰는 지도 앱이 자기
/// 위치에서 알아서 찾는다 (`MapApp`). 우리가 위치를 읽을 이유가 없다.
@Observable
@MainActor
final class PlaceResolver {
    struct Spot: Equatable {
        var place: MemoPlaces.Place
        var coordinate: CLLocationCoordinate2D?
        /// 지도가 이름을 못 찾았다. 카드는 이름만 보인다.
        var unresolved = false

        static func == (a: Spot, b: Spot) -> Bool {
            a.place == b.place && a.unresolved == b.unresolved
                && a.coordinate?.latitude == b.coordinate?.latitude
                && a.coordinate?.longitude == b.coordinate?.longitude
        }
    }

    private(set) var spots: [Spot] = []

    /// 이 실행 안에서 한 번 안 이름.
    private static var known: [String: CLLocationCoordinate2D] = [:]

    /// 메모의 자리들로 다시 짓는다. 첫 자리의 좌표를 새로 알게 되면 `onResolvedFirst`.
    func load(places: [MemoPlaces.Place], onResolvedFirst: ((Coordinate) -> Void)? = nil) async {
        spots = places.map { place in
            var spot = Spot(place: place)
            if let geo = place.geo {
                spot.coordinate = CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude)
            } else if let known = Self.known[place.name] {
                spot.coordinate = known
            }
            return spot
        }
        // 앞 자리를 알면 뒤 자리는 그 근처에서 찾는다 — 「강남역」은 하나지만 「스타벅스」는 수천 개다.
        for index in spots.indices where spots[index].coordinate == nil {
            let name = spots[index].place.name
            let near = spots.first { $0.coordinate != nil }?.coordinate
            let found = await Self.search(name, near: near)
            guard !Task.isCancelled, index < spots.count, spots[index].place.name == name else { return }
            if let found {
                Self.known[name] = found
                spots[index].coordinate = found
                if index == 0, let geo = Coordinate(latitude: found.latitude, longitude: found.longitude) {
                    onResolvedFirst?(geo)
                }
            } else {
                spots[index].unresolved = true
            }
        }
    }

    private static func search(_ name: String, near: CLLocationCoordinate2D?) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.resultTypes = [.pointOfInterest, .address]
        if let near {
            request.region = MKCoordinateRegion(center: near, latitudinalMeters: 30_000, longitudinalMeters: 30_000)
        }
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        return response.mapItems.first?.location.coordinate
    }
}

/// 가는 길을 여는 지도 앱 — 깔린 것만 단추로 선다.
///
/// 출발지는 넘기지 않는다: 셋 다 비워 두면 **지금 위치**에서 찾고, 수단은
/// 대중교통을 먼저 내민다. 위치를 읽는 것도, 길을 재는 것도 그 앱의 몫이다 —
/// 우리는 좌표 하나와 이름을 건넬 뿐이다.
enum MapApp: String, CaseIterable, Identifiable {
    case kakao, naver, apple
    var id: String { rawValue }

    var label: String {
        switch self {
        case .kakao: "카카오맵"
        case .naver: "네이버 지도"
        case .apple: "애플 지도"
        }
    }

    /// 깔린 것만, 카카오 → 네이버 → 애플 차례. 애플은 늘 있다.
    static var installed: [MapApp] {
        allCases.filter { app in
            guard let probe = app.probe else { return true }
            return UIApplication.shared.canOpenURL(probe)
        }
    }

    private var probe: URL? {
        switch self {
        case .kakao: URL(string: "kakaomap://open")
        case .naver: URL(string: "nmap://open")
        case .apple: nil
        }
    }

    /// 그 자리까지의 길. 좌표가 없으면 이름으로 찾아 준다 (애플만).
    func open(_ spot: PlaceResolver.Spot) {
        let name = spot.place.name
        switch self {
        case .kakao:
            guard let to = spot.coordinate,
                  let url = URL(string: "kakaomap://route?ep=\(to.latitude),\(to.longitude)&by=PUBLICTRANSIT")
            else { return }
            UIApplication.shared.open(url)
        case .naver:
            guard let to = spot.coordinate else { return }
            var parts = URLComponents(string: "nmap://route/public")
            parts?.queryItems = [
                .init(name: "dlat", value: String(to.latitude)), .init(name: "dlng", value: String(to.longitude)),
                .init(name: "dname", value: name), .init(name: "appname", value: Bundle.main.bundleIdentifier ?? "lazymemo"),
            ]
            if let url = parts?.url { UIApplication.shared.open(url) }
        case .apple:
            guard let to = spot.coordinate else {
                if let url = MapLink.url(place: name, geo: nil) { UIApplication.shared.open(url) }
                return
            }
            let item = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
            item.name = name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
        }
    }
}
