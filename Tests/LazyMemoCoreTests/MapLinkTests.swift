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

@Suite("MapLink — 지도 주소에서 거꾸로 읽기")
struct MapLinkReadTests {
    private let gangnam = Coordinate("37.4979,127.0276")

    @Test("우리가 만든 주소는 그대로 되읽힌다")
    func roundTrip() {
        let url = MapLink.url(place: "강남역 3번 출구", geo: gangnam)!
        #expect(MapLink.read(url.absoluteString) == MapLink.Spot(place: "강남역 3번 출구", geo: gangnam))
        // 좌표만으로 만든 주소는 이름 자리에 좌표가 들어 있다 — 그건 이름이 아니다.
        let bare = MapLink.url(place: nil, geo: gangnam)!
        #expect(MapLink.read(bare.absoluteString) == MapLink.Spot(place: nil, geo: gangnam))
    }

    @Test("애플 지도의 공유 주소 — coordinate 와 name")
    func apple() {
        let spot = MapLink.read("https://maps.apple.com/place?coordinate=37.4979,127.0276&name=강남역&place-id=I1")
        #expect(spot == MapLink.Spot(place: "강남역", geo: gangnam))
    }

    @Test("구글 — /place/<이름>/@중심 에서 이름과 좌표를 읽는다")
    func googlePlace() {
        let spot = MapLink.read("https://www.google.com/maps/place/Gangnam+Station/@37.4979,127.0276,17z")
        #expect(spot == MapLink.Spot(place: "Gangnam Station", geo: gangnam))
        #expect(MapLink.read("https://www.google.com/maps/place/강남역/@37.4979,127.0276,17z")?.place == "강남역")
    }

    @Test("구글 — !3d!4d 핀이 @ 중심을 이긴다")
    func googlePinBeatsCenter() {
        let spot = MapLink.read(
            "https://www.google.com/maps/place/강남역/@37.5,127.1,15z/data=!4m6!3m5!1s0x1!8m2!3d37.4979!4d127.0276!16s"
        )
        #expect(spot?.geo == gangnam)
    }

    @Test("구글 — ?q=위도,경도 와 /search/")
    func googleQuery() {
        #expect(MapLink.read("https://maps.google.com/maps?q=37.4979,127.0276") == MapLink.Spot(geo: gangnam))
        #expect(MapLink.read("https://maps.google.com/?q=37.4979,127.0276") == MapLink.Spot(geo: gangnam))
        #expect(MapLink.read("https://www.google.com/maps/search/스타벅스+강남R점")?.place == "스타벅스 강남R점")
        #expect(MapLink.read("https://www.google.co.kr/maps/search/?api=1&query=강남역")?.place == "강남역")
    }

    @Test("카카오 — link/map/<이름>,<위도>,<경도> 와 link/search")
    func kakao() {
        #expect(MapLink.read("https://map.kakao.com/link/map/강남역,37.4979,127.0276")
            == MapLink.Spot(place: "강남역", geo: gangnam))
        #expect(MapLink.read("https://map.kakao.com/link/to/강남역,37.4979,127.0276")?.geo == gangnam)
        #expect(MapLink.read("https://map.kakao.com/link/search/강남역") == MapLink.Spot(place: "강남역"))
        // 풀린 주소 — urlX/urlY 는 위경도가 아니라 읽지 않고, 이름만 남는다.
        #expect(MapLink.read("https://map.kakao.com/?urlX=506102.0&urlY=1110678.0&name=강남역")
            == MapLink.Spot(place: "강남역"))
    }

    @Test("카카오 — 장소 id 만 있는 주소에는 읽을 것이 없다")
    func kakaoPlaceID() {
        #expect(MapLink.read("https://map.kakao.com/link/map/27246495") == nil)
        #expect(MapLink.read("https://place.map.kakao.com/27246495") == nil)
    }

    @Test("네이버 — 검색어는 읽고, c= 화면 중심은 읽지 않는다")
    func naver() {
        #expect(MapLink.read("https://map.naver.com/p/search/강남역/place/11583300?c=15.00,0,0,0,dh")
            == MapLink.Spot(place: "강남역"))
        #expect(MapLink.read("https://map.naver.com/p/entry/place/11583300?c=127.0276,37.4979,15,0,0,0,dh") == nil)
        #expect(MapLink.read("https://m.place.naver.com/place/11583300/home") == nil)
    }

    @Test("짧은 공유 링크에는 아무것도 적혀 있지 않다 — 지도인 줄은 안다")
    func shortLinks() {
        for raw in ["https://naver.me/5abcdef", "https://kko.to/abcdef", "https://maps.app.goo.gl/abcdef"] {
            #expect(MapLink.read(raw) == nil)
            #expect(MapLink.isMap(raw))
        }
    }

    @Test("지도가 아닌 주소는 지도가 아니다")
    func notMaps() {
        #expect(MapLink.read("https://www.google.com/search?q=강남역") == nil)
        #expect(MapLink.read("https://youtu.be/abc") == nil)
        #expect(!MapLink.isMap("https://www.google.com/search?q=강남역"))
        #expect(!MapLink.isMap("https://youtu.be/abc"))
        #expect(MapLink.isMap("https://www.google.com/maps/place/강남역"))
    }

    @Test("글 속의 첫 지도 주소에서 읽는다")
    func inText() {
        let text = "내일 여기 https://youtu.be/abc 그리고 https://maps.apple.com/?ll=37.4979,127.0276&q=강남역 에서"
        #expect(MapLink.spot(in: text) == MapLink.Spot(place: "강남역", geo: gangnam))
        #expect(MapLink.spot(in: "지도 없음 https://youtu.be/abc") == nil)
    }

    @Test("네이버 짧은 링크가 풀린 옛 모양 — lat·lng 가 핀이고 title 이 이름이다")
    func naverPinLink() {
        let spot = MapLink.read("https://map.naver.com/?menu=location&appMenu=location&version=2&lng=127.0031828&title=%EC%84%BC%ED%8A%B8%EB%9F%B4%EC%8B%9C%ED%8B%B0%ED%84%B0%EB%AF%B8%EB%84%90(%ED%98%B8%EB%82%A8%EC%84%A0)&pinType=site&pinId=11815569&app=Y&lat=37.5049856")
        #expect(spot?.place == "센트럴시티터미널(호남선)")
        #expect(spot?.geo == Coordinate("37.5049856,127.0031828"))
    }
}
