import Foundation
import Testing
@testable import LazyMemoCore

@Suite("PlaceParser — 산문 속 @낱말")
struct PlaceParserProseTests {
    @Test("@ 뒤의 낱말을 장소로 읽는다")
    func readsAtWord() {
        #expect(PlaceParser.parse("치과 @강남역")?.place == "강남역")
        #expect(PlaceParser.parse("@광화문 에서 만나기")?.place == "광화문")
    }

    @Test("본문에서 덜어낼 조각을 함께 준다")
    func reportsPhrase() {
        let result = PlaceParser.parse("내일 3시 치과 @강남역")
        #expect(result?.phrases == ["@강남역"])
        #expect(NaturalDateParser.strip(result!.phrases, from: "내일 3시 치과 @강남역")
            == "내일 3시 치과")
    }

    @Test("메일 주소를 장소로 읽지 않는다 — @ 앞이 글자면 장소가 아니다")
    func ignoresEmail() {
        #expect(PlaceParser.parse("메일 보내기 foo@bar.com") == nil)
        #expect(PlaceParser.parse("bunhine0452@gmail.com 로 회신") == nil)
    }

    @Test("@ 뒤에 낱말이 없으면 아무것도 하지 않는다")
    func ignoresBareAt() {
        #expect(PlaceParser.parse("@") == nil)
        #expect(PlaceParser.parse("값이 @ 이다") == nil)
        #expect(PlaceParser.parse("@ 강남역") == nil)
    }

    @Test("문장부호는 장소 이름에 넣지 않는다")
    func trimsPunctuation() {
        #expect(PlaceParser.parse("@강남역, 3번 출구")?.place == "강남역")
        #expect(PlaceParser.parse("@강남역.")?.place == "강남역")
    }

    @Test("산문 안의 주소는 읽지 않는다 — 오탐은 안 읽느니만 못하다")
    func doesNotGuessAddressInProse() {
        #expect(PlaceParser.parse("인구 조사로 3일 걸린다") == nil)
        #expect(PlaceParser.parse("집으로 3분") == nil)
        #expect(PlaceParser.parse("서울 강남구 테헤란로 152 에 갔다가 밥 먹고 영화 보고 집에 옴") == nil)
    }
}

@Suite("PlaceParser — 통째로 주소일 때만")
struct PlaceParserAddressTests {
    @Test("도로명 주소 한 줄을 읽는다")
    func readsRoadAddress() {
        #expect(PlaceParser.address("서울특별시 강남구 테헤란로 152") == "서울특별시 강남구 테헤란로 152")
        #expect(PlaceParser.address("강남구 테헤란로 152") == "강남구 테헤란로 152")
        #expect(PlaceParser.address("경기도 성남시 분당구 판교로 235") == "경기도 성남시 분당구 판교로 235")
    }

    @Test("지번 주소도 읽는다")
    func readsLotAddress() {
        #expect(PlaceParser.address("서울 강남구 역삼동 123-45") == "서울 강남구 역삼동 123-45")
    }

    @Test("앞뒤 공백을 털고 돌려준다")
    func trims() {
        #expect(PlaceParser.address("  강남구 테헤란로 152  ") == "강남구 테헤란로 152")
    }

    @Test("주소 뒤에 붙은 것은 함께 둔다 — 지도에 그대로 넘긴다")
    func keepsTrailingDetail() {
        #expect(PlaceParser.address("서울 강남구 테헤란로 152 강남파이낸스센터")
            == "서울 강남구 테헤란로 152 강남파이낸스센터")
    }

    @Test("주소가 아니면 읽지 않는다")
    func rejectsNonAddress() {
        #expect(PlaceParser.address("장보기") == nil)
        #expect(PlaceParser.address("테헤란로 152") == nil)          // 시·군·구가 없다
        #expect(PlaceParser.address("인구 조사로 3일") == nil)        // 숫자가 번지가 아니다
        #expect(PlaceParser.address("강남구 테헤란로") == nil)        // 번지가 없다
    }

    @Test("여러 줄이거나 너무 길면 읽지 않는다 — 그건 주소가 아니라 글이다")
    func rejectsProse() {
        #expect(PlaceParser.address("서울 강남구 테헤란로 152\n두 번째 줄") == nil)
        #expect(PlaceParser.address(String(repeating: "가", count: 60) + " 강남구 테헤란로 152") == nil)
    }
}
