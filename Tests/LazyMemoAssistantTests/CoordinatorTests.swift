import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 정해진 답을 흘리는 provider. 호출 횟수와 취소를 센다.
final class MockProvider: LocalModelProvider, @unchecked Sendable {
    var answers: [String]
    private(set) var prompts: [AssistantPrompt] = []
    private(set) var cancelled: [AssistantRequest.ID] = []
    var ready = true
    /// 스트림이 열리는 순간 부른다 — 생성 도중 취소를 결정적으로 재현하려고.
    var onStream: (@Sendable () async -> Void)?
    let lock = NSLock()

    init(_ answers: [String]) { self.answers = answers }

    var availability: ModelAvailability { ready ? .ready : .notDownloaded }
    func prepare(_ profile: ModelProfile) async throws {}
    func unload() async {}
    func cancel(requestID: AssistantRequest.ID) async { lock.withLock { cancelled.append(requestID) } }

    func stream(_ prompt: AssistantPrompt) -> AsyncThrowingStream<String, Error> {
        let answer: String = lock.withLock {
            prompts.append(prompt)
            return answers.isEmpty ? "" : answers.removeFirst()
        }
        let hook = onStream
        return AsyncThrowingStream { c in
            Task {
                await hook?()
                for piece in answer.split(separator: " ", omittingEmptySubsequences: false) {
                    c.yield(String(piece) + " ")
                }
                c.finish()
            }
        }
    }
}

struct MemorySource: EvidenceSource {
    let memos: [Memo]
    func search(_ query: String, limit: Int) async throws -> [Memo] { Array(memos.prefix(limit)) }
    func get(_ id: ULID) async throws -> Memo {
        guard let m = memos.first(where: { $0.id == id }) else { throw AssistantFailure.noEvidence }
        return m
    }
    func today(now: Date) async throws -> [Memo] { memos }
}

@Suite("AssistantCoordinator")
struct CoordinatorTests {
    let dentist = Memo(due: CalendarDate(year: 2026, month: 9, day: 18),
                       at: ISO8601DateFormatter().date(from: "2026-09-18T05:00:00Z"),
                       body: "치과 예약 — 강남역 3번 출구")
    let gift = Memo(due: CalendarDate(year: 2026, month: 9, day: 20), body: "엄마 생신 선물 — 담요")
    let profile = ModelProfile(profileID: "test")

    func events(_ provider: MockProvider, _ request: AssistantRequest, memos: [Memo]) async -> [AssistantEvent] {
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: memos), profile: profile)
        var out: [AssistantEvent] = []
        for await e in await c.run(request) { out.append(e) }
        return out
    }

    @Test("답변은 보여 준 근거 id 만 인용한다 — 없는 id 는 버린다")
    func answerDropsBogusEvidence() async {
        let bogus = ULID()
        let provider = MockProvider([#"{"found": true, "answer": "담요", "evidence": ["id: \#(gift.id)", "\#(bogus)"]}"#])
        let out = await events(provider, AssistantRequest(task: .answer, userText: "엄마 선물?"), memos: [gift, dentist])
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.evidence == [gift.id])
        #expect(a.text == "담요")
    }

    @Test("근거 없이 found=true 면 답을 내지 않는다")
    func answerWithoutEvidenceFails() async {
        let provider = MockProvider([#"{"found": true, "answer": "지어낸 말", "evidence": []}"#])
        let out = await events(provider, AssistantRequest(task: .answer, userText: "?"), memos: [gift])
        #expect(out.last == .failed(.noEvidence))
    }

    @Test("「다시 알려줘」는 surface 만 바꾸고 due·at 은 keep — hash 를 함께 낸다")
    func setRecallNarrowsPatch() async {
        let provider = MockProvider([#"{"kind": "setRecall", "memoID": "\#(dentist.id)", "patch": {"surface": "2026-09-18T10:00:00+09:00", "at": "2026-09-18T10:00:00+09:00"}}"#])
        let request = AssistantRequest(task: .command, userText: "금요일 10시에 다시 알려줘", selectedMemoID: dentist.id)
        let out = await events(provider, request, memos: [dentist, gift])
        guard case .proposedAction(let action) = out.dropLast().last else { Issue.record("\(out)"); return }
        #expect(action.kind == .setRecall)
        #expect(action.memoID == dentist.id)
        #expect(action.patch.at == .keep)
        #expect(action.patch.due == .keep)
        #expect(action.patch.surface == .set(ISO8601DateFormatter().date(from: "2026-09-18T01:00:00Z")!))
        #expect(action.expectedContentHash == Evidence.hash(of: dentist.body))
    }

    @Test("빈 문자열은 clear, 없는 키는 keep")
    func clearVersusKeep() {
        let p = OutputValidator.fieldPatch(["surface": "", "folder": "일"], timeZone: .current)!
        #expect(p.surface == .clear)
        #expect(p.at == .keep)
        #expect(p.folder == .set("일"))
        #expect(p.surface.doubleOptional == .some(nil))
        #expect(p.at.doubleOptional == nil)
    }

    @Test("allowlist 밖 kind 는 한 번 교정 뒤에도 실패하면 변경 없이 오류")
    func unknownKindRepairedOnce() async {
        let provider = MockProvider([#"{"kind": "delete", "memoID": "\#(gift.id)"}"#, #"{"kind": "move", "memoID": "\#(gift.id)"}"#])
        let out = await events(provider, AssistantRequest(task: .command, userText: "이거 지워", selectedMemoID: gift.id), memos: [gift])
        #expect(out.last == .failed(.malformedOutput))
        #expect(provider.prompts.count == 2)
        #expect(!out.contains { if case .proposedAction = $0 { return true } else { return false } })
    }

    @Test("열린 메모가 있는데 다른 메모를 고르면 되묻는다")
    func selectedMemoWins() async {
        let provider = MockProvider([#"{"kind": "trash", "memoID": "\#(gift.id)"}"#])
        let out = await events(provider, AssistantRequest(task: .command, userText: "이거 지워", selectedMemoID: dentist.id), memos: [dentist, gift])
        guard case .proposedAction(let action) = out.dropLast().last else { Issue.record("\(out)"); return }
        #expect(action.kind == .ask)
        #expect(action.memoID == nil)
    }

    @Test("보여 주지 않은 메모를 대상으로 삼으면 되묻는다")
    func unknownTargetAsks() async {
        let provider = MockProvider([#"{"kind": "trash", "memoID": "\#(ULID())"}"#])
        let out = await events(provider, AssistantRequest(task: .command, userText: "지수 메모 지워"), memos: [gift])
        guard case .completed(.action(let action)) = out.last else { Issue.record("\(out)"); return }
        #expect(action.kind == .ask)
    }

    @Test("브리핑은 셋까지, 완료·휴지통·없는 id 는 빠진다")
    func briefFilters() async {
        let done = Memo(body: "- [x] 세탁소")
        let trashed = Memo(body: "헬스", deleted: Date())
        let a = Memo(body: "회의"), b = Memo(body: "점심"), c = Memo(body: "약국"), d = Memo(body: "강의")
        let json = #"{"items": [{"memoID": "\#(done.id)", "reason": ""}, {"memoID": "\#(trashed.id)", "reason": ""}, {"memoID": "\#(a.id)", "reason": "10시"}, {"memoID": "\#(a.id)", "reason": "중복"}, {"memoID": "\#(b.id)", "reason": ""}, {"memoID": "\#(c.id)", "reason": ""}, {"memoID": "\#(d.id)", "reason": ""}]}"#
        let out = await events(MockProvider([json]), AssistantRequest(task: .brief, userText: ""), memos: [done, trashed, a, b, c, d])
        guard case .completed(.brief(let items)) = out.last else { Issue.record("\(out)"); return }
        #expect(items.map(\.memoID) == [a.id, b.id, c.id])
    }

    @Test("취소된 요청은 완료 이벤트를 내지 않는다")
    func cancelSuppressesCompletion() async {
        let provider = MockProvider([#"{"found": true, "answer": "담요", "evidence": ["\#(gift.id)"]}"#])
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: [gift]), profile: profile)
        let request = AssistantRequest(task: .answer, userText: "?")
        provider.onStream = { await c.cancel(request.id) }
        var out: [AssistantEvent] = []
        for await e in await c.run(request) { out.append(e) }
        #expect(out.count == 2)
        #expect(out.first == .loading)
        if case .evidence = out.last {} else { Issue.record("\(out)") }
        #expect(provider.cancelled == [request.id])
    }

    @Test("모델이 없으면 명시 상태로 끝난다")
    func unavailable() async {
        let provider = MockProvider([])
        provider.ready = false
        let out = await events(provider, AssistantRequest(task: .answer, userText: "?"), memos: [gift])
        #expect(out == [.loading, .failed(.modelUnavailable)])
    }

    @Test("다듬기는 글자를 흘리고 코드펜스를 걷는다")
    func tidyStreams() async {
        let provider = MockProvider(["```\n- 치과 예약\n```"])
        let out = await events(provider, AssistantRequest(task: .tidy, userText: "", selectedMemoID: dentist.id), memos: [dentist])
        #expect(out.contains { if case .textDelta = $0 { return true } else { return false } })
        #expect(out.last == .completed(.tidied("- 치과 예약")))
    }
}
