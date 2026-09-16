import Foundation
import LazyMemoCore

/// 네이버 지도 **웹**이 쓰는 길찾기 — 키 없이 답한다 (2026-09-16 실측).
///
/// `map.naver.com/p/api/directions/pubtrans` 는 네이버 지도 웹 페이지가 브라우저에서 부르는 주소다.
/// 사람이 가져온 화면(최적·최소도보, 버스 번호와 종류, 정류장, 요금, 출발·도착 시각, 기후동행)의
/// 데이터 그대로이고 미래의 출발 시각도 시간표대로 답한다. **문서화된 API 가 아니다** — 네이버가
/// 모양을 바꾸거나 브라우저 아닌 요청을 막으면 그날로 끊긴다. 그때 `RouteFinder` 는 택시만 잰다 —
/// 키가 필요한 다른 길찾기는 두지 않기로 했다 (2026-09-16, 사용자: 「ODsay 는 절대 안 쓸 거야」).
///
/// 시각은 한국 시간이다(오프셋 없는 `2026-09-16T19:32:11`) — 서울의 길이라 `Asia/Seoul` 로 읽는다.
public struct NaverWebRouter: TransitRouter {
    public init() {}

    static let endpoint = "https://map.naver.com/p/api/directions/pubtrans"
    static let timeout: TimeInterval = 15
    static let agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    static let zone = TimeZone(identifier: "Asia/Seoul") ?? .current
    /// 도착보다 이만큼 앞서 닿게 출발 시각을 되잰다.
    static let slack: TimeInterval = 3 * 60

    /// `arriveBy` 까지 닿는 길들. 도착 시각을 받는 API 가 아니라, 도심의 흔한 길이(40분) 만큼 앞선
    /// 출발로 한 번 묻는다 — 고른 뒤 `refine` 이 그 길의 소요 시간으로 되잰다.
    public func routes(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async throws -> [TransitRoute] {
        let guess = arriveBy.addingTimeInterval(-40 * 60)
        let departure = max(Date(), guess)
        return try await fetch(from: origin, to: destination, departingAt: departure, arriveBy: arriveBy)
    }

    /// 고른 길을 그 소요 시간만큼 앞선 출발로 다시 잰다 — 시간표의 실제 출발·승차 시각이 약속에 맞는다.
    /// 같은 종류의 길 중 약속 전에 닿는 가장 늦은 출발을 고른다. 그 출발로는 늦으면(그 시각의 차가 없어서)
    /// 늦는 만큼 앞당겨 두 번까지 더 묻고, 그래도 늦으면 가장 일찍 닿는 것을 준다. 못 재면 nil.
    public func refine(_ route: TransitRoute, from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async -> TransitRoute? {
        var departure = arriveBy.addingTimeInterval(-Double(route.minutes) * 60 - Self.slack)
        var fallback: TransitRoute?
        for _ in 0..<3 {
            guard departure > Date() else { break }
            guard let routes = try? await fetch(from: origin, to: destination, departingAt: departure, arriveBy: arriveBy) else { break }
            let same = routes.filter { $0.kind == route.kind }
            if let best = same.filter({ $0.arrive <= arriveBy }).max(by: { $0.depart < $1.depart }) { return best }
            guard let earliest = same.min(by: { $0.arrive < $1.arrive }) else { break }
            fallback = earliest
            departure = departure.addingTimeInterval(-(earliest.arrive.timeIntervalSince(arriveBy) + Self.slack))
        }
        return fallback
    }

    func fetch(from origin: LocatedPlace, to destination: LocatedPlace, departingAt departure: Date, arriveBy: Date) async throws -> [TransitRoute] {
        var parts = URLComponents(string: Self.endpoint)
        parts?.queryItems = [
            .init(name: "start", value: Self.point(origin)), .init(name: "goal", value: Self.point(destination)),
            .init(name: "crs", value: "EPSG:4326"), .init(name: "mode", value: "TIME"), .init(name: "lang", value: "ko"),
            .init(name: "departureTime", value: Self.stamp(departure)), .init(name: "includeDetailOperation", value: "true"),
        ]
        guard let url = parts?.url else { return [] }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(Self.agent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://map.naver.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw TransitFailure.network(error.localizedDescription) }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw TransitFailure.rejected("네이버 지도가 \(http.statusCode) 으로 답했습니다")
        }
        return try Self.parse(data, origin: origin.name, destination: destination.name)
    }

    /// `경도,위도,이름` — 이름의 쉼표는 자리를 가르는 글자라 뗀다.
    static func point(_ place: LocatedPlace) -> String {
        "\(place.geo.longitude),\(place.geo.latitude),\(place.name.replacingOccurrences(of: ",", with: " "))"
    }

    // MARK: 응답 읽기

    struct Envelope: Decodable {
        var status: String?
        var message: String?
        var paths: [Path]?
    }
    struct Path: Decodable {
        var type: String?
        var labels: [String]?
        var duration: Int?
        var fare: Int?
        var departureTime: String?
        var arrivalTime: String?
        var legs: [Leg]?
    }
    struct Leg: Decodable {
        var steps: [Step]?
    }
    struct Step: Decodable {
        var type: String?
        var duration: Int?
        var distance: Int?
        var departureTime: String?
        var arrivalTime: String?
        var headsign: String?
        var stations: [Station]?
        var routes: [Route]?
    }
    struct Station: Decodable {
        var name: String?
        var displayName: String?
    }
    struct Route: Decodable {
        var name: String?
        var longName: String?
        var type: RouteType?
    }
    struct RouteType: Decodable {
        var name: String?
    }

    static func parse(_ data: Data, origin: String, destination: String) throws -> [TransitRoute] {
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw TransitFailure.rejected("네이버 지도의 답을 읽지 못했습니다") }
        if let message = envelope.message, envelope.paths?.isEmpty ?? true { throw TransitFailure.rejected(message) }
        return (envelope.paths ?? []).compactMap { path -> TransitRoute? in
            guard let departure = path.departureTime.flatMap(date), let arrival = path.arrivalTime.flatMap(date) else { return nil }
            let steps = path.legs?.flatMap { $0.steps ?? [] } ?? []
            var legs: [TransitRoute.Leg] = []
            for step in steps {
                guard let parsed = leg(step) else { return nil }
                if let parsed { legs.append(parsed) }
            }
            guard legs.contains(where: \.rides) else { return nil }
            let minutes = max(1, Int((arrival.timeIntervalSince(departure) / 60).rounded()))
            return TransitRoute(origin: origin, destination: destination, minutes: minutes, arrive: arrival,
                                fare: path.fare, legs: legs, provider: "naver")
        }
    }

    /// 구간 하나. 모르는 탈것(기차·항공·시외버스)은 `nil` 로 길 전체를 버리고, 0분 걷기는 `.some(nil)` 로 건너뛴다.
    static func leg(_ step: Step) -> TransitRoute.Leg?? {
        let minutes = step.duration ?? 0
        switch step.type {
        case "WALKING":
            return .some(minutes > 0 ? TransitRoute.Leg(mode: .walk, minutes: minutes) : nil)
        case "BUS", "SUBWAY":
            let mode: TransitRoute.Mode = step.type == "BUS" ? .bus : .subway
            let route = step.routes?.first
            let names = (step.stations ?? []).compactMap { $0.displayName ?? $0.name }
            return .some(TransitRoute.Leg(
                mode: mode, minutes: minutes, line: route?.name,
                kind: mode == .bus ? route?.type?.name : nil,
                from: names.first, to: names.count > 1 ? names.last : nil,
                stops: names.count > 1 ? names.count - 1 : nil,
                heading: mode == .subway ? step.headsign.flatMap { $0.isEmpty ? nil : $0 } : nil,
                boardAt: step.departureTime.flatMap(date)
            ))
        default:
            return nil
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    static func date(_ raw: String) -> Date? { formatter.date(from: String(raw.prefix(19))) }
    static func stamp(_ date: Date) -> String { formatter.string(from: date) }
}
