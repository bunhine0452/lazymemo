import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import SpikeKit

// 3.31.4 의 공개 시그니처(ChatSession·LLMModelFactory.loadContainer(from:using:)·Generation)를 보고 썼다.
// 이 세션에서는 컴파일하지 않았다 — mlx-swift 빌드와 Qwen 가중치(약 2.3GB)가 필요해 용량 때문에 미뤘다.
// 처음 돌릴 때 컴파일 오류가 나면 이 파일만 고치면 된다. SpikeKit 의 채점·보고서는 그대로 쓴다.

/// Qwen3-4B-Instruct-2507 은 non-thinking 전용이다. thinking 토글이 없으니 template 검사만 한다.
final class MLXGenerator: TextGenerator, @unchecked Sendable {
    let label: String
    private let directory: URL
    private let maxContext: Int
    private var container: ModelContainer?
    private var liveTask: Task<Void, Never>?
    private let lock = NSLock()
    private var cancelFlag = false

    init(directory: URL, maxContext: Int) {
        self.directory = directory
        self.maxContext = maxContext
        self.label = "MLX Swift LM 3.31.4 · \(directory.lastPathComponent) · ctx \(maxContext)"
    }

    func load() async throws -> TimeInterval {
        let start = Date()
        container = try await LLMModelFactory.shared.loadContainer(
            from: directory, using: #huggingFaceTokenizerLoader())
        return Date().timeIntervalSince(start)
    }

    func unload() async {
        container = nil
        MLX.GPU.clearCache()
    }

    func tokenCount(system: String, user: String) async throws -> Int? {
        guard let container else { throw SpikeError.notLoaded }
        return try await container.perform { context in
            let messages: [Chat.Message] = [.system(system), .user(user)]
            let input = try await context.processor.prepare(input: UserInput(chat: messages))
            return input.text.tokens.size
        }
    }

    /// mlx-swift-lm 3.31.4 에는 schema 제약 디코딩이 없다. 무시한다.
    var supportsSchema: Bool { false }

    func generate(
        system: String, user: String, maxOutputTokens: Int, jsonSchema: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> GenerationStats {
        guard let container else { throw SpikeError.notLoaded }
        // 모델 카드 권고(non-thinking): temperature 0.7 · topP 0.8 · topK 20. 품질 평가 뒤 task 별 고정.
        var params = GenerateParameters(maxTokens: maxOutputTokens, temperature: 0.7, topP: 0.8)
        params.topK = 20
        params.maxKVSize = maxContext
        let session = ChatSession(container, instructions: system, generateParameters: params)

        let start = Date()
        var firstText: TimeInterval?
        var text = ""
        var info: GenerateCompletionInfo?
        lock.withLock { cancelFlag = false }

        let stream = session.streamDetails(to: user)
        for try await event in stream {
            if lock.withLock({ cancelFlag }) { break }
            switch event {
            case .chunk(let piece):
                guard !piece.isEmpty else { continue }
                if firstText == nil { firstText = Date().timeIntervalSince(start) }
                text += piece
                onDelta(piece)
            case .info(let done):
                info = done
            default:
                break
            }
        }
        let total = Date().timeIntervalSince(start)
        return GenerationStats(
            timeToFirstText: firstText ?? total, total: total, outputText: text,
            prefillTokens: info?.promptTokenCount, decodeTokens: info?.generationTokenCount,
            decodeTokensPerSecond: info?.tokensPerSecond, cancelled: lock.withLock { cancelFlag })
    }

    /// MLX 스트림은 소비자가 끊으면 멈춘다 — 다음 chunk 에서 break.
    func cancel() async { lock.withLock { cancelFlag = true } }
}

enum SpikeError: Error, CustomStringConvertible {
    case notLoaded, missingArgument(String), modelNotFound(String)
    var description: String {
        switch self {
        case .notLoaded: return "모델이 로드되지 않았다"
        case .missingArgument(let a): return "인자가 없다: \(a)"
        case .modelNotFound(let p): return "모델 폴더가 없다: \(p)"
        }
    }
}
