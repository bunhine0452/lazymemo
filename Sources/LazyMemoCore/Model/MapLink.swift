import Foundation

/// 장소를 **시스템 지도**에 넘기는 주소를 만들고, 거꾸로 지도 주소에서 장소를 읽는다.
///
/// 오래 「맥은 지도를 그리지 않는다」였다 — 앱 안에 지도 뷰를 두면 재질이 둘이 되고
/// (§14.5 「재질은 하나 — 종이」), 종이 위에 지도를 얹는 순간 화면이 «글자와
/// 종이뿐»(철학 4)이 아니게 된다는 이유였다. 2026-09-14 에 뒤집었다: 폰이 먼저 종이
/// 머리에 만질 수 없는 작은 지도 카드를 앉혔고(MOBILE_DESIGN §5 「자리 카드」), 맥이
/// 같은 카드를 받았다(`PlaceCardsView`). 여기 남은 것은 **바깥의 지도로 가는 주소**뿐이다 —
/// 꼬리의 잉크 자국을 누를 때, 그리고 좌표를 못 찾은 이름을 지도 앱에 넘길 때.
///
/// **여기서 다루는 것은 주소 문자열뿐이고, 이 타입은 아무 데도 접속하지 않는다.**
/// 실제로 여는 것은 사용자가 눌렀을 때의 OS 다 — §9.3 의 약속(기본 상태에서
/// 네트워크를 쓰지 않는다)이 장소를 들여도 그대로다.
public enum MapLink {
    /// 좌표가 있으면 그 점으로, 없으면 이름을 검색어로 넘긴다.
    ///
    /// `ll` 만 넘기면 지도는 그 자리를 보여주되 핀에 이름이 없다. `q` 를 늘
    /// 함께 넘겨 **무엇을 찾아간 것인지가 지도에도 남게** 한다.
    public static func url(place: String?, geo: Coordinate?) -> URL? {
        let name = place.flatMap { $0.isEmpty ? nil : $0 } ?? geo?.description
        guard let name else { return nil }

        var items: [URLQueryItem] = []
        if let geo { items.append(URLQueryItem(name: "ll", value: geo.description)) }
        items.append(URLQueryItem(name: "q", value: name))

        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = items
        return components?.url
    }

    public static func url(for memo: Memo) -> URL? {
        url(place: memo.place, geo: memo.geo)
    }

    // MARK: 거꾸로 읽기

    /// 지도 주소에 적혀 있던 것. 둘 중 하나는 있다.
    public struct Spot: Sendable, Equatable {
        public var place: String?
        public var geo: Coordinate?

        public init(place: String? = nil, geo: Coordinate? = nil) {
            self.place = place
            self.geo = geo
        }
    }

    /// 지도 주소에서 이름·좌표를 읽는다 — **주소 안에 적혀 있을 때만.**
    ///
    /// 애플·구글·카카오·네이버의 긴 주소에는 검색어나 좌표가 그대로 들어 있다.
    /// 그러나 폰 앱의 「공유」가 내놓는 짧은 링크(`naver.me`·`kko.to`·
    /// `maps.app.goo.gl`)에는 아무것도 적혀 있지 않다. 그것을 풀려면 접속해야
    /// 하고, 여기는 접속하지 않는다 — 링크 카드가 풀어 준 주소를 다시 여기에
    /// 넣는 것은 카드의 몫이다.
    ///
    /// 네이버의 `c=` 는 읽지 않는다. 그것은 핀이 아니라 **화면의 중심**이라,
    /// 사용자가 지도를 조금만 밀었어도 엉뚱한 자리가 된다. 틀린 좌표를 붙이는
    /// 것은 안 붙이는 것보다 나쁘다 (`PlaceParser`).
    public static func read(_ raw: String) -> Spot? {
        guard let parts = components(raw) else { return nil }
        let host = (parts.host ?? "").lowercased()
        let path = parts.path.split(separator: "/").map(String.init)
        var query: [String: String] = [:]
        for item in parts.queryItems ?? [] where query[item.name] == nil {
            query[item.name] = item.value
        }

        let spot: Spot
        if host == "maps.apple.com" {
            spot = apple(path: path, query: query)
        } else if isGoogleMaps(host: host, path: parts.path) {
            spot = google(raw: raw, path: path, query: query)
        } else if host == "map.kakao.com" {
            spot = kakao(path: path, query: query)
        } else if host == "map.naver.com" || host == "m.map.naver.com" {
            spot = naver(path: path, query: query)
        } else {
            return nil
        }
        return spot.place == nil && spot.geo == nil ? nil : spot
    }

    /// 글 속의 첫 지도 주소에서 읽는다. 지도 주소가 없거나 적힌 것이 없으면 `nil`.
    public static func spot(in text: String) -> Spot? {
        for destination in MarkdownScanner.linkDestinations(in: text) {
            if let spot = read(destination) { return spot }
        }
        return nil
    }

    /// 지도 서비스의 주소인가 — 짧은 공유 링크처럼 **읽을 것이 없어도** 지도는 지도다.
    public static func isMap(_ raw: String) -> Bool {
        guard let parts = components(raw), let host = parts.host?.lowercased() else { return false }
        if ["maps.apple.com", "maps.app.goo.gl", "naver.me", "kko.to"].contains(host) { return true }
        if host.hasSuffix("map.kakao.com") || host.hasSuffix("map.naver.com")
            || host.hasSuffix("place.naver.com") { return true }
        return isGoogleMaps(host: host, path: parts.path)
    }

    // MARK: 지도별

    /// `?ll=위도,경도&q=이름` (우리가 만드는 모양) · `/place?coordinate=…&name=…` (공유).
    private static func apple(path: [String], query: [String: String]) -> Spot {
        let geo = coordinate(query["ll"]) ?? coordinate(query["coordinate"]) ?? coordinate(query["sll"])
        let name = named(query["q"]) ?? named(query["name"]) ?? named(query["address"]) ?? named(query["daddr"])
        return Spot(place: name, geo: geo)
    }

    /// `/maps/place/<이름>/@<중심>/data=…!3d<위도>!4d<경도>` · `/maps/search/<검색어>` · `?q=`.
    ///
    /// `!3d…!4d…` 가 핀이고 `@` 는 화면의 중심이다. 둘 다 있으면 핀을 믿는다.
    private static func google(raw: String, path: [String], query: [String: String]) -> Spot {
        var geo: Coordinate?
        if let pin = raw.firstMatch(of: /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/) {
            geo = coordinate("\(pin.1),\(pin.2)")
        }
        if geo == nil, let center = path.first(where: { $0.hasPrefix("@") }) {
            geo = coordinate(center.dropFirst().split(separator: ",").prefix(2).joined(separator: ","))
        }
        if geo == nil {
            geo = coordinate(query["q"]) ?? coordinate(query["query"]) ?? coordinate(query["ll"])
        }

        var name: String?
        if let index = path.firstIndex(where: { $0 == "place" || $0 == "search" }),
           index + 1 < path.count, !path[index + 1].hasPrefix("@") {
            name = named(path[index + 1].replacingOccurrences(of: "+", with: " "))
        }
        name = name ?? named(query["q"]) ?? named(query["query"])
        return Spot(place: name, geo: geo)
    }

    /// `/link/map/<이름>,<위도>,<경도>` · `/link/to/…` · `/link/search/<이름>` · `?name=` · `?q=`.
    ///
    /// 풀린 주소의 `urlX`·`urlY` 는 위경도가 아니라 카카오의 평면 좌표라 읽지 않는다.
    private static func kakao(path: [String], query: [String: String]) -> Spot {
        if path.first == "link", path.count >= 3 {
            let parts = path[2].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            switch path[1] {
            case "map", "to":
                // `<이름>,<위도>,<경도>`. 숫자 하나뿐이면 카카오의 장소 id 라 읽을 것이 없다.
                guard parts.count >= 3, let geo = coordinate(parts.suffix(2).joined(separator: ",")) else {
                    return Spot()
                }
                return Spot(place: named(parts.dropLast(2).joined(separator: ",")), geo: geo)
            case "search":
                return Spot(place: named(path[2]))
            case "roadview":
                return Spot(geo: coordinate(path[2]))
            default:
                break
            }
        }
        return Spot(place: named(query["name"]) ?? named(query["q"]))
    }

    /// `/p/search/<검색어>` · `/v5/search/<검색어>` · `?query=`. 좌표는 적혀 있지 않다.
    private static func naver(path: [String], query: [String: String]) -> Spot {
        if let index = path.firstIndex(of: "search"), index + 1 < path.count {
            return Spot(place: named(path[index + 1]))
        }
        return Spot(place: named(query["query"]) ?? named(query["q"]))
    }

    // MARK: 조각

    /// `maps.google.*` 는 통째로 지도이고, `google.*` 는 `/maps` 아래만 지도다.
    private static func isGoogleMaps(host: String, path: String) -> Bool {
        if host.hasPrefix("maps.google.") { return true }
        let google = host == "google.com" || host.hasSuffix(".google.com")
            || host == "google.co.kr" || host.hasSuffix(".google.co.kr")
        return google && (path == "/maps" || path.hasPrefix("/maps/"))
    }

    /// `URLComponents` 는 한글이 든 주소를 그대로는 못 읽는다. 한 번 감싸서 다시 본다.
    private static func components(_ raw: String) -> URLComponents? {
        if let parts = URLComponents(string: raw) { return parts }
        let allowed = CharacterSet.urlQueryAllowed.union(CharacterSet(charactersIn: "#"))
        return raw.addingPercentEncoding(withAllowedCharacters: allowed)
            .flatMap { URLComponents(string: $0) }
    }

    private static func coordinate(_ raw: String?) -> Coordinate? {
        raw.flatMap(Coordinate.init)
    }

    /// 이름이라 부를 만한 것만 — 비었거나 좌표를 이름 자리에 넣은 것은 이름이 아니다.
    private static func named(_ raw: String?) -> String? {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              Coordinate(name) == nil, name.count <= InboundNote.placeLimit
        else { return nil }
        return name
    }
}
