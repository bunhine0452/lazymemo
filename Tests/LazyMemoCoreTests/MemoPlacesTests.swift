import Foundation
import Testing
@testable import LazyMemoCore

@Suite("여러 자리 — 칸 하나와 본문의 @낱말")
struct MemoPlacesTests {
    @Test("본문의 @낱말을 전부, 차례대로, 한 번씩 읽는다")
    func parsesAll() {
        let all = PlaceParser.parseAll("@강남역 에서 보고 @홍대입구 로, 다시 @강남역")
        #expect(all.map(\.place) == ["강남역", "홍대입구"])
        #expect(PlaceParser.parse("치과 @강남역")?.place == "강남역")
    }

    @Test("칸의 자리가 첫 장, 본문의 자리가 그 뒤 — 겹치면 한 번")
    func ordersPlaces() {
        let geo = Coordinate(latitude: 37.4979, longitude: 127.0276)
        let memo = Memo(place: "강남역", geo: geo, body: "치과 다음 @홍대입구 그리고 @강남역")
        let places = MemoPlaces.of(memo)
        #expect(places.map(\.name) == ["강남역", "홍대입구"])
        #expect(places[0].geo == geo)
        #expect(places[1].geo == nil)
    }

    @Test("칸이 비고 좌표만 있으면 그 좌표는 본문 첫 자리의 것 — 이름 없는 카드를 세우지 않는다")
    func geoBelongsToFirstBodyPlace() throws {
        let geo = try #require(Coordinate(latitude: 37.556, longitude: 126.910))
        let memo = Memo(geo: geo, body: "저녁 약속\n@망원역 에서 보고 @홍대입구역 으로")
        let places = MemoPlaces.of(memo)
        #expect(places.map(\.name) == ["망원역", "홍대입구역"])
        #expect(places[0].geo == geo)
        #expect(places[1].geo == nil)
        // 본문에도 자리가 없으면 좌표 자체가 자리다.
        #expect(MemoPlaces.of(Memo(geo: geo, body: "여기")).map(\.name) == [geo.description])
    }

    @Test("자리가 없으면 빈 목록 — 메일 주소는 자리가 아니다")
    func noPlaces() {
        #expect(MemoPlaces.of(Memo(body: "foo@bar.com 에 회신")).isEmpty)
    }
}
