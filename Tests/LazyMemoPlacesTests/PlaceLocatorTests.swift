import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoPlaces

@Suite("TaxiFare — 서울 요금표의 어림")
struct TaxiFareTests {
    @Test("기본요금 안이면 4,800원, 밤에는 두 할 더")
    func taxi() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 14))!
        let night = cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 23))!
        #expect(TaxiFare.estimate(meters: 1000, minutes: 3, at: day, calendar: cal) == 4800)
        #expect(TaxiFare.estimate(meters: 6200, minutes: 15, at: day, calendar: cal) == 8300)
        #expect(TaxiFare.estimate(meters: 1000, minutes: 3, at: night, calendar: cal) == 5800)
    }
}

@Suite("PlaceLocator — 사람의 말에서 자리 이름을")
struct PlaceLocatorTests {
    @Test("「…에서 출발」을 뗀다")
    func strips() {
        #expect(PlaceLocator.stripped("석촌고분역에서 출발해") == "석촌고분역")
        #expect(PlaceLocator.stripped("석촌고분역에서") == "석촌고분역")
        #expect(PlaceLocator.stripped("석촌고분역") == "석촌고분역")
        #expect(PlaceLocator.stripped("집에서 갈게") == "집")
    }

    @Test("네이버 검색의 답 — 장소가 먼저, 없으면 주소. x 가 경도다")
    func naverSearch() {
        let place = Data(#"{"place":[{"title":"강남역 2호선","x":"127.0276242","y":"37.4979526","ctg":"지하철,전철"}],"address":[]}"#.utf8)
        #expect(NaverPlaceSearch.parse(place) == LocatedPlace(name: "강남역 2호선", geo: Coordinate(latitude: 37.4979526, longitude: 127.0276242)!))
        let address = Data(#"{"place":[],"address":[{"title":"서울 송파구 송파대로 386","x":"127.110371241","y":"37.502281181"}]}"#.utf8)
        #expect(NaverPlaceSearch.parse(address)?.name == "서울 송파구 송파대로 386")
        #expect(NaverPlaceSearch.parse(Data(#"{"place":[],"address":[]}"#.utf8)) == nil)
        #expect(NaverPlaceSearch.parse(Data("not json".utf8)) == nil)
    }

    @Test("네이버 장소 번호와 이름표를 읽는다")
    func naver() {
        #expect(ShortMapLink.naverPlaceID(in: URL(string: "https://map.naver.com/p/entry/place/1041643501?placePath=%2Fhome")!) == "1041643501")
        #expect(ShortMapLink.naverPlaceID(in: URL(string: "https://m.place.naver.com/restaurant/36943350/home")!) == "36943350")
        #expect(ShortMapLink.naverPlaceID(in: URL(string: "https://m.map.naver.com/appLink.naver?pinId=1041643501&pinType=site&id=1041643501")!) == "1041643501")
        #expect(ShortMapLink.naverPlaceID(in: URL(string: "https://map.kakao.com/link/map/a,37.5,127.0")!) == nil)
        #expect(ShortMapLink.cleanedNaverTitle("투파인드피터 잠실점 : 네이버") == "투파인드피터 잠실점")
        #expect(ShortMapLink.cleanedNaverTitle("투파인드피터 잠실점 : 네이버\u{1C}") == "투파인드피터 잠실점")
        #expect(ShortMapLink.ogTitle(in: #"<meta property="og:title" content="스타벅스 송파사거리점 : 네이버">"#) == "스타벅스 송파사거리점 : 네이버")
    }
}
