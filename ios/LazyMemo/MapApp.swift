import Foundation
import LazyMemoCore
import LazyMemoPlaces
import MapKit
import UIKit

/// 가는 길을 여는 지도 앱 — 깔린 것만 단추로 선다.
///
/// 출발지는 넘기지 않는다: 셋 다 비워 두면 **지금 위치**에서 찾고, 수단은
/// 대중교통을 먼저 내민다. 위치를 읽는 것도, 길을 재는 것도 그 앱의 몫이다 —
/// 우리는 좌표 하나와 이름을 건넬 뿐이다.
enum MapApp: String, CaseIterable, Identifiable {
    case kakao, naver, apple
    var id: String { rawValue }

    /// 적힌 길을 깔린 지도 앱으로 — 네이버 → 카카오 → 웹의 카카오맵. 애플 지도는 한국의 대중교통을 모른다.
    /// 종이의 카드(`MemoEditorView`)와 배너의 「지도 열기」(`ReminderCenter.onOpenMap`)가 같은 길을 쓴다.
    static func openRoute(_ route: TransitRoute, destination geo: Coordinate?) {
        let app = UIApplication.shared
        let appName = Bundle.main.bundleIdentifier ?? "lazymemo"
        if let geo {
            if let probe = URL(string: "nmap://open"), app.canOpenURL(probe),
               let url = RouteLinks.naverApp(route, destination: geo, appName: appName) { app.open(url); return }
            if let probe = URL(string: "kakaomap://open"), app.canOpenURL(probe),
               let url = RouteLinks.kakaoApp(route, destination: geo) { app.open(url); return }
        }
        if let url = RouteLinks.kakaoWeb(route) { app.open(url) }
    }

    /// 메모에 적힌 길을 연다. 길이 없으면 아무 일도 없다.
    static func openRoute(in memo: Memo) {
        guard let at = memo.at, let route = RouteNote.read(memo.body, day: at) else { return }
        openRoute(route, destination: memo.geo)
    }

    var label: String {
        switch self {
        case .kakao: String(localized: "카카오맵")
        case .naver: String(localized: "네이버 지도")
        case .apple: String(localized: "애플 지도")
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
