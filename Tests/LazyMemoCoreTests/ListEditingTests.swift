import Foundation
import Testing
@testable import LazyMemoCore

/// 목록 줄의 ⏎ 와 체크상자 뒤집기 — 맥·폰 편집기가 함께 읽는 규칙 (`ListEditing`).
@Suite("목록 줄 편집")
struct ListEditingTests {
    /// `|` 자리에 커서를 두고 ⏎ 를 친 결과.
    private func pressReturn(_ marked: String) -> String? {
        let caret = (marked as NSString).range(of: "|")
        let text = (marked as NSString).replacingCharacters(in: caret, with: "")
        guard let edit = ListEditing.onReturn(in: text, selection: NSRange(location: caret.location, length: 0)) else {
            return nil
        }
        return (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
    }

    @Test("체크상자 줄의 ⏎ 는 빈 상자를 잇는다 — 체크된 줄에서도 새 칸은 비어 있다")
    func continuesCheckbox() {
        #expect(pressReturn("- [ ] 우유|") == "- [ ] 우유\n- [ ] ")
        #expect(pressReturn("- [x] 우유|") == "- [x] 우유\n- [ ] ")
        #expect(pressReturn("* [X] 우유|") == "* [X] 우유\n* [ ] ")
    }

    @Test("점 목록·번호·인용도 잇는다 — 번호는 하나 더한다, 모양은 사람이 쓴 그대로")
    func continuesBulletsNumbersQuotes() {
        #expect(pressReturn("- 우유|") == "- 우유\n- ")
        #expect(pressReturn("* 우유|") == "* 우유\n* ")
        #expect(pressReturn("+ 우유|") == "+ 우유\n+ ")
        #expect(pressReturn("1. 우유|") == "1. 우유\n2. ")
        #expect(pressReturn("9. 우유|") == "9. 우유\n10. ")
        #expect(pressReturn("> 옆에서 데려온 말|") == "> 옆에서 데려온 말\n> ")
        #expect(pressReturn("  - 들여쓴 것|") == "  - 들여쓴 것\n  - ")
    }

    @Test("빈 항목의 ⏎ 는 머리를 뗀다 — 목록이 끝났다")
    func emptyItemLeavesTheList() {
        #expect(pressReturn("- [ ] 우유\n- [ ] |") == "- [ ] 우유\n")
        #expect(pressReturn("- 우유\n- |") == "- 우유\n")
        #expect(pressReturn("1. 우유\n2. |") == "1. 우유\n")
        #expect(pressReturn("- [ ]|") == "", "끝 빈칸이 없어도 빈 상자다")
        // 머리 뒤에 빈칸만 있고 커서가 그 앞에 있어도 빈 항목이다.
        #expect(pressReturn("- |  ") == "")
    }

    @Test("줄 가운데의 ⏎ 는 항목을 둘로 가른다 — 뒤의 글이 새 항목이 된다")
    func splitsAnItem() {
        #expect(pressReturn("- [ ] 우유|계란") == "- [ ] 우유\n- [ ] 계란")
        #expect(pressReturn("- 우유|계란\n- 두부") == "- 우유\n- 계란\n- 두부")
    }

    @Test("머리 안에서 친 ⏎ 는 그냥 줄바꿈 — 항목을 밀어 내리는 손이다")
    func returnInsideTheHeadIsPlain() {
        #expect(pressReturn("|- [ ] 우유") == nil)
        #expect(pressReturn("- [ ]| 우유") == nil)
        #expect(pressReturn("-| 우유") == nil)
    }

    @Test("목록이 아닌 줄은 건드리지 않는다")
    func plainLinesAreLeftAlone() {
        #expect(pressReturn("우유|") == nil)
        #expect(pressReturn("## 제목|") == nil)
        #expect(pressReturn("-|") == nil, "빈칸 없는 줄표는 목록이 아니다")
        #expect(pressReturn("2026.| 9월") == nil, "네 자리 수는 번호가 아니다")
        #expect(pressReturn("|") == nil)
        #expect(pressReturn("- [ ] 우유\n|") == nil, "목록 다음의 빈 줄")
    }

    @Test("선택한 글은 새 머리로 갈아 끼운다")
    func replacesTheSelection() {
        let text = "- 우유 계란"
        let edit = ListEditing.onReturn(in: text, selection: NSRange(location: 4, length: 3))   // 「 계란」
        #expect(edit == ListEditing.Edit(range: NSRange(location: 4, length: 3), replacement: "\n- "))
        #expect(edit?.caret == 4 + 3)
    }

    @Test("글 밖의 자리는 없다고 답한다")
    func rejectsOutOfRange() {
        #expect(ListEditing.onReturn(in: "- 우유", selection: NSRange(location: 9, length: 0)) == nil)
        #expect(ListEditing.onReturn(in: "- 우유", selection: NSRange(location: 3, length: 9)) == nil)
    }

    @Test("체크상자 줄은 괄호 안 한 글자만 뒤집는다")
    func togglesTheSlot() {
        let text = "장보기\n- [ ] 우유\n- [x] 계란\n- 두부"
        let milk = (text as NSString).range(of: "우유").location
        #expect(ListEditing.toggleCheckbox(inLineContaining: milk, in: text)
            == ListEditing.Edit(range: NSRange(location: 7, length: 1), replacement: "x"))
        let eggs = (text as NSString).range(of: "계란").location
        #expect(ListEditing.toggleCheckbox(inLineContaining: eggs, in: text)
            == ListEditing.Edit(range: NSRange(location: 16, length: 1), replacement: " "))
        // 줄 머리에서 눌러도 같은 줄이다.
        #expect(ListEditing.toggleCheckbox(inLineContaining: 4, in: text)?.replacement == "x")
        // 상자가 없는 줄은 없다.
        #expect(ListEditing.toggleCheckbox(inLineContaining: 0, in: text) == nil)
        #expect(ListEditing.toggleCheckbox(inLineContaining: (text as NSString).length - 1, in: text) == nil)
    }
}
