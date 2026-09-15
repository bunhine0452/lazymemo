import Foundation

/// 한 번의 생성이 남기는 수치. 시각은 모두 초.
public struct GenerationStats: Sendable {
    /// 사용자에게 보이는 첫 글자까지 (명세 §8 — thinking 은 세지 않는다).
    public var timeToFirstText: TimeInterval
    public var total: TimeInterval
    public var outputText: String
    /// 엔진이 알려 주면 채운다. 모르면 nil — 글자 수로 대신 계산하지 않는다.
    public var prefillTokens: Int?
    public var decodeTokens: Int?
    public var decodeTokensPerSecond: Double?
    public var cancelled: Bool

    public init(
        timeToFirstText: TimeInterval, total: TimeInterval, outputText: String,
        prefillTokens: Int? = nil, decodeTokens: Int? = nil,
        decodeTokensPerSecond: Double? = nil, cancelled: Bool = false
    ) {
        self.timeToFirstText = timeToFirstText
        self.total = total
        self.outputText = outputText
        self.prefillTokens = prefillTokens
        self.decodeTokens = decodeTokens
        self.decodeTokensPerSecond = decodeTokensPerSecond
        self.cancelled = cancelled
    }
}

/// 엔진 어댑터가 지켜야 할 최소 계약. 제품의 `LocalModelProvider`(명세 §3)가 아니라
/// spike 전용이다 — 대화 상태를 들지 않고, 요청마다 새 대화로 시작한다.
public protocol TextGenerator: AnyObject {
    /// 보고서에 적을 이름 — 엔진·버전·모델 파일.
    var label: String { get }
    /// 모델을 메모리에 올린다. 걸린 시간을 돌려준다.
    func load() async throws -> TimeInterval
    /// 메모리에서 내린다. 다시 load 할 수 있어야 한다.
    func unload() async
    /// system+user 를 엔진의 실제 tokenizer 로 센다. 못 세면 nil.
    func tokenCount(system: String, user: String) async throws -> Int?
    /// 스트리밍 생성. delta 는 사용자에게 보이는 글자만.
    /// `jsonSchema` 가 있으면 제약 디코딩을 시도한다. 엔진이 못 하면 무시하고 `supportsSchema` 를 false 로 둔다.
    func generate(
        system: String, user: String, maxOutputTokens: Int, jsonSchema: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> GenerationStats
    var supportsSchema: Bool { get }
    /// 진행 중인 생성을 끊는다. 스트림은 곧 끝나야 한다.
    func cancel() async
}
