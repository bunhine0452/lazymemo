import Foundation
import LazyMemoCore

/// 검색 → 근거 묶기 → 생성 → 검증까지. **실행은 하지 않는다** — `ProposedAction` 을 내놓을 뿐이고,
/// 저장은 정책을 거친 앱 코드(`#action-executor`)가 한다 (명세 §3).
///
/// 요청마다 세대 번호를 올린다. 취소되거나 새 요청이 오면 옛 세대의 이벤트는 밖으로 나가지 않는다.
public actor AssistantCoordinator {
    public struct Limits: Sendable {
        public var maxEvidence = 6
        public var maxReads = 4
        public var maxModelCalls = 3
        public var candidateLimit = 20
        public init() {}
    }

    private let provider: any LocalModelProvider
    private let evidence: any EvidenceSource
    private let profile: ModelProfile
    private let limits: Limits
    private var generation = 0
    private var live: [AssistantRequest.ID: Int] = [:]

    public init(provider: any LocalModelProvider, evidence: any EvidenceSource, profile: ModelProfile, limits: Limits = Limits()) {
        self.provider = provider
        self.evidence = evidence
        self.profile = profile
        self.limits = limits
    }

    public func cancel(_ requestID: AssistantRequest.ID) async {
        live[requestID] = nil
        await provider.cancel(requestID: requestID)
    }

    public func run(_ request: AssistantRequest) -> AsyncStream<AssistantEvent> {
        generation += 1
        let gen = generation
        live[request.id] = gen
        return AsyncStream { continuation in
            let task = Task {
                await self.perform(request, gen: gen) { event in
                    guard await self.isCurrent(request.id, gen) else { return false }
                    continuation.yield(event)
                    return true
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func isCurrent(_ id: AssistantRequest.ID, _ gen: Int) -> Bool { live[id] == gen }

    private func perform(_ request: AssistantRequest, gen: Int, emit: @Sendable (AssistantEvent) async -> Bool) async {
        do {
            guard await emit(.loading) else { return }
            guard await provider.availability == .ready else { _ = await emit(.failed(.modelUnavailable)); return }
            try await provider.prepare(profile)

            let (selected, gathered) = try await gather(request)
            guard await emit(.evidence(gathered)) else { return }
            if request.task == .tidy, selected == nil { _ = await emit(.failed(.noEvidence)); return }

            var calls = 0
            var text = try await generate(request, selected: selected, evidence: gathered, repair: nil, calls: &calls, emit: emit)
            guard isCurrent(request.id, gen) else { return }

            if var result = validate(text, request: request, evidence: gathered) {
                _ = await finish(&result, request: request, emit: emit)
                return
            }
            // 명세 §3: 잘못된 구조는 한 번만 교정 요청. 다시 실패하면 변경 없이 오류.
            text = try await generate(request, selected: selected, evidence: gathered,
                                      repair: "앞선 답의 모양이 맞지 않았다. " + AssistantPrompts.jsonRule, calls: &calls, emit: emit)
            guard isCurrent(request.id, gen) else { return }
            if var result = validate(text, request: request, evidence: gathered) {
                _ = await finish(&result, request: request, emit: emit)
            } else {
                _ = await emit(.failed(.malformedOutput))
            }
        } catch let failure as AssistantFailure {
            _ = await emit(.failed(failure))
        } catch is CancellationError {
            _ = await emit(.failed(.cancelled))
        } catch {
            _ = await emit(.failed(.provider(String(describing: error))))
        }
    }

    /// 열린 메모 먼저, 그다음 검색. 읽기 횟수는 `maxReads` 안.
    private func gather(_ request: AssistantRequest) async throws -> (Evidence?, [Evidence]) {
        var reads = 0
        var selected: Evidence?
        if let id = request.selectedMemoID {
            reads += 1
            if let memo = try? await evidence.get(id) { selected = Evidence(memo: memo) }
        }
        var found: [Memo] = []
        switch request.task {
        case .tidy:
            break
        case .brief:
            reads += 1
            found = try await evidence.today(now: request.now)
        case .answer, .command:
            let query = request.userText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty, reads < limits.maxReads {
                reads += 1
                found = try await evidence.search(query, limit: limits.candidateLimit)
            }
        }
        var list = selected.map { [$0] } ?? []
        for memo in found where memo.id != selected?.memoID && list.count < limits.maxEvidence {
            list.append(Evidence(memo: memo))
        }
        return (selected, list)
    }

    private func generate(
        _ request: AssistantRequest, selected: Evidence?, evidence: [Evidence], repair: String?,
        calls: inout Int, emit: @Sendable (AssistantEvent) async -> Bool
    ) async throws -> String {
        calls += 1
        if calls > limits.maxModelCalls { throw AssistantFailure.budgetExceeded("모델 호출 \(limits.maxModelCalls)회") }
        let now = AssistantPrompts.iso(request.now, request.timeZone)
        var user = AssistantPrompts.user(request, selected: selected, evidence: evidence)
        if let repair { user += "\n\n" + repair }
        let prompt = AssistantPrompt(
            requestID: request.id, system: AssistantPrompts.system(for: request.task, now: now), user: user,
            maxOutputTokens: request.outputBudget, jsonSchema: AssistantPrompts.jsonSchema(for: request.task))
        var text = ""
        for try await delta in provider.stream(prompt) {
            try Task.checkCancellation()
            text += delta
            // JSON 은 다 받아야 뜻이 있다 — 부분 도구 토큰을 흘리지 않는다. 글은 흘린다.
            if request.task == .tidy { guard await emit(.textDelta(delta)) else { throw CancellationError() } }
        }
        return text
    }

    private func validate(_ text: String, request: AssistantRequest, evidence: [Evidence]) -> AssistantResult? {
        switch request.task {
        case .answer:
            return OutputValidator.answer(text, allowed: Set(evidence.map(\.memoID))).map(AssistantResult.answer)
        case .brief:
            return OutputValidator.brief(text, allowed: evidence).map(AssistantResult.brief)
        case .command:
            return OutputValidator.action(text, request: request, evidence: evidence).map(AssistantResult.action)
        case .tidy:
            let cleaned = ClaudePrompts.clean(text)
            return cleaned.isEmpty ? nil : .tidied(cleaned)
        }
    }

    private func finish(_ result: inout AssistantResult, request: AssistantRequest, emit: @Sendable (AssistantEvent) async -> Bool) async -> Bool {
        if case .action(let action) = result {
            guard await emit(.proposedAction(action)) else { return false }
        }
        if case .answer(let a) = result, !a.found, a.text.isEmpty {
            return await emit(.failed(.noEvidence))
        }
        return await emit(.completed(result))
    }
}
