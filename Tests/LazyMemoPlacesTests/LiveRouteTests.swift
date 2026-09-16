import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoPlaces

/// 진짜 접속 — `LAZYMEMO_LIVE_ROUTES=1` 일 때만 돈다. 평소 `swift test` 는 건너뛴다.
@Suite("가는 길 — 실제 접속", .enabled(if: ProcessInfo.processInfo.environment["LAZYMEMO_LIVE_ROUTES"] == "1"))
struct LiveRouteTests {
    @Test("네이버 짧은 링크 → 이름과 좌표")
    func naverShortLink() async throws {
        let found = try #require(await PlaceLocator.locate("https://naver.me/GFB1MHiW"))
        #expect(found.name == "투파인드피터 잠실점")
        #expect(abs(found.geo.latitude - 37.5109) < 0.01)
        #expect(abs(found.geo.longitude - 127.0853) < 0.01)

        let origin = try #require(await PlaceLocator.locate("https://naver.me/58NGrhb8 여기서 출발해"))
        #expect(origin.name == "스타벅스 송파사거리점")

        // 2026-09-16 사용자가 네이버 지도에서 바로 복사한 것 — 한 줄로 붙은 채로도 자리와 좌표가 나와야 한다.
        let glued = "[네이버지도]센트럴시티터미널(호남선)서울 서초구 신반포로 176 센트럴시티https://naver.me/GFsUdKBr"
        let note = NoteReader.read(glued)
        #expect(note.place == "센트럴시티터미널(호남선)")
        let terminal = try #require(await PlaceLocator.locate("https://naver.me/GFsUdKBr"))
        #expect(terminal.name.contains("센트럴시티"))
        #expect(abs(terminal.geo.latitude - 37.5048) < 0.01)
    }

    @Test("이름 → 좌표, 네이버 지도 웹의 버스·지하철, 애플의 택시 — 그리고 약속에 맞춘 되재기")
    func routes() async throws {
        let destination = try #require(await PlaceLocator.locate("https://naver.me/GFB1MHiW"))
        let origin = try #require(await PlaceLocator.locate("석촌고분역에서 출발", near: destination.geo))
        #expect(origin.name == "석촌고분역")

        // 내일 저녁 6시 반 — 시간표가 있는 시각.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let arrive = cal.date(bySettingHour: 18, minute: 30, second: 0, of: tomorrow)!

        let finder = RouteFinder()
        let routes = try await finder.find(from: origin, to: destination, arriveBy: arrive)
        for route in routes.prefix(4) { print(RouteNote.render(route, calendar: cal)) }
        #expect(routes.contains { $0.kind == .taxi })
        let bus = try #require(routes.first { $0.kind == .bus })
        #expect(bus.legs.contains { $0.mode == .bus && $0.line != nil && $0.from != nil })

        let refined = try #require(await finder.refine(bus, from: origin, to: destination, arriveBy: arrive))
        print("되잰 것:\n" + RouteNote.render(refined, calendar: cal))
        #expect(refined.kind == .bus)
        #expect(refined.arrive <= arrive)
        #expect(refined.arrive > arrive.addingTimeInterval(-20 * 60), "너무 일찍 닿는 길이면 되재기가 헛돈 것")
    }

    @Test("지하철 — 석촌고분역 → 강남역, 지하철만인 길과 갈아타는 길, 그리고 되재기")
    func subway() async throws {
        let origin = try #require(await PlaceLocator.locate("석촌고분역"))
        let destination = try #require(await PlaceLocator.locate("강남역", near: origin.geo))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let arrive = cal.date(bySettingHour: 18, minute: 30, second: 0, of: tomorrow)!

        let finder = RouteFinder()
        let routes = try await finder.find(from: origin, to: destination, arriveBy: arrive)
        print("종류:", routes.map(\.kind.label).joined(separator: " · "))
        print("되물음:", await MainActor.run { RoutePlanner.offer(routes) })
        let subway = try #require(routes.first { $0.kind == .subway })
        print(RouteNote.render(subway, calendar: cal))
        #expect(subway.legs.contains { $0.mode == .subway && $0.line?.contains("호선") == true })
        if let mixed = routes.first(where: { $0.kind == .mixed }) {
            print("갈아타는 길 — 환승 \(mixed.transfers)회 (\(mixed.transferWords ?? "")):\n" + RouteNote.render(mixed, calendar: cal))
        }
        let refined = try #require(await finder.refine(subway, from: origin, to: destination, arriveBy: arrive))
        print("되잰 것:\n" + RouteNote.render(refined, calendar: cal))
        #expect(refined.kind == .subway)
        #expect(refined.arrive <= arrive)
    }
}
