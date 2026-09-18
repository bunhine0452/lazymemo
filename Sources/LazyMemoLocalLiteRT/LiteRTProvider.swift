import Foundation
import LazyMemoAssistant
import LiteRTLM

/// LiteRT-LM 위의 `LocalModelProvider` — 양 기기 공통. 엔진은 하나, 요청마다 새 Conversation (명세 §6~7).
///
/// - 유휴 `profile.idleUnload` 뒤 내린다. 메모리 압박이 오면 진행 중이 아닐 때 즉시 내린다.
/// - 취소는 그 요청의 Conversation 에 `cancel()`. 스트림은 곧 끝난다.
/// - 모델 로딩·추론은 이 actor 와 엔진의 스레드에서 돈다. MainActor 를 막지 않는다.
public actor LiteRTProvider: LocalModelProvider {
    public struct Sampling: Sendable {
        public var topK = 64
        public var topP: Float = 0.95
        public var temperature: Float = 1.0
        public init() {}
    }

    private let store: ModelStore
    private let manifest: ModelManifest
    private let sampling: Sampling
    private var engine: Engine?
    private var profile: ModelProfile?
    private var live: [AssistantRequest.ID: Conversation] = [:]
    private var lastUse = Date()
    private var idleTask: Task<Void, Never>?
    private var pressure: DispatchSourceMemoryPressure?

    public init(store: ModelStore, manifest: ModelManifest, sampling: Sampling = Sampling()) {
        self.store = store
        self.manifest = manifest
        self.sampling = sampling
    }

    public var availability: ModelAvailability {
        get async { await store.availability(manifest) }
    }

    public func prepare(_ profile: ModelProfile) async throws {
        self.profile = profile
        lastUse = Date()
        if engine != nil { return }
        guard await store.availability(manifest) == .ready else { throw AssistantFailure.modelUnavailable }
        let cache = store.directory(for: manifest).appending(path: "cache", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let config = try EngineConfig(
            modelPath: store.activeURL(for: manifest).path(percentEncoded: false),
            backend: .gpu, maxNumTokens: profile.contextTokens,
            cacheDir: cache.path(percentEncoded: false))
        let engine = Engine(engineConfig: config)
        try await engine.initialize()
        self.engine = engine
        armIdleTimer()
        armMemoryPressure()
    }

    public nonisolated func stream(_ prompt: AssistantPrompt) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { await self.run(prompt, continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ prompt: AssistantPrompt, _ continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        do {
            if engine == nil, let profile { try await prepare(profile) }
            guard let engine else { throw AssistantFailure.modelUnavailable }
            lastUse = Date()
            let format = try prompt.jsonSchema.map { try ResponseFormat.json(schema: $0) }
            let config = ConversationConfig(
                systemMessage: Message(prompt.system, role: .system),
                samplerConfig: try SamplerConfig(topK: sampling.topK, topP: sampling.topP, temperature: sampling.temperature),
                thinkingConfig: ThinkingConfig(enableThinking: false),
                automaticToolCalling: false,
                enableResponseFormat: format != nil)
            let conversation = try await engine.createConversation(with: config)
            live[prompt.requestID] = conversation
            defer { live[prompt.requestID] = nil; lastUse = Date() }
            for try await chunk in conversation.sendMessageStream(
                Message(prompt.user, role: .user),
                maxOutputTokens: prompt.maxOutputTokens,
                thinkingConfig: ThinkingConfig(enableThinking: false),
                responseFormat: format
            ) {
                try Task.checkCancellation()
                let piece = chunk.contents.toString
                if !piece.isEmpty { continuation.yield(piece) }
            }
            continuation.finish()
        } catch let error as LiteRTLMError {
            // 엔진의 말은 사람 말이 아니다 — 화면에는 우리말 한 줄, 원문은 로그로.
            FileHandle.standardError.write("[litert] \(error)\n".data(using: .utf8)!)
            if Self.isEngineBroken(error) {
                // 이 엔진으로는 다시 해도 같다 — 내려서 다음 부탁이 새로 올리게 한다 (자리가 나면 된다).
                live[prompt.requestID] = nil
                await unload()
            }
            continuation.finish(throwing: AssistantFailure.provider(Self.explain(error)))
        } catch {
            continuation.finish(throwing: error)
        }
    }

    /// 엔진이 올라간 채로는 고쳐지지 않는 고장인가.
    ///
    /// 아이폰에서 Gemma 의 층별 임베딩(약 1.3GB)은 **이어진 주소 공간 하나**에 통째로 mmap 돼야
    /// 하는데, 앱이 오래 돌아 주소 공간이 조각나 있으면 그 mmap 이 실패한다. 엔진은 그 절을
    /// 건너뛰고도 「준비됨」이라 하고, 첫 prefill 에서야 `FAILED_PRECONDITION … per_layer_embedding_
    /// lookup_ is null` 로 넘어진다 (LiteRT-LM #2545, 2026-09-18 사용자 화면). 같은 엔진으로는
    /// 백 번 해도 같다 — 내려놓고 다시 올려야 한 번 더 자리를 잡아 볼 수 있다.
    static func isEngineBroken(_ error: LiteRTLMError) -> Bool {
        switch error {
        case .engine: return true
        case .conversation(.invalidResponse(let detail)):
            return detail.contains("FAILED_PRECONDITION") || detail.contains("is null")
        case .conversation(.failedToStartStream), .conversation(.notAlive): return true
        default: return false
        }
    }

    /// 화면에 보일 한 줄. 자세한 원문은 짧게 뒤에 — 알려 줄 때 도움이 된다.
    static func explain(_ error: LiteRTLMError) -> String {
        switch error {
        case .conversation(.invalidResponse(let detail)) where detail.contains("per_layer_embedding"):
            return "이 기기에서 모델이 자리를 잡지 못했습니다 — 한 번 더 해 보고, 그래도 안 되면 앱을 껐다 켜 주세요"
        case .engine:
            return "모델을 올리지 못했습니다 — 앱을 껐다 켜고 다시 해 보세요"
        case .conversation(.invalidResponse(let detail)):
            return "모델이 답하지 못했습니다 — 다시 해 보세요 (\(Self.brief(detail)))"
        default:
            return "모델이 답하지 못했습니다 — 다시 해 보세요 (\(Self.brief(error.errorDescription ?? String(describing: error))))"
        }
    }

    private static func brief(_ detail: String) -> String {
        let line = detail.split(whereSeparator: \.isNewline).first.map(String.init) ?? detail
        return line.count > 80 ? String(line.prefix(80)) + "…" : line
    }

    public func cancel(requestID: AssistantRequest.ID) async {
        guard let conversation = live[requestID] else { return }
        try? conversation.cancel()
    }

    public func unload() async {
        guard live.isEmpty else { return }
        engine = nil
        idleTask?.cancel()
        idleTask = nil
        pressure?.cancel()
        pressure = nil
    }

    private func armIdleTimer() {
        idleTask?.cancel()
        let idle = profile?.idleUnload ?? 120
        idleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(idle * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                if await self.idleElapsed(idle) { await self.unload(); return }
            }
        }
    }

    private func idleElapsed(_ idle: TimeInterval) -> Bool {
        live.isEmpty && Date().timeIntervalSince(lastUse) >= idle
    }

    private func armMemoryPressure() {
        pressure?.cancel()
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.unload() }
        }
        source.activate()
        pressure = source
    }
}
