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
    /// 웹 검색 창구. 없으면(시험·렌더) `webAnswer` 는 「웹에 닿지 못했습니다」다.
    private let web: (any WebSearcher)?
    private let profile: ModelProfile
    private let limits: Limits
    private var generation = 0
    private var live: [AssistantRequest.ID: Int] = [:]

    public init(provider: any LocalModelProvider, evidence: any EvidenceSource, web: (any WebSearcher)? = nil,
                profile: ModelProfile, limits: Limits = Limits()) {
        self.provider = provider
        self.evidence = evidence
        self.web = web
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
            let ready = await provider.availability == .ready
            // 묻기·다듬기·브리핑은 모델이 있어야 한다. 시키기는 아래에서 말만으로 끝날 수 있으니 먼저 해 본다.
            // 웹은 모델이 없어도 검색 결과 셋을 그대로 보여 줄 수 있다.
            guard ready || request.task == .command || request.task == .webAnswer else { _ = await emit(.failed(.modelUnavailable)); return }

            let (selected, gathered) = try await gather(request)
            guard await emit(.evidence(gathered)) else { return }
            // 다듬기는 열린 메모가 있거나, 글을 직접 들고 왔거나 — 웹의 답을 「정리해서 남기기」는 아직 메모가 아닌 글을 다듬는다.
            if request.task == .tidy, selected == nil, request.userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = await emit(.failed(.noEvidence)); return
            }
            // 걸리는 메모가 한 장도 없으면 모델을 부를 것도 없다 — 바로 「찾지 못했습니다」, 화면은 웹을 권한다.
            if request.task == .answer, gathered.isEmpty { _ = await emit(.failed(.noEvidence)); return }
            if request.task == .webAnswer, !ready {
                var plain = AssistantResult.answer(OutputValidator.plainWebAnswer(gathered))
                _ = await finish(&plain, request: request, emit: emit)
                return
            }

            // 시키기는 사용자의 말만으로 정해지는 일이 많다 — 「금요일 10시에 다시 알려줘」는 파서가 읽고
            // 열린 메모가 대상이다. 그러면 모델을 올리지도 부르지도 않는다(즉시·결정적). 모델은 말이 낯설 때만 —
            // 그래서 폰에 2.4GB 를 받지 않아도 시키기는 된다.
            if request.task == .command,
               var result = CommandResolver.resolve(nil, request: request, selected: selected, candidates: gathered).map(AssistantResult.action),
               !Self.needsModel(result) {
                _ = await finish(&result, request: request, emit: emit)
                return
            }
            guard ready else { _ = await emit(.failed(.modelUnavailable)); return }
            guard await emit(.preparing) else { return }

            var calls = 0
            var text: String
            do {
                try await provider.prepare(profile)
                text = try await generate(request, selected: selected, evidence: gathered, repair: nil, calls: &calls, emit: emit)
            } catch let failure as AssistantFailure where request.task == .webAnswer && !gathered.isEmpty {
                // 웹의 결과는 이미 손에 있다 — 모델이 넘어졌다고 그것까지 버리지 않는다. 모델 없는
                // 기기와 같은 길로 결과 셋을 그대로 보인다 (2026-09-18, 폰에서 엔진이 첫 prefill 에 넘어짐).
                guard case .provider = failure else { throw failure }
                var plain = AssistantResult.answer(OutputValidator.plainWebAnswer(gathered))
                _ = await finish(&plain, request: request, emit: emit)
                return
            }
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
            // 시각이 정해진 것부터 — 근거는 여섯 장까지라, 뒤에 선 것은 모델이 보지 못한다.
            found = try await evidence.today(now: request.now).sorted { a, b in
                switch (a.at, b.at) {
                case (let x?, let y?): return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return a.updated > b.updated
                }
            }
        case .command where selected != nil:
            // 열린 메모가 대상이다. 다른 메모를 보여 주면 모델이 그리로 끌려간다.
            break
        case .answer, .command:
            let query = request.userText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty, reads < limits.maxReads {
                reads += 1
                found = try await evidence.search(query, limit: limits.candidateLimit)
            }
        case .webAnswer:
            // 검색어는 앱이 만든다(「검색해줘」·물음표만 뗀다). 결과는 다섯 줄 — 4096 토큰 안에 넉넉하다.
            guard let web else { throw AssistantFailure.webUnavailable }
            let hits: [WebHit]
            do { hits = try await web.search(WebQuery.make(from: request.userText), limit: limits.maxEvidence - 1) }
            catch let failure as AssistantFailure { throw failure }
            catch { throw AssistantFailure.webUnavailable }
            if hits.isEmpty { throw AssistantFailure.webEmpty }
            return (nil, hits.map(Evidence.init(hit:)))
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
            // JSON 은 다 받아야 뜻이 있다 — 화면은 다듬기의 글만 보이고 나머지 조각은 세기만 한다 (`AssistantEvent.textDelta`).
            guard await emit(.textDelta(delta)) else { throw CancellationError() }
        }
        // 개발용 — 모델이 실제로 뭐라 했는지. `LAZYMEMO_ASSISTANT_TRACE=1` 일 때만, stderr 로.
        if ProcessInfo.processInfo.environment["LAZYMEMO_ASSISTANT_TRACE"] != nil {
            FileHandle.standardError.write("[assistant \(request.task.rawValue)] \(request.userText)\n<<< \(text)\n".data(using: .utf8)!)
        }
        return text
    }

    private func validate(_ text: String, request: AssistantRequest, evidence: [Evidence]) -> AssistantResult? {
        switch request.task {
        case .answer:
            return OutputValidator.answer(text, allowed: evidence, question: request.userText).map(AssistantResult.answer)
        case .webAnswer:
            return OutputValidator.answer(text, allowed: evidence, question: WebQuery.make(from: request.userText)).map(AssistantResult.answer)
        case .brief:
            return OutputValidator.brief(text, allowed: evidence, request: request).map(AssistantResult.brief)
        case .command:
            let selected = request.selectedMemoID.flatMap { id in evidence.first { $0.memoID == id } }
            return OutputValidator.action(text, request: request, selected: selected, candidates: evidence).map(AssistantResult.action)
        case .tidy:
            let cleaned = ClaudePrompts.clean(text)
            return cleaned.isEmpty ? nil : .tidied(cleaned)
        }
    }

    /// 모델 없이 낸 답이 「무엇을 할지 모르겠다」뿐이면 모델의 읽기를 한 번 빌린다.
    static func needsModel(_ result: AssistantResult) -> Bool {
        guard case .action(let action) = result, action.kind == .ask else { return false }
        return action.question == CommandResolver.questions.unsupported
    }

    private func finish(_ result: inout AssistantResult, request: AssistantRequest, emit: @Sendable (AssistantEvent) async -> Bool) async -> Bool {
        if case .action(let action) = result {
            guard await emit(.proposedAction(action)) else { return false }
        }
        if case .answer(let a) = result, !a.found, a.text.isEmpty {
            return await emit(.failed(request.task == .webAnswer ? .webEmpty : .noEvidence))
        }
        return await emit(.completed(result))
    }
}
