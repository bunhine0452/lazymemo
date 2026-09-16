import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoPlaces

@Suite("ODsayRouter — 응답을 길로")
struct ODsayRouterTests {
    private let arrive = Date(timeIntervalSince1970: 1_789_000_000)

    /// ODsay `searchPubTransPathT` 의 모양(v1.8 레퍼런스) — 버스 하나, 지하철+버스 하나.
    private let sample = """
    {"result":{"searchType":0,"busCount":1,"subwayCount":0,"subwayBusCount":1,"pointDistance":2100,"path":[
      {"pathType":2,"info":{"trafficDistance":2500,"totalWalk":400,"totalTime":21,"payment":1500,"busTransitCount":2,"subwayTransitCount":0,"firstStartStation":"잠실여고후문","lastEndStation":"잠실새내역2번출구","totalStationCount":6},
       "subPath":[
         {"trafficType":3,"distance":120,"sectionTime":2},
         {"trafficType":2,"distance":1200,"sectionTime":8,"stationCount":4,"lane":[{"busNo":"3314","type":12,"busID":100}],"startName":"잠실여고후문","startX":127.08,"startY":37.51,"endName":"잠실역.롯데월드","endX":127.1,"endY":37.51},
         {"trafficType":3,"distance":0,"sectionTime":0},
         {"trafficType":2,"distance":900,"sectionTime":6,"stationCount":2,"lane":[{"busNo":"4318","type":11,"busID":101}],"startName":"잠실역.롯데월드","endName":"잠실새내역2번출구"},
         {"trafficType":3,"distance":280,"sectionTime":4}
       ]},
      {"pathType":3,"info":{"totalTime":19,"payment":1650},
       "subPath":[
         {"trafficType":3,"sectionTime":3},
         {"trafficType":1,"sectionTime":6,"stationCount":3,"lane":[{"name":"수도권 2호선","subwayCode":2}],"startName":"잠실","endName":"강남","way":"강남 방면","wayCode":1,"endExitNo":"2"},
         {"trafficType":2,"sectionTime":7,"stationCount":3,"lane":[{"busNo":"146","type":11}],"startName":"강남역","endName":"논현역"},
         {"trafficType":3,"sectionTime":3}
       ]}
    ]}}
    """

    @Test("버스·지하철·걷기 구간과 요금·시간을 읽는다")
    func parses() throws {
        let routes = try ODsayRouter.parse(Data(sample.utf8), origin: "석촌고분역", destination: "잠실", arriveBy: arrive)
        #expect(routes.count == 2)

        let bus = routes[0]
        #expect(bus.kind == .bus)
        #expect(bus.minutes == 21)
        #expect(bus.fare == 1500)
        #expect(bus.depart == arrive.addingTimeInterval(-21 * 60))
        // 0분 걷기(갈아타는 자리)는 줄로 세우지 않는다.
        #expect(bus.legs.map(\.mode) == [.walk, .bus, .bus, .walk])
        #expect(bus.legs[1].line == "3314")
        #expect(bus.legs[1].kind == "지선")
        #expect(bus.legs[1].from == "잠실여고후문")
        #expect(bus.legs[1].stops == 4)
        #expect(bus.legs[2].kind == "간선")
        #expect(bus.transfers == 1)
        #expect(bus.transferWords == "버스 → 버스")

        let mixed = routes[1]
        #expect(mixed.kind == .mixed)
        #expect(mixed.legs[1].mode == .subway)
        #expect(mixed.legs[1].line == "2호선")
        #expect(mixed.legs[1].heading == "강남 방면")
        #expect(mixed.legs[1].exit == "2")
        #expect(mixed.transferWords == "지하철 → 버스")
    }

    @Test("오류 봉투 — 배열이든 객체든 거절로 읽는다")
    func errors() {
        let asList = Data(#"{"error":[{"code":"500","message":"서버 내부 에러"}]}"#.utf8)
        let asObject = Data(#"{"error":{"code":"-98","msg":"검색결과가 없습니다."}}"#.utf8)
        #expect(throws: TransitFailure.rejected("서버 내부 에러")) {
            try ODsayRouter.parse(asList, origin: "a", destination: "b", arriveBy: arrive)
        }
        #expect(throws: TransitFailure.rejected("검색결과가 없습니다.")) {
            try ODsayRouter.parse(asObject, origin: "a", destination: "b", arriveBy: arrive)
        }
    }

    @Test("도시 이름을 뗀 노선 — 「수도권 2호선」은 「2호선」")
    func lines() {
        #expect(ODsayRouter.subwayLine("수도권 2호선") == "2호선")
        #expect(ODsayRouter.subwayLine("수도권 신분당선") == "신분당선")
        #expect(ODsayRouter.subwayLine("부산 1호선") == "1호선")
        #expect(ODsayRouter.busKind(12) == "지선")
        #expect(ODsayRouter.busKind(99) == nil)
    }

    @Test("택시 요금 어림 — 기본요금 안이면 4,800원, 밤에는 두 할 더")
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
