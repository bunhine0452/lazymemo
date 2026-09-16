import CoreLocation
import Foundation
import LazyMemoCore
import MapKit

/// 좌표를 얻은 자리 — 길을 재려면 이름만으로는 안 된다.
public struct LocatedPlace: Sendable, Equatable {
    public var name: String
    public var geo: Coordinate

    public init(name: String, geo: Coordinate) {
        self.name = name
        self.geo = geo
    }

    var location: CLLocation { CLLocation(latitude: geo.latitude, longitude: geo.longitude) }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude) }
}

/// 사람이 말한 자리를 좌표로 — 「석촌고분역」·주소·지도 링크(짧은 공유 링크까지).
///
/// `PlaceResolver` 가 카드를 위해 이름을 지도에 묻는 것과 같은 일이지만, 여기는 **링크를
/// 푼다.** 폰 앱의 「공유」가 내놓는 `naver.me`·`kko.to`·`maps.app.goo.gl` 에는 아무것도
/// 적혀 있지 않아(`MapLink`) 접속해서 풀어야 한다. 접속은 사람이 되물음에 답한 그때만이다 —
/// 종이를 열 때마다 두드리지 않는다.
public enum PlaceLocator {
    /// 이름·주소·링크 무엇이든. 못 찾으면 nil — 짐작하지 않는다.
    public static func locate(_ text: String, near: Coordinate? = nil) async -> LocatedPlace? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let link = firstLink(in: trimmed) {
            if let spot = MapLink.read(link), let geo = spot.geo {
                return LocatedPlace(name: spot.place ?? geo.description, geo: geo)
            }
            if let found = await ShortMapLink.resolve(link) {
                if let geo = found.geo { return LocatedPlace(name: found.name, geo: geo) }
                return await search(found.name, near: near)
            }
            if let spot = MapLink.read(link), let name = spot.place { return await search(name, near: near) }
            return nil
        }
        // 사람이 친 이름은 그대로 둔다 — 지도는 「Seokchon Gobun Station」이라 부르기도 하지만
        // 메모에 설 이름은 그 사람의 말이다. 좌표만 지도에서 받는다.
        let name = stripped(trimmed)
        guard var found = await search(name, near: near) else { return nil }
        found.name = name
        return found
    }

    /// 지도에 이름을 묻는다. 가까운 곳이 있으면 그 근처부터 — 「스타벅스」는 수천 개다.
    public static func search(_ name: String, near: Coordinate?) async -> LocatedPlace? {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let near {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: near.latitude, longitude: near.longitude),
                latitudinalMeters: 40_000, longitudinalMeters: 40_000
            )
        }
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first,
              let geo = Coordinate(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
        else { return nil }
        return LocatedPlace(name: item.name ?? query, geo: geo)
    }

    /// 글 속의 첫 주소 — 마크다운 링크든 맨 주소든.
    static func firstLink(in text: String) -> String? {
        MarkdownScanner.linkDestinations(in: text).first
    }

    /// 「석촌고분역에서 출발」·「석촌고분역에서」·「집에서 갈게」 — 자리 이름만 남긴다.
    static func stripped(_ text: String) -> String {
        var name = text
        let tails = ["에서 출발할게", "에서 출발할래", "에서 출발해", "에서 출발", "에서 갈게", "에서 가", "에서 출발함", "출발은", "에서요", "에서", "부터", "출발"]
        for tail in tails where name.hasSuffix(tail) {
            name = String(name.dropLast(tail.count))
            break
        }
        return name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",.!~")))
    }
}

/// 짧은 공유 링크를 푼다 — 네이버·카카오·구글의 「공유」가 내놓는 것.
///
/// 네이버는 두 번 접속한다: 짧은 주소는 장소 번호로만 가고(`map.naver.com/p/entry/place/<번호>`),
/// 그 번호의 모바일 페이지(`m.place.naver.com/place/<번호>/home`)에 이름과 좌표가 적혀 있다.
/// 구글의 긴 주소는 좌표가 그대로 들어 있어 `MapLink` 가 읽고, 카카오의 장소 페이지는 이름만 준다.
enum ShortMapLink {
    struct Found: Equatable {
        var name: String
        var geo: Coordinate?
    }

    /// 접속이 오래 걸리면 되물음이 그만큼 멈춘다 — 짧게 끊는다.
    static let timeout: TimeInterval = 10
    private static let mobileAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static func resolve(_ raw: String) async -> Found? {
        guard let url = URL(string: raw), MapLink.isMap(raw) else { return nil }
        guard let final = await finalURL(of: url) else { return nil }
        let text = final.absoluteString

        if let spot = MapLink.read(text), spot.geo != nil || spot.place != nil {
            if let geo = spot.geo { return Found(name: spot.place ?? geo.description, geo: geo) }
        }
        if let id = naverPlaceID(in: final) {
            return await naverPlace(id: id)
        }
        if let host = final.host()?.lowercased(), host.hasSuffix("map.kakao.com") || host == "place.map.kakao.com",
           let title = await pageTitle(of: final) {
            return Found(name: title, geo: nil)
        }
        if let spot = MapLink.read(text), let name = spot.place { return Found(name: name, geo: nil) }
        return nil
    }

    /// 리다이렉트를 따라간 끝의 주소. `URLSession` 이 따라가므로 응답의 `url` 이 그것이다.
    private static func finalURL(of url: URL) async -> URL? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "HEAD"
        request.setValue(mobileAgent, forHTTPHeaderField: "User-Agent")
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return nil }
        return response.url ?? url
    }

    /// `map.naver.com/p/entry/place/1041643501` · `m.place.naver.com/restaurant/1041643501/home` ·
    /// `m.map.naver.com/appLink.naver?pinId=1041643501` (짧은 링크가 폰 UA 에게 보내는 곳).
    static func naverPlaceID(in url: URL) -> String? {
        guard let host = url.host()?.lowercased(), host.hasSuffix("naver.com") else { return nil }
        let parts = url.path().split(separator: "/").map(String.init)
        if let index = parts.firstIndex(where: { $0.allSatisfy(\.isNumber) && $0.count >= 5 }) { return parts[index] }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        for key in ["pinId", "placeId", "id"] {
            if let value = query.first(where: { $0.name == key })?.value, value.allSatisfy(\.isNumber), value.count >= 5 { return value }
        }
        return nil
    }

    private static func naverPlace(id: String) async -> Found? {
        guard let url = URL(string: "https://m.place.naver.com/place/\(id)/home") else { return nil }
        guard let html = await page(url) else { return nil }
        guard let title = ogTitle(in: html).map(cleanedNaverTitle), !title.isEmpty else { return nil }
        var geo: Coordinate?
        // 첫 좌표가 이 장소의 것이다 — `"x":"127.085265","y":"37.510894"` (x 가 경도).
        if let match = html.firstMatch(of: /"x":"(-?\d+\.\d+)","y":"(-?\d+\.\d+)"/),
           let longitude = Double(match.1), let latitude = Double(match.2) {
            geo = Coordinate(latitude: latitude, longitude: longitude)
        }
        return Found(name: title, geo: geo)
    }

    private static func pageTitle(of url: URL) async -> String? {
        guard let html = await page(url) else { return nil }
        let title = ogTitle(in: html) ?? html.firstMatch(of: /<title>([^<]*)<\/title>/).map { String($0.1) }
        guard let title else { return nil }
        // 「스타벅스 | 카카오맵」처럼 서비스 이름이 뒤에 붙는다.
        let cleaned = title.components(separatedBy: " | ").first ?? title
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func page(_ url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(mobileAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func ogTitle(in html: String) -> String? {
        html.firstMatch(of: /property="og:title"\s+content="([^"]*)"/).map { String($0.1) }
            ?? html.firstMatch(of: /content="([^"]*)"\s+property="og:title"/).map { String($0.1) }
    }

    /// 「투파인드피터 잠실점 : 네이버」 → 「투파인드피터 잠실점」. 끝에 제어 문자(U+001C)가 붙어 오기도 한다.
    static func cleanedNaverTitle(_ title: String) -> String {
        var name = String(title.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for tail in [" : 네이버 지도", " : 네이버 플레이스", " : 네이버", " - 네이버 지도"] where name.hasSuffix(tail) {
            name = String(name.dropLast(tail.count))
            break
        }
        return decodedEntities(name).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodedEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
