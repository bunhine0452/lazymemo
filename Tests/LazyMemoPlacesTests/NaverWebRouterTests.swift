import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoPlaces

@Suite("NaverWebRouter — 네이버 지도 웹의 답을 길로")
struct NaverWebRouterTests {
    private var seoul: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    private func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "naver-pubtrans", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test("실제 응답(2026-09-16 석촌고분역 → 투파인드피터)에서 버스·지하철·걷기·시각·요금을 읽는다")
    func parses() throws {
        let routes = try NaverWebRouter.parse(try fixture(), origin: "석촌고분역", destination: "투파인드피터 잠실점")
        #expect(routes.count == 2)

        let bus = routes[0]
        #expect(bus.kind == .bus)
        #expect(bus.provider == "naver")
        #expect(bus.fare == 1500)
        #expect(bus.minutes == 21)
        #expect(seoul.dateComponents([.hour, .minute], from: bus.arrive) == DateComponents(hour: 18, minute: 14))
        #expect(seoul.dateComponents([.hour, .minute], from: bus.depart) == DateComponents(hour: 17, minute: 53))
        #expect(bus.legs.map(\.mode) == [.walk, .bus, .walk])
        #expect(bus.legs[1].line == "3317")
        #expect(bus.legs[1].kind == "지선")
        #expect(bus.legs[1].from == "석촌역")
        #expect(bus.legs[1].to == "잠실새내역.잠실2동주민센터")
        #expect(bus.legs[1].stops == 4)
        #expect(bus.legs[1].boardAt.map { seoul.dateComponents([.hour, .minute], from: $0) } == DateComponents(hour: 17, minute: 57))
        #expect(bus.legs[1].heading == nil, "버스의 방면은 시끄럽다 — 적지 않는다")

        let mixed = routes[1]
        #expect(mixed.kind == .mixed)
        #expect(mixed.transfers == 1)
        let subway = try #require(mixed.legs.first { $0.mode == .subway })
        #expect(subway.line == "2호선")
        #expect(subway.heading == "내선순환")
        #expect(subway.from == "잠실역")
        #expect(subway.stops == 1)
    }

    @Test("절로 적으면 승차 시각까지 남고 도로 읽힌다")
    func roundTrips() throws {
        let routes = try NaverWebRouter.parse(try fixture(), origin: "석촌고분역", destination: "투파인드피터 잠실점")
        let body = RouteNote.append(routes[0], to: "밥약속", calendar: seoul)
        #expect(body.contains("- 버스 3317 (지선) 석촌역 → 잠실새내역.잠실2동주민센터 · 9분 · 4정류장 · 17:57 승차"))
        var expected = routes[0]
        expected.provider = nil
        // 절에는 시·분만 적히므로 초는 버린다.
        expected.arrive = seoul.date(bySettingHour: 18, minute: 14, second: 0, of: expected.arrive)!
        expected.legs[1].boardAt = seoul.date(bySettingHour: 17, minute: 57, second: 0, of: expected.legs[1].boardAt!)
        #expect(RouteNote.read(body, day: expected.arrive, calendar: seoul) == expected)
    }

    @Test("모르는 탈것이 낀 길은 버리고, 답이 비면 메시지로 거절한다")
    func rejects() throws {
        let train = Data(#"{"status":"INTERCITY","message":null,"paths":[{"type":"TRAIN","duration":100,"departureTime":"2026-09-18T10:00:00","arrivalTime":"2026-09-18T11:40:00","legs":[{"steps":[{"type":"TRAIN","duration":100}]}]}]}"#.utf8)
        #expect(try NaverWebRouter.parse(train, origin: "a", destination: "b").isEmpty)
        let empty = Data(#"{"status":"ERROR","message":"경로를 찾을 수 없습니다","paths":[]}"#.utf8)
        #expect(throws: TransitFailure.rejected("경로를 찾을 수 없습니다")) {
            try NaverWebRouter.parse(empty, origin: "a", destination: "b")
        }
    }

    @Test("요청 자리 — 경도,위도,이름이고 이름의 쉼표는 뗀다")
    func point() {
        let place = LocatedPlace(name: "투파인드피터, 잠실", geo: Coordinate(latitude: 37.510894, longitude: 127.085265)!)
        #expect(NaverWebRouter.point(place) == "127.085265,37.510894,투파인드피터  잠실")
        #expect(NaverWebRouter.stamp(NaverWebRouter.date("2026-09-18T17:50:00")!) == "2026-09-18T17:50:00")
    }
}
