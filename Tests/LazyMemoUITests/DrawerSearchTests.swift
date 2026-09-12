import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 서랍에서 **찾는 일** — 거르기가 한 칸 어긋나면 종이가 없어진 것으로 보인다.
///
/// 그림으로는 「서랍에 없다」와 「안 찾아졌다」가 구별되지 않는다. 둘 다 빈
/// 화면이다. 그래서 규칙을 뷰 밖에 두고 여기서 못 박는다 (`DrawerSearch`).
@Suite("서랍에서 찾기")
struct DrawerSearchTests {

    private func paper(_ body: String) -> Memo { Memo(body: body) }

    @Test("빈 질의는 아무것도 거르지 않는다 — 찾기는 분류가 아니다 (§16.1)")
    func emptyQueryKeepsEverything() {
        let papers = [paper("장보기"), paper("치과")]
        #expect(DrawerSearch.filter(papers, query: "").count == 2)
        #expect(DrawerSearch.filter(papers, query: "   ").count == 2)
    }

    @Test("제목으로 찾는다")
    func findsByTitle() {
        #expect(DrawerSearch.matches(paper("장보기 목록\n우유"), query: "장보"))
    }

    /// 사람은 제목을 기억하지 못하는 만큼이나 본문의 한 낱말을 기억한다.
    @Test("본문으로도 찾는다 — 제목만 보면 절반을 못 찾는다")
    func findsByBody() {
        #expect(DrawerSearch.matches(paper("장보기 목록\n- 우유\n- 계란"), query: "계란"))
    }

    @Test("대소문자를 가리지 않는다")
    func ignoresCase() {
        #expect(DrawerSearch.matches(paper("iOS 회의"), query: "ios"))
        #expect(DrawerSearch.matches(paper("ios 회의"), query: "IOS"))
    }

    @Test("걸리지 않는 것은 남지 않는다")
    func rejectsMisses() {
        #expect(!DrawerSearch.matches(paper("장보기"), query: "치과"))
    }

    // MARK: 첫소리

    /// 한글 입력에서 「장보」는 여섯 번의 타건이다. 첫소리를 빼면 사용자는
    /// 그것을 다 쳐야 하고, 그러면 찾기는 «게으른 사람» 의 것이 아니게 된다.
    @Test("첫소리로 찾는다 — ㅈㅂㄱ 가 장보기를 찾는다")
    func findsByInitials() {
        #expect(DrawerSearch.matches(paper("장보기 목록"), query: "ㅈㅂㄱ"))
        #expect(DrawerSearch.matches(paper("치과 예약"), query: "ㅊㄱ"))
    }

    @Test("첫소리는 한 글자씩 좁혀진다")
    func initialsNarrowOneAtATime() {
        let papers = [paper("장보기"), paper("전세 계약"), paper("치과")]
        #expect(DrawerSearch.filter(papers, query: "ㅈ").count == 2)
        #expect(DrawerSearch.filter(papers, query: "ㅈㅂ").count == 1)
    }

    @Test("겹받침·된소리 음절의 첫소리도 바르게 뽑는다")
    func initialsHandleComplexSyllables() {
        #expect(DrawerSearch.initials(of: "꽃값") == "ㄲㄱ")
        #expect(DrawerSearch.initials(of: "빵") == "ㅃ")
        #expect(DrawerSearch.initials(of: "하") == "ㅎ")
    }

    @Test("한글이 아닌 글자는 첫소리에서 그대로 남는다")
    func initialsLeaveNonHangulAlone() {
        #expect(DrawerSearch.initials(of: "iOS 회의") == "iOS ㅎㅇ")
    }

    /// 섞인 것을 해석하기 시작하면 「ㄱ」가 낱말인지 첫소리인지 사람이
    /// 예측할 수 없다. **통째로 초성일 때만** 첫소리로 읽는다.
    @Test("섞인 질의는 첫소리로 읽지 않는다")
    func mixedQueriesAreLiteral() {
        #expect(!DrawerSearch.isInitialsQuery("ㅈ보기"))
        #expect(!DrawerSearch.matches(paper("장보기"), query: "ㅈ보기"))
    }

    // MARK: 말

    @Test("찾는 중이면 몇 장이 걸렸는지 말한다")
    func countsWhatMatched() {
        #expect(DrawerSearch.summary(query: "장", found: 3) == "3장")
    }

    /// 못 찾았다는 말은 **무더기가 있던 자리**가 더 크게 한다 (`DrawerView.empty`).
    /// 같은 말을 한 화면에서 두 번 하면 둘 다 배경이 된다.
    @Test("한 장도 못 찾았을 때는 바닥 줄이 말하지 않는다 — 가운데가 말한다")
    func staysSilentWhenTheEmptyViewSpeaks() {
        #expect(DrawerSearch.summary(query: "치과", found: 0) == nil)
    }

    @Test("찾는 중이 아니면 아무 말도 하지 않는다")
    func staysSilentWhenNotSearching() {
        #expect(DrawerSearch.summary(query: "", found: 8) == nil)
        #expect(DrawerSearch.summary(query: "  ", found: 8) == nil)
    }

    @Test("걸러도 차례는 그대로다 — 같은 메모를 두 곳에서 다르게 늘어놓지 않는다")
    func filteringKeepsOrder() {
        let papers = [paper("장보기"), paper("치과"), paper("장부 정리")]
        let found = DrawerSearch.filter(papers, query: "장")
        #expect(found.map(\.title) == ["장보기", "장부 정리"])
    }
}
