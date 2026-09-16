import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoPlaces

/// 진짜 접속 — `LAZYMEMO_LIVE_ROUTES=1` 일 때만 돈다. 평소 `swift test` 는 건너뛴다.
/// ODsay 는 `LAZYMEMO_ODSAY_KEY` 가 있을 때만.
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
    }

    @Test("이름 → 좌표, 그리고 애플의 대중교통 시간·택시")
    func appleRoutes() async throws {
        let destination = try #require(await PlaceLocator.locate("https://naver.me/GFB1MHiW"))
        let origin = try #require(await PlaceLocator.locate("석촌고분역에서 출발", near: destination.geo))
        #expect(origin.name == "석촌고분역")

        let arrive = Date().addingTimeInterval(6 * 3600)
        let routes = try await RouteFinder(transitKey: ProcessInfo.processInfo.environment["LAZYMEMO_ODSAY_KEY"]).find(from: origin, to: destination, arriveBy: arrive)
        for route in routes { print(RouteNote.render(route)) }
        #expect(routes.contains { $0.kind == .taxi })
    }
}
