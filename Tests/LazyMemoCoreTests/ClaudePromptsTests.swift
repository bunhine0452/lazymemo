import Foundation
import Testing
@testable import LazyMemoCore

@Suite("ClaudePrompts")
struct ClaudePromptsTests {
    @Test("코드펜스를 걷어낸다 — 말로 막고 코드로 한 번 더 막는다")
    func stripsFences() {
        #expect(ClaudePrompts.clean("```markdown\n장보기\n- 우유\n```") == "장보기\n- 우유")
        #expect(ClaudePrompts.clean("```\n장보기\n```") == "장보기")
    }

    @Test("앞뒤 빈 줄을 턴다")
    func trims() {
        #expect(ClaudePrompts.clean("\n\n장보기\n\n") == "장보기")
    }

    @Test("멀쩡한 답은 건드리지 않는다")
    func leavesPlainAnswers() {
        let answer = "## 장보기\n- [ ] 우유\n- [ ] 계란"
        #expect(ClaudePrompts.clean(answer) == answer)
    }

    @Test("본문 안의 코드펜스는 남긴다 — 첫 줄이 펜스일 때만 걷는다")
    func keepsInnerFences() {
        let answer = "메모\n\n```sh\nls\n```"
        #expect(ClaudePrompts.clean(answer) == answer)
    }

    @Test("다듬기 문장이 뜻을 바꾸지 말라고 못 박는다")
    func tidyPromptForbidsInvention() {
        let ko = ClaudePrompts.tidy(locale: Locale(identifier: "ko_KR"))
        #expect(ko.contains("뜻을 바꾸지 마라"))
        #expect(ko.contains("없는 내용을 더하지 마라"))
        #expect(ko.contains("코드펜스도 붙이지 마라"))
        let en = ClaudePrompts.tidy(locale: Locale(identifier: "en_US"))
        #expect(en.contains("Do not change the meaning"))
        #expect(en.contains("code fence"))
    }
}
