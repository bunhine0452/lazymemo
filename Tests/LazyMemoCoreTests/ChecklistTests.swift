import Foundation
import Testing
@testable import LazyMemoCore

@Suite("Checklist — 체크상자 줄을 글로 찾는다")
struct ChecklistTests {
    let body = "장보기\n- [ ] 우유\n- [x] 계란\n  * [ ]  두부 \n- 김\n"

    @Test("줄 차례대로, 상자 뒤의 글과 체크 여부")
    func linesInOrder() {
        #expect(Checklist.lines(in: body) == [
            .init(text: "우유", done: false), .init(text: "계란", done: true), .init(text: "두부", done: false),
        ])
        #expect(Checklist.lines(in: "그냥 글\n- 점 목록") == [])
    }

    @Test("글로 찾아 괄호 안 한 글자만 뒤집는다 — 자리가 밀려도 같은 줄")
    func togglesByLabel() throws {
        let edit = try #require(Checklist.toggle("두부", done: false, in: body))
        #expect(edit.replacement == "x")
        let after = Checklist.applying(edit, to: body)
        #expect(after == "장보기\n- [ ] 우유\n- [x] 계란\n  * [x]  두부 \n- 김\n")
        // 앞에 줄이 끼어들어도 글은 그대로다.
        let shifted = "머리말 한 줄\n" + body
        #expect(Checklist.applying(try #require(Checklist.toggle("두부", done: false, in: shifted)), to: shifted)
            == "머리말 한 줄\n" + after)
        // 체크된 것을 풀기도 같은 문이다.
        #expect(Checklist.toggle("계란", done: true, in: body)?.replacement == " ")
    }

    @Test("없는 글·이미 체크된 칸·상자 아닌 줄은 nil — 엉뚱한 줄을 뒤집지 않는다")
    func refusesWhatIsNotThere() {
        #expect(Checklist.toggle("우유 2개", done: false, in: body) == nil)
        #expect(Checklist.toggle("계란", done: false, in: body) == nil)
        #expect(Checklist.toggle("김", done: false, in: body) == nil)
        #expect(Checklist.toggle("우유", done: false, in: "") == nil)
    }

    @Test("같은 글이 두 줄이면 첫 줄만")
    func firstOfDuplicates() throws {
        let twice = "- [ ] 우유\n- [ ] 우유\n"
        let edit = try #require(Checklist.toggle("우유", done: false, in: twice))
        #expect(Checklist.applying(edit, to: twice) == "- [x] 우유\n- [ ] 우유\n")
    }
}
