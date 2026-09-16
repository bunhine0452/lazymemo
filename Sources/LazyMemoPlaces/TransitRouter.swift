import CoreLocation
import Foundation
import LazyMemoCore
import MapKit

/// 길을 재는 것. 답은 `TransitRoute` 하나씩 — 어디서 왔든 카드와 메모는 같은 모양을 본다.
public protocol TransitRouter: Sendable {
    /// `arriveBy` 까지 닿는 길들. 빠른 것이 앞이다. 못 재면 빈 배열, 접속이 안 되면 throw.
    func routes(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async throws -> [TransitRoute]
}

public enum TransitFailure: Error, Sendable, Equatable {
    case network(String)
    case rejected(String)
}

/// ODsay 대중교통 길찾기 — 버스 번호·지하철역·환승·요금까지 준다 (`searchPubTransPathT`).
///
/// 키는 사람이 설정에 넣은 것이다 (`Settings.transitKey`). 시각을 받지 않는 API 라 시간표가
/// 아니라 **평균 소요 시간**이다 — 그래서 출발 시각은 도착에서 거꾸로 세고, 알림은 그보다
/// 앞서 건다 (`RoutePlanner`).
public struct ODsayRouter: TransitRouter {
    public let key: String
    public init(key: String) { self.key = key }

    static let endpoint = "https://api.odsay.com/v1/api/searchPubTransPathT"
    static let timeout: TimeInterval = 15

    public func routes(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async throws -> [TransitRoute] {
        var parts = URLComponents(string: Self.endpoint)
        parts?.queryItems = [
            .init(name: "apiKey", value: key),
            .init(name: "SX", value: String(origin.geo.longitude)), .init(name: "SY", value: String(origin.geo.latitude)),
            .init(name: "EX", value: String(destination.geo.longitude)), .init(name: "EY", value: String(destination.geo.latitude)),
            .init(name: "OPT", value: "0"), .init(name: "SearchPathType", value: "0"), .init(name: "lang", value: "0"),
            .init(name: "output", value: "json"),
        ]
        guard let url = parts?.url else { return [] }
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: Self.timeout))
        } catch {
            throw TransitFailure.network(error.localizedDescription)
        }
        return try Self.parse(data, origin: origin.name, destination: destination.name, arriveBy: arriveBy)
    }

    // MARK: 응답 읽기

    struct Envelope: Decodable {
        var result: Result?
    }
    struct Result: Decodable {
        var path: [Path]?
    }
    struct Path: Decodable {
        var pathType: Int?
        var info: Info?
        var subPath: [SubPath]?
    }
    struct Info: Decodable {
        var totalTime: Int?
        var payment: Int?
    }
    struct SubPath: Decodable {
        var trafficType: Int?
        var sectionTime: Int?
        var stationCount: Int?
        var lane: [Lane]?
        var startName: String?
        var endName: String?
        var way: String?
        var endExitNo: String?
    }
    struct Lane: Decodable {
        var name: String?
        var busNo: String?
        var type: Int?
    }

    /// 응답을 길로. 오류 봉투(`{"error": …}`)는 배열이기도 객체이기도 해서 따로 본다.
    static func parse(_ data: Data, origin: String, destination: String, arriveBy: Date) throws -> [TransitRoute] {
        if let message = errorMessage(in: data) { throw TransitFailure.rejected(message) }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw TransitFailure.rejected("응답을 읽지 못했습니다") }
        return (envelope.result?.path ?? []).compactMap { path -> TransitRoute? in
            guard let minutes = path.info?.totalTime, minutes > 0 else { return nil }
            let legs = (path.subPath ?? []).compactMap(leg)
            guard legs.contains(where: \.rides) else { return nil }
            return TransitRoute(origin: origin, destination: destination, minutes: minutes,
                                arrive: arriveBy, fare: path.info?.payment, legs: legs)
        }
    }

    static func leg(_ sub: SubPath) -> TransitRoute.Leg? {
        let minutes = sub.sectionTime ?? 0
        switch sub.trafficType {
        case 3:
            // 0분 걷기는 갈아타는 자리의 빈 구간이다 — 줄로 세우지 않는다.
            return minutes > 0 ? TransitRoute.Leg(mode: .walk, minutes: minutes) : nil
        case 2:
            let lane = sub.lane?.first
            return TransitRoute.Leg(mode: .bus, minutes: minutes, line: lane?.busNo, kind: lane?.type.flatMap(busKind),
                                    from: sub.startName, to: sub.endName, stops: sub.stationCount)
        case 1:
            let lane = sub.lane?.first
            return TransitRoute.Leg(mode: .subway, minutes: minutes, line: lane?.name.map(subwayLine),
                                    from: sub.startName, to: sub.endName, stops: sub.stationCount,
                                    heading: sub.way.flatMap { $0.isEmpty || $0 == "null" ? nil : $0 },
                                    exit: sub.endExitNo.flatMap { $0.isEmpty || $0 == "null" ? nil : $0 })
        default:
            return nil
        }
    }

    /// ODsay 의 버스 종류 코드.
    static func busKind(_ type: Int) -> String? {
        switch type {
        case 1: return "일반"
        case 2: return "좌석"
        case 3: return "마을"
        case 4: return "직행좌석"
        case 5: return "공항"
        case 6: return "간선급행"
        case 10: return "외곽"
        case 11: return "간선"
        case 12: return "지선"
        case 13: return "순환"
        case 14: return "광역"
        case 15: return "급행"
        case 16: return "관광"
        case 20: return "농어촌"
        case 22: return "시외"
        default: return nil
        }
    }

    /// 「수도권 2호선」→「2호선」. 도시 이름은 카드에 둘 자리가 없다.
    static func subwayLine(_ name: String) -> String {
        var line = name
        for prefix in ["수도권 ", "수도권", "부산 ", "대구 ", "대전 ", "광주 ", "인천 "] where line.hasPrefix(prefix) {
            line = String(line.dropFirst(prefix.count))
            break
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    static func errorMessage(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] else { return nil }
        let box: [String: Any]?
        if let list = error as? [[String: Any]] { box = list.first } else { box = error as? [String: Any] }
        let message = (box?["message"] as? String) ?? (box?["msg"] as? String)
        let code = box?["code"].map { "\($0)" }
        switch message {
        case nil: return "ODsay 가 거절했습니다" + (code.map { " (\($0))" } ?? "")
        case let text?: return text
        }
    }
}

/// 애플 지도 — 키 없이 늘 있다. 대중교통은 **걸리는 시간만** 알려 주고(구간은 못 준다),
/// 자동차 길은 택시의 시간·거리가 된다.
public struct AppleRouter: TransitRouter {
    public init() {}

    public func routes(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async throws -> [TransitRoute] {
        var found: [TransitRoute] = []
        if let transit = await transit(from: origin, to: destination, arriveBy: arriveBy) { found.append(transit) }
        return found
    }

    func transit(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async -> TransitRoute? {
        let request = Self.request(from: origin, to: destination, arriveBy: arriveBy, transport: .transit)
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return nil }
        let minutes = Int((eta.expectedTravelTime / 60).rounded(.up))
        guard minutes > 0 else { return nil }
        return TransitRoute(origin: origin.name, destination: destination.name, minutes: minutes, arrive: arriveBy,
                            legs: [TransitRoute.Leg(mode: .transit, minutes: minutes)])
    }

    /// 택시 — 자동차 길의 시간·거리에 서울 요금표를 대어 어림한다. 길을 못 재면 직선거리로 어림한다.
    public func taxi(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async -> TransitRoute {
        let request = Self.request(from: origin, to: destination, arriveBy: arriveBy, transport: .automobile)
        var minutes: Int
        var distance: Int
        if let response = try? await MKDirections(request: request).calculate(), let route = response.routes.first {
            minutes = Int((route.expectedTravelTime / 60).rounded(.up))
            distance = Int(route.distance.rounded())
        } else {
            // 직선거리의 1.3배를 시속 22km 로 — 도심의 어림.
            let straight = origin.location.distance(from: destination.location)
            distance = Int((straight * 1.3).rounded())
            minutes = max(3, Int((Double(distance) / 1000 / 22 * 60).rounded(.up)))
        }
        minutes = max(1, minutes)
        let fare = TaxiFare.estimate(meters: distance, minutes: minutes, at: arriveBy.addingTimeInterval(-Double(minutes) * 60))
        return TransitRoute(origin: origin.name, destination: destination.name, minutes: minutes, arrive: arriveBy, fare: nil,
                            legs: [TransitRoute.Leg(mode: .taxi, minutes: minutes, fare: fare, distance: distance)])
    }

    static func request(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date,
                        transport: MKDirectionsTransportType) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: origin.location, address: nil)
        request.destination = MKMapItem(location: destination.location, address: nil)
        request.transportType = transport
        request.arrivalDate = arriveBy
        return request
    }
}

/// 서울 중형 택시 요금의 어림 — 기본 4,800원(1.6km), 131m 마다 100원, 시속 15km 아래에서는 30초마다 100원.
/// 밤(22시~4시)은 두 할 더. 다른 도시는 조금 다르지만 「약」이 붙는 값이다.
public enum TaxiFare {
    public static func estimate(meters: Int, minutes: Int, at depart: Date, calendar: Calendar = .current) -> Int {
        var fare = 4800
        if meters > 1600 { fare += (meters - 1600) / 131 * 100 }
        // 도심 평균 시속을 20km 안팎으로 보고, 그보다 더 걸리는 분마다 100원 — 30초 단위의 반쯤을 친다.
        let expectedMinutes = Double(meters) / 1000 / 20 * 60
        let slowMinutes = max(0, Double(minutes) - expectedMinutes)
        fare += Int(slowMinutes) * 100
        let hour = calendar.component(.hour, from: depart)
        if hour >= 22 || hour < 4 { fare = Int(Double(fare) * 1.2) }
        return (fare + 50) / 100 * 100
    }
}

/// 셋을 합친 것 — 대중교통은 네이버 지도 웹(키 없음)이 먼저, 그것이 답하지 않으면 ODsay(키가 있으면).
/// 택시는 늘 애플. 둘 다 없으면 택시만 남는다.
public struct RouteFinder: Sendable {
    public var transitKey: String?
    public init(transitKey: String? = nil) {
        self.transitKey = transitKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? transitKey : nil
    }

    public func find(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async throws -> [TransitRoute] {
        let apple = AppleRouter()
        async let taxi = apple.taxi(from: origin, to: destination, arriveBy: arriveBy)
        var routes = (try? await NaverWebRouter().routes(from: origin, to: destination, arriveBy: arriveBy)) ?? []
        if routes.isEmpty, let transitKey {
            routes = try await ODsayRouter(key: transitKey).routes(from: origin, to: destination, arriveBy: arriveBy)
        }
        routes.append(await taxi)
        return routes
    }

    /// 고른 길을 약속에 맞춰 되잰다 — 시간표를 아는 길(네이버)만. 아니면 nil 이고 고른 그대로 적는다.
    public func refine(_ route: TransitRoute, from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async -> TransitRoute? {
        guard route.provider == "naver" else { return nil }
        return await NaverWebRouter().refine(route, from: origin, to: destination, arriveBy: arriveBy)
    }
}
