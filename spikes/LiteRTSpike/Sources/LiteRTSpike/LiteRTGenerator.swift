import Foundation
import LiteRTLM
import SpikeKit

/// LiteRT-LM Engine/Conversation 을 `TextGenerator` 로 감싼다.
/// 요청마다 새 Conversation — 폰·맥이 KV cache 를 공유하지 않는다는 명세 §7 과 같은 자세.
final class LiteRTGenerator: TextGenerator, @unchecked Sendable {
    let label: String
    private let modelPath: String
    private let backend: Backend
    private let maxNumTokens: Int
    private let cacheDir: String
    private let temperature: Float
    private var engine: Engine?
    private var live: Conversation?
    private let lock = NSLock()

    init(modelPath: String, backend: Backend, maxNumTokens: Int, cacheDir: String, temperature: Float = 1.0) {
        self.modelPath = modelPath
        self.backend = backend
        self.maxNumTokens = maxNumTokens
        self.cacheDir = cacheDir
        self.temperature = temperature
        self.label = "LiteRT-LM 0.16.0 · \(backend.rawValue) · \((modelPath as NSString).lastPathComponent) · ctx \(maxNumTokens) · temp \(temperature)"
    }

    func load() async throws -> TimeInterval {
        // 엔진 자체의 prefill/decode 수치를 받으려면 실험 API 를 켜야 한다. 앱 전체 수치와 따로 적는다(명세 §8).
        ExperimentalFlags.optIntoExperimentalAPIs()
        ExperimentalFlags.enableBenchmark = true
        let start = Date()
        let config = try EngineConfig(
            modelPath: modelPath, backend: backend, maxNumTokens: maxNumTokens, cacheDir: cacheDir)
        let engine = Engine(engineConfig: config)
        try await engine.initialize()
        self.engine = engine
        return Date().timeIntervalSince(start)
    }

    func unload() async {
        lock.withLock { live = nil }
        engine = nil
    }

    var supportsSchema: Bool { true }

    private func conversation(system: String, constrained: Bool) async throws -> Conversation {
        guard let engine else { throw SpikeError.notLoaded }
        // 모델 카드 권고값 기준선 (명세 §7). 품질 평가 뒤 task 별로 고정한다.
        let sampler = try SamplerConfig(topK: 64, topP: 0.95, temperature: temperature, seed: 0)
        let config = ConversationConfig(
            systemMessage: Message(system, role: .system),
            samplerConfig: sampler,
            thinkingConfig: ThinkingConfig(enableThinking: false),
            automaticToolCalling: false,
            enableResponseFormat: constrained)
        return try await engine.createConversation(with: config)
    }

    /// LiteRT-LM 0.16.0 은 보내기 전의 토큰 수를 주지 않는다 (getTokenCount 는 처리된 토큰).
    /// 실제 입력 토큰은 생성 뒤 `GenerationStats.prefillTokens` 로 받는다.
    func tokenCount(system: String, user: String) async throws -> Int? { nil }

    func generate(
        system: String, user: String, maxOutputTokens: Int, jsonSchema: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> GenerationStats {
        let format = try jsonSchema.map { try ResponseFormat.json(schema: $0) }
        let conv = try await conversation(system: system, constrained: format != nil)
        lock.withLock { live = conv }
        defer { lock.withLock { live = nil } }

        let start = Date()
        var firstText: TimeInterval?
        var text = ""
        var cancelled = false
        do {
            for try await chunk in conv.sendMessageStream(
                Message(user, role: .user),
                maxOutputTokens: maxOutputTokens,
                thinkingConfig: ThinkingConfig(enableThinking: false),
                responseFormat: format
            ) {
                // channels(예: thought) 는 사용자에게 보이지 않는다 — 첫 답으로 세지 않는다.
                let piece = chunk.contents.toString
                guard !piece.isEmpty else { continue }
                if firstText == nil { firstText = Date().timeIntervalSince(start) }
                text += piece
                onDelta(piece)
            }
        } catch {
            if isCancelled { cancelled = true } else { throw error }
        }
        let total = Date().timeIntervalSince(start)
        var stats = GenerationStats(
            timeToFirstText: firstText ?? total, total: total, outputText: text, cancelled: cancelled)
        if let info = try? conv.getBenchmarkInfo() {
            stats.prefillTokens = info.lastPrefillTokenCount
            stats.decodeTokens = info.lastDecodeTokenCount
            stats.decodeTokensPerSecond = info.lastDecodeTokensPerSecond
        }
        return stats
    }

    private var isCancelled: Bool { lock.withLock { cancelFlag } }
    private var cancelFlag = false

    func cancel() async {
        let conv: Conversation? = lock.withLock { cancelFlag = true; return live }
        try? conv?.cancel()
    }

    func resetCancel() { lock.withLock { cancelFlag = false } }
}

enum SpikeError: Error, CustomStringConvertible {
    case notLoaded, missingArgument(String), modelNotFound(String)
    var description: String {
        switch self {
        case .notLoaded: return "엔진이 로드되지 않았다"
        case .missingArgument(let a): return "인자가 없다: \(a)"
        case .modelNotFound(let p): return "모델 파일이 없다: \(p)"
        }
    }
}
