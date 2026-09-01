import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MapLink")
struct MapLinkTests {
    private func items(_ url: URL?) -> [URLQueryItem] {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return [] }
        return parts.queryItems ?? []
    }

    @Test("이름만 있으면 검색어로 넘긴다")
    func nameOnly() {
        let url = MapLink.url(place: "광화문 교보문고", geo: nil)
        #expect(url?.host() == "maps.apple.com")
        #expect(items(url) == [URLQueryItem(name: "q", value: "광화문 교보문고")])
    }

    @Test("좌표가 있으면 그 점으로 가되 이름도 함께 넘긴다")
    func nameAndCoordinate() {
        let url = MapLink.url(place: "강남역 3번 출구", geo: Coordinate("37.4979,127.0276"))
        #expect(items(url).contains(URLQueryItem(name: "ll", value: "37.4979,127.0276")))
        #expect(items(url).contains(URLQueryItem(name: "q", value: "강남역 3번 출구")))
    }

    @Test("좌표만 있으면 좌표가 곧 이름이다 — 이름 없는 핀을 만들지 않는다")
    func coordinateOnly() {
        let url = MapLink.url(place: nil, geo: Coordinate("37.4979,127.0276"))
        #expect(items(url).contains(URLQueryItem(name: "q", value: "37.4979,127.0276")))
    }

    @Test("장소가 없으면 주소도 없다")
    func nothingToOpen() {
        #expect(MapLink.url(place: nil, geo: nil) == nil)
        #expect(MapLink.url(place: "", geo: nil) == nil)
        #expect(MapLink.url(for: Memo(body: "장보기")) == nil)
    }

    @Test("메모에서 바로 만든다")
    func fromMemo() {
        let memo = Memo(place: "강남역", body: "커피")
        #expect(items(MapLink.url(for: memo)) == [URLQueryItem(name: "q", value: "강남역")])
    }
}
