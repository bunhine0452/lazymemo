import Foundation

/// 기기별 예산. 엔진 어댑터에 주입한다 (명세 §6~7).
public struct ModelProfile: Sendable, Equatable {
    public let profileID: String
    public let contextTokens: Int
    /// 이 시간 동안 요청이 없으면 내린다. M1·8GB 2분, 16GB 이상 5분.
    public let idleUnload: TimeInterval
    public let peakMemoryBudget: UInt64

    public init(profileID: String, contextTokens: Int = TokenBudget.context, idleUnload: TimeInterval = 120,
                peakMemoryBudget: UInt64 = 3 * 1024 * 1024 * 1024) {
        self.profileID = profileID; self.contextTokens = contextTokens
        self.idleUnload = idleUnload; self.peakMemoryBudget = peakMemoryBudget
    }
}

public enum ModelAvailability: Sendable, Equatable {
    case ready
    case notDownloaded
    case downloading(fraction: Double)
    case unsupportedDevice
    case insufficientMemory
    case corrupted
}

/// Coordinator 가 엔진에 넘기는 한 번의 호출. 지시문은 Coordinator 가 만든다.
public struct AssistantPrompt: Sendable, Equatable {
    public let requestID: AssistantRequest.ID
    public let system: String
    public let user: String
    public let maxOutputTokens: Int
    /// 제약 디코딩용. 엔진이 못 하면 무시해도 된다 — 검증은 앱이 한다.
    public let jsonSchema: String?

    public init(requestID: AssistantRequest.ID, system: String, user: String, maxOutputTokens: Int, jsonSchema: String? = nil) {
        self.requestID = requestID; self.system = system; self.user = user
        self.maxOutputTokens = maxOutputTokens; self.jsonSchema = jsonSchema
    }
}

/// 엔진 어댑터 계약. 대화 상태를 들지 않는다 — 호출마다 완결된 prompt 를 받는다.
public protocol LocalModelProvider: Sendable {
    var availability: ModelAvailability { get async }
    func prepare(_ profile: ModelProfile) async throws
    /// 사용자에게 보이는 글자만 흘린다. thinking·도구 토큰은 오지 않는다.
    func stream(_ prompt: AssistantPrompt) -> AsyncThrowingStream<String, Error>
    func cancel(requestID: AssistantRequest.ID) async
    func unload() async
}
