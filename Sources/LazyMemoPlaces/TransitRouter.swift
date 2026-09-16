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

/// 둘을 합친 것 — 대중교통은 네이버 지도 웹(키 없음), 택시는 늘 애플. 네이버가 답하지 않으면 택시만 남는다.
public struct RouteFinder: Sendable {
    public init() {}

    public func find(from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async throws -> [TransitRoute] {
        let apple = AppleRouter()
        async let taxi = apple.taxi(from: origin, to: destination, arriveBy: arriveBy)
        var routes = (try? await NaverWebRouter().routes(from: origin, to: destination, arriveBy: arriveBy)) ?? []
        routes.append(await taxi)
        return routes
    }

    /// 고른 길을 약속에 맞춰 되잰다 — 시간표를 아는 길(네이버)만. 아니면 nil 이고 고른 그대로 적는다.
    public func refine(_ route: TransitRoute, from origin: LocatedPlace, to destination: LocatedPlace, arriveBy: Date) async -> TransitRoute? {
        guard route.provider == "naver" else { return nil }
        return await NaverWebRouter().refine(route, from: origin, to: destination, arriveBy: arriveBy)
    }
}
