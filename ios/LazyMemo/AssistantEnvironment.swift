import LazyMemoAssistantUI
import SwiftUI

/// 편집기·목록 어디서든 같은 비서를 잡는다 — 생성자에 하나씩 끼우지 않는다.
private struct AssistantKey: EnvironmentKey {
    static let defaultValue: AssistantModel? = nil
}

extension EnvironmentValues {
    var assistant: AssistantModel? {
        get { self[AssistantKey.self] }
        set { self[AssistantKey.self] = newValue }
    }
}
