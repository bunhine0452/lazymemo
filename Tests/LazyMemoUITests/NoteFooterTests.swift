import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

@Suite("NoteFooter")
struct NoteFooterTests {
    @Test("장소만 있어도 아래 줄이 선다 — 적은 것이 화면에서 사라지면 안 된다")
    func placeAloneShowsFooter() {
        #expect(NoteFooter.isVisible(for: Memo(place: "강남역", body: "커피")))
        #expect(NoteFooter.isVisible(for: Memo(geo: Coordinate("37.4979,127.0276"), body: "여기")))
    }

    @Test("아무것도 없으면 줄도 없다 — 기본 상태는 글자와 종이뿐이다")
    func bareMemoHasNoFooter() {
        #expect(!NoteFooter.isVisible(for: Memo(body: "장보기")))
    }

    @Test("날짜와 태그는 그대로다")
    func keepsExistingRules() {
        #expect(NoteFooter.isVisible(for: Memo(due: CalendarDate(year: 2026, month: 9, day: 1))))
        #expect(NoteFooter.isVisible(for: Memo(tags: ["병원"])))
    }

    @Test("좌표만 있으면 좌표를 적는다")
    func labelsCoordinateWhenNameless() {
        #expect(NoteFooter.placeLabel(for: Memo(place: "강남역")) == "강남역")
        #expect(NoteFooter.placeLabel(for: Memo(geo: Coordinate("37.4979,127.0276")))
            == "37.4979,127.0276")
        #expect(NoteFooter.placeLabel(for: Memo(body: "장보기")) == nil)
    }
}

@Suite("RowWords")
struct RowWordsTests {
    @Test("시각·제목·장소가 한 줄에 선다 — 나가기 전에 필요한 전부다")
    func joinsAll() {
        #expect(RowWords.line(clock: "14:00", title: "치과", place: "강남역")
            == "14:00 치과 · 강남역")
    }

    @Test("없는 것은 자리를 차지하지 않는다")
    func omitsMissing() {
        #expect(RowWords.line(clock: "", title: "치과", place: "강남역") == "치과 · 강남역")
        #expect(RowWords.line(clock: "14:00", title: "치과", place: nil) == "14:00 치과")
        #expect(RowWords.line(clock: "", title: "치과", place: "") == "치과")
    }

    @Test("소리로는 가운뎃점 대신 쉼표를 읽는다 (§14.11)")
    func spokenUsesComma() {
        #expect(RowWords.spoken(clock: "14:00", title: "치과", place: "강남역")
            == "14:00 치과, 강남역")
        #expect(RowWords.spoken(clock: "", title: "치과", place: nil) == "치과")
    }
}
