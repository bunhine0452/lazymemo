import Foundation
import Testing
@testable import LazyMemoCore

@Suite("Coordinate")
struct CoordinateTests {
    @Test("`위도,경도` 한 줄을 읽는다")
    func readsPair() {
        let seoul = Coordinate("37.4979,127.0276")
        #expect(seoul?.latitude == 37.4979)
        #expect(seoul?.longitude == 127.0276)
    }

    @Test("공백이 섞여 있어도 읽는다 — 사람이 손으로 적을 수 있다")
    func toleratesSpaces() {
        #expect(Coordinate(" 37.4979 , 127.0276 ") == Coordinate("37.4979,127.0276"))
    }

    @Test("지구 밖 좌표는 읽지 않는다")
    func rejectsOutOfRange() {
        #expect(Coordinate("91.0,127.0") == nil)
        #expect(Coordinate("37.5,181.0") == nil)
        #expect(Coordinate("37.5") == nil)
        #expect(Coordinate("여기") == nil)
        #expect(Coordinate("37.5,127.0,3") == nil)
    }

    @Test("적은 그대로 되쓴다 — 파일이 정본이다")
    func roundTripsAsText() {
        #expect(Coordinate("37.4979,127.0276")?.description == "37.4979,127.0276")
        #expect(Coordinate("0,0")?.description == "0,0")
        #expect(Coordinate("-33.8688,151.2093")?.description == "-33.8688,151.2093")
    }
}

@Suite("메모의 장소")
struct MemoPlaceTests {
    private let sample = """
        ---
        id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
        created: 2026-08-28T16:29:50+09:00
        updated: 2026-08-28T16:31:00+09:00
        at: 2026-09-01T14:00:00+09:00
        place: 강남역 3번 출구
        geo: 37.4979,127.0276
        color: yellow
        pinned: false
        ---
        치과 예약
        """

    @Test("place 와 geo 를 읽는다")
    func decodesPlace() throws {
        let memo = try MemoFile.decode(sample)
        #expect(memo.place == "강남역 3번 출구")
        #expect(memo.geo == Coordinate("37.4979,127.0276"))
        #expect(memo.hasPlace)
    }

    @Test("왕복해도 변하지 않는다")
    func roundTrips() throws {
        let decoded = try MemoFile.decode(sample)
        let again = try MemoFile.decode(
            MemoFile.encode(decoded, timeZone: TimeZone(identifier: "Asia/Seoul")!)
        )
        #expect(again.place == decoded.place)
        #expect(again.geo == decoded.geo)
    }

    @Test("좌표 없이 장소 이름만 있어도 된다 — 지도에 검색어로 넘긴다")
    func placeWithoutCoordinate() throws {
        let memo = try MemoFile.decode("""
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            place: 광화문 교보문고
            ---
            책 사기
            """)
        #expect(memo.place == "광화문 교보문고")
        #expect(memo.geo == nil)
        #expect(memo.hasPlace)
    }

    @Test("읽지 못한 geo 는 지우지 않고 원문 그대로 남긴다")
    func keepsMalformedGeo() throws {
        let text = """
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            geo: 어딘가
            ---
            본문
            """
        let memo = try MemoFile.decode(text)
        #expect(memo.geo == nil)
        #expect(memo.preserved.map(\.key) == ["geo"])
        #expect(MemoFile.encode(memo).contains("geo: 어딘가"))
    }

    @Test("장소는 자리를 바꾸지 않는다 — 달력이 맡는 것은 여전히 날짜뿐이다")
    func placeDoesNotSchedule() throws {
        let memo = Memo(place: "강남역", body: "커피")
        #expect(memo.hasPlace)
        #expect(!memo.isScheduled)
        #expect(memo.scheduledDate() == nil)
    }
}
