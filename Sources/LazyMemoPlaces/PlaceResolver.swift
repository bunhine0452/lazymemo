import CoreLocation
import Foundation
import LazyMemoCore
import MapKit
import Observation

/// 메모의 자리들을 지도 위의 점으로 — 폰과 맥이 같은 답을 본다.
///
/// 「강남역」이 어디인지는 애플 지도에 물어야 안다 (`MKLocalSearch`). 파일에 좌표가
/// 있으면 묻지 않고, 한 번 안 이름은 이 실행 안에서 다시 묻지 않는다. 첫 자리의
/// 좌표는 파일의 `geo:` 에 적어 둔다 — 다음엔 폰도 맥도 안 묻고, 「가면 떠오르기」도
/// 그 자리를 안다. **길은 재지 않는다** — 가는 길은 사용자가 쓰는 지도 앱이 자기
/// 위치에서 알아서 찾는다 (`MapApp`). 우리가 위치를 읽을 이유가 없다.
@Observable
@MainActor
public final class PlaceResolver {
    public struct Spot: Equatable {
        public var place: MemoPlaces.Place
        public var coordinate: CLLocationCoordinate2D?
        /// 지도가 이름을 못 찾았다. 카드는 이름만 보인다.
        public var unresolved = false

        public static func == (a: Spot, b: Spot) -> Bool {
            a.place == b.place && a.unresolved == b.unresolved
                && a.coordinate?.latitude == b.coordinate?.latitude
                && a.coordinate?.longitude == b.coordinate?.longitude
        }
    }

    public private(set) var spots: [Spot] = []

    public init() {}

    /// 이 실행 안에서 한 번 안 이름.
    private static var known: [String: CLLocationCoordinate2D] = [:]

    /// 메모의 자리들로 다시 짓는다. 첫 자리의 좌표를 새로 알게 되면 `onResolvedFirst`.
    public func load(places: [MemoPlaces.Place], onResolvedFirst: ((Coordinate) -> Void)? = nil) async {
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
