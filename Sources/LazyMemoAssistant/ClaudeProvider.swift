#if os(macOS)
import Foundation
import LazyMemoCore

/// 이 맥에 `claude` 가 있으면 그것을 비서의 엔진으로 빌린다 (`ClaudeSupport` 가 찾아 준다).
///
/// **왜 빌리는가.** 이 기기의 모델은 2B 다. 메모 여섯 장에서 답을 찾는 일은 잘 하지만, 웹 세 쪽을
/// 견줘 하나의 답으로 묶고 표까지 세우는 일은 그 크기가 할 수 있는 일이 아니다. 맥에 `claude` 가
/// 있는 사람에게는 그 일을 맡기는 편이 정확하다 — **키는 여전히 없다**(사용자 구독을 그대로 쓴다,
/// docs/DESIGN.md §9.4). 없는 사람에게는 아무것도 달라지지 않는다: 이 기기의 모델이 그대로 답한다.
///
/// 빌리는 일은 셋뿐이다 — 웹의 답(`webAnswer`)·다듬기(`tidy`)·정리(`digest`). 메모에서 답 찾기와
/// 시키기는 **메모 본문이 나가는 일**이라 이 기기 안에 둔다 (§9.3 의 표가 그대로 참이어야 한다).
public struct ClaudeCLIProvider: LocalModelProvider {
    let runner: ClaudeRunner

    public init(runner: ClaudeRunner) { self.runner = runner }

    /// 찾아 둔 자리에 파일이 있으니 준비랄 것이 없다. 콜드 스타트도 받을 것도 없다.
    public var availability: ModelAvailability { .ready }

    public func prepare(_ profile: ModelProfile) async throws {}

    /// 조각으로 흘리지 않는다 — `claude -p` 는 다 쓰고 한 번에 준다. 화면의 획은 그래서 한 번만
    /// 나아가고, 대신 「답을 적는 중」이 그동안 서 있다 (`AssistantModel.Stage`).
    public func stream(_ prompt: AssistantPrompt) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let answer = try await runner.ask(prompt.system, about: prompt.user)
                    continuation.yield(answer)
                    continuation.finish()
                } catch let failure as ClaudeRunner.Failure {
                    // `.provider` 여야 웹의 답이 «결과 그대로» 로 물러난다 (`AssistantCoordinator`).
                    continuation.finish(throwing: AssistantFailure.provider(failure.description))
                } catch {
                    continuation.finish(throwing: AssistantFailure.provider(String(describing: error)))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 띄운 프로세스를 중간에 끊을 길은 두지 않았다 — 상한(90초)이 끝을 보장한다 (`ClaudeRunner`).
    public func cancel(requestID: AssistantRequest.ID) async {}

    public func unload() async {}
}
#endif
