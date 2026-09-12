import Testing
@testable import LazyMemoCore

/// 첫소리 규칙 그 자체 (`HangulInitials`). 서랍의 시험(`DrawerSearchTests`)이
/// 같은 규칙을 종이에 대고 묻는다 — 여기서는 규칙이 자리와 무관하게 서는지 본다.
@Suite("한글 첫소리")
struct HangulInitialsTests {
    @Test("첫소리만 뽑는다 — 한글이 아닌 글자는 그대로")
    func extractsInitials() {
        #expect(HangulInitials.initials(of: "장보기 목록") == "ㅈㅂㄱ ㅁㄹ")
        #expect(HangulInitials.initials(of: "iOS 회의") == "iOS ㅎㅇ")
        #expect(HangulInitials.initials(of: "꽃값") == "ㄲㄱ")
    }

    @Test("통째로 첫소리일 때만 첫소리 질의다")
    func recognizesInitialsQuery() {
        #expect(HangulInitials.isInitialsQuery("ㅈㅂㄱ"))
        #expect(HangulInitials.isInitialsQuery(" ㅊㄱ "))
        #expect(!HangulInitials.isInitialsQuery("ㅈ보기"))
        #expect(!HangulInitials.isInitialsQuery("장보기"))
        #expect(!HangulInitials.isInitialsQuery(""))
        // 모음만으로는 아무것도 찾지 않는다 — 초성이 아니다.
        #expect(!HangulInitials.isInitialsQuery("ㅏ"))
    }

    @Test("보통 글자로 먼저 견주고, 첫소리로도 견준다")
    func matchesText() {
        #expect(HangulInitials.matches("장보기 목록\n우유", query: "장보"))
        #expect(HangulInitials.matches("장보기 목록\n우유", query: "ㅈㅂㄱ"))
        #expect(HangulInitials.matches("치과 예약", query: "ㅊㄱ"))
        #expect(HangulInitials.matches("iOS 회의", query: "IOS"))
        #expect(!HangulInitials.matches("장보기", query: "치과"))
        #expect(!HangulInitials.matches("장보기", query: "ㅈ보기"))
        #expect(HangulInitials.matches("아무거나", query: "   "))
    }
}
