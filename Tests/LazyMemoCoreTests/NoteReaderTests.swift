import Foundation
import Testing
@testable import LazyMemoCore

@Suite("NoteReader — 문이 몇이든 읽는 규칙은 하나다")
struct NoteReaderTests {
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 10))!
    }

    private func read(_ text: String, place: String? = nil) -> ParsedNote {
        NoteReader.read(text, place: place, now: now)
    }

    @Test("날짜만 있으면 날짜를 읽고 본문에서 덜어낸다")
    func readsDate() {
        let note = read("내일 장보기")
        #expect(note.due == CalendarDate(year: 2026, month: 8, day: 29))
        #expect(note.body == "장보기")
        #expect(note.place == nil)
    }

    @Test("장소만 있으면 장소를 읽고 본문에서 덜어낸다")
    func readsPlace() {
        let note = read("커피 @광화문")
        #expect(note.place == "광화문")
        #expect(note.body == "커피")
        #expect(!note.body.contains("@"))
    }

    @Test("날짜와 장소가 함께 있어도 둘 다 읽는다")
    func readsBoth() {
        let note = read("내일 3시 치과 @강남역")
        #expect(note.at != nil)
        #expect(note.place == "강남역")
        #expect(note.body == "치과")
    }

    @Test("통째로 주소면 본문을 그대로 둔다 — 덜어내면 남는 것이 없다")
    func keepsWholeAddress() {
        let note = read("서울 강남구 테헤란로 152")
        #expect(note.place == "서울 강남구 테헤란로 152")
        #expect(note.body == "서울 강남구 테헤란로 152")
    }

    @Test("밖에서 준 장소가 글에서 읽은 것을 이긴다")
    func explicitPlaceWins() {
        // 단축어가 「현재 위치」를 물려 보냈다면 그것이 사실이다.
        let note = read("커피 @광화문", place: "서울 종로구 세종대로 175")
        #expect(note.place == "서울 종로구 세종대로 175")
        // 밖에서 정해 준 이상 글은 손대지 않는다.
        #expect(note.body == "커피 @광화문")
    }

    @Test("읽을 것이 없으면 글을 그대로 둔다")
    func leavesPlainText() {
        let note = read("우유 사기")
        #expect(note.body == "우유 사기")
        #expect(note.due == nil)
        #expect(note.at == nil)
        #expect(note.place == nil)
    }

    @Test("덜어내서 남는 것이 없으면 원문을 지킨다 — 빈 메모를 만들지 않는다")
    func neverEmpties() {
        #expect(!read("내일").body.isEmpty)
        #expect(!read("@강남역").body.isEmpty)
    }

    @Test("지도 앱이 공유한 글은 첫 줄이 장소고 본문은 이름표만 뗀다")
    func readsMapShare() {
        let note = read("[네이버 지도]\n스타벅스 강남R점\n서울 강남구 강남대로 390\nhttps://naver.me/5abcdef")
        #expect(note.place == "스타벅스 강남R점")
        #expect(note.body == "스타벅스 강남R점\n서울 강남구 강남대로 390\nhttps://naver.me/5abcdef")
        #expect(note.geo == nil)   // 짧은 링크에는 좌표가 없다
        #expect(note.due == nil)
    }

    @Test("지도 주소에 적힌 이름과 좌표를 읽고 본문은 그대로 둔다 — 카드가 붙어야 한다")
    func readsMapURL() {
        let raw = "https://www.google.com/maps/place/강남역/@37.4979,127.0276,17z"
        let note = read(raw)
        #expect(note.place == "강남역")
        #expect(note.geo == Coordinate("37.4979,127.0276"))
        #expect(note.body == raw)
    }

    @Test("손으로 찍은 @장소가 지도 주소의 이름을 이기되 좌표는 가져온다")
    func atWordBeatsMapName() {
        let note = read("내일 3시 치과 @강남역 https://maps.apple.com/?ll=37.4979,127.0276&q=Gangnam")
        #expect(note.place == "강남역")
        #expect(note.geo == Coordinate("37.4979,127.0276"))
        #expect(note.at != nil)
    }

    @Test("밖에서 장소를 주면 지도 주소는 읽지 않는다 — 그 이름과 이 좌표가 다른 곳일 수 있다")
    func explicitPlaceSkipsMapURL() {
        let note = read("https://maps.apple.com/?ll=37.4979,127.0276&q=강남역", place: "서울 종로구 세종대로 175")
        #expect(note.place == "서울 종로구 세종대로 175")
        #expect(note.geo == nil)
    }

    @Test("들어온 덩이에서도 같은 규칙으로 읽는다")
    func readsInboundNote() {
        let note = NoteReader.read(InboundNote(text: "내일 3시 치과"), now: now)
        #expect(note.at != nil)
        #expect(note.body == "치과")
    }
}
