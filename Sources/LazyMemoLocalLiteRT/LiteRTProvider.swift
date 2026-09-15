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
        } catch {
            continuation.finish(throwing: error)
        }
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
