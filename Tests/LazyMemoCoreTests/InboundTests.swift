import Foundation
import Testing
@testable import LazyMemoCore

@Suite("InboundLink — lazymemo://add")
struct InboundLinkTests {
    private func note(_ raw: String) -> InboundNote? {
        URL(string: raw).flatMap(InboundLink.note(from:))
    }

    @Test("글을 받는다")
    func acceptsText() {
        #expect(note("lazymemo://add?text=%EC%9E%A5%EB%B3%B4%EA%B8%B0")
            == InboundNote(text: "장보기"))
        #expect(note("lazymemo://add?text=%EC%B9%98%EA%B3%BC&place=%EA%B0%95%EB%82%A8%EC%97%AD")
            == InboundNote(text: "치과", place: "강남역"))
    }

    @Test("`lazymemo:add` 처럼 빗금 없이 와도 받는다")
    func acceptsPathForm() {
        #expect(note("lazymemo:add?text=%EB%A9%94%EB%AA%A8") == InboundNote(text: "메모"))
    }

    @Test("**글자만 받는다** — 파일도 명령도 받지 않는다")
    func acceptsNothingButText() {
        // 할 수 있는 일을 늘리지 않는 것이 유일하게 확실한 방어다.
        #expect(note("lazymemo://run?cmd=rm%20-rf%20~") == nil)
        #expect(note("lazymemo://open?file=/etc/passwd") == nil)
        #expect(note("lazymemo://add?file=/etc/passwd") == nil)
        #expect(note("lazymemo://add") == nil)
    }

    @Test("다른 스킴은 우리 문이 아니다")
    func rejectsOtherSchemes() {
        #expect(note("https://example.com/add?text=hi") == nil)
        #expect(note("file:///etc/passwd") == nil)
        #expect(note("javascript:alert(1)") == nil)
    }

    @Test("빈 글은 종이를 만들지 않는다")
    func rejectsEmpty() {
        #expect(note("lazymemo://add?text=") == nil)
        #expect(note("lazymemo://add?text=%20%20%20") == nil)
    }

    @Test("메모가 아니라 파일만 한 것은 받지 않는다")
    func rejectsHuge() {
        let huge = String(repeating: "가", count: InboundNote.textLimit + 1)
        #expect(InboundNote.make(text: huge) == nil)
        #expect(InboundNote.make(text: String(repeating: "가", count: InboundNote.textLimit)) != nil)
    }

    @Test("장소만 너무 길면 장소만 버린다 — 글은 살린다")
    func dropsOverlongPlaceOnly() {
        let note = InboundNote.make(
            text: "치과", place: String(repeating: "가", count: InboundNote.placeLimit + 1)
        )
        #expect(note == InboundNote(text: "치과", place: nil))
    }
}

@Suite("InboundCommand — 터미널에서")
struct InboundCommandTests {
    @Test("인자가 없으면 MCP 서버로 선다 — 이미 등록한 사람의 연동을 깨지 않는다")
    func defaultsToServe() {
        #expect(InboundCommand.parse(["lazymemo-mcp"]) == .serve)
        #expect(InboundCommand.parse([]) == .serve)
    }

    @Test("add 는 남은 말을 한 줄로 잇는다")
    func addsJoinedText() {
        #expect(InboundCommand.parse(["lazymemo-mcp", "add", "장보기"])
            == .add(InboundNote(text: "장보기")))
        #expect(InboundCommand.parse(["lazymemo-mcp", "add", "우유", "사기"])
            == .add(InboundNote(text: "우유 사기")))
    }

    @Test("--place 는 글에서 빠진다")
    func readsPlace() {
        #expect(InboundCommand.parse(["lazymemo-mcp", "add", "치과", "--place", "강남역"])
            == .add(InboundNote(text: "치과", place: "강남역")))
        #expect(InboundCommand.parse(["lazymemo-mcp", "add", "--place", "강남역", "치과"])
            == .add(InboundNote(text: "치과", place: "강남역")))
    }

    @Test("적을 것이 없으면 빈 종이를 만들지 않는다")
    func rejectsEmptyAdd() {
        #expect(InboundCommand.parse(["lazymemo-mcp", "add"]) == .empty)
        #expect(InboundCommand.parse(["lazymemo-mcp", "add", "   "]) == .empty)
    }

    @Test("나머지는 나머지라고 말한다")
    func namesTheRest() {
        #expect(InboundCommand.parse(["lazymemo-mcp", "help"]) == .help)
        #expect(InboundCommand.parse(["lazymemo-mcp", "--version"]) == .version)
        #expect(InboundCommand.parse(["lazymemo-mcp", "지우기"]) == .unknown("지우기"))
    }
}
