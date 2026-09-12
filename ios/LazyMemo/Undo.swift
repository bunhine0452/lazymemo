import Foundation
import LazyMemoCore
import SwiftUI

/// 되돌리기는 시스템이 한다 (MOBILE_DESIGN §4). 흔들기·세 손가락 쓸기가
/// `UndoManager` 에 이름을 달아 둔 동작을 되돌리고, 시스템 알림이 「지우기
/// 실행 취소」라고 묻는다. 우리 띠는 없다. 되돌린 결과는 화면이 보인다 —
/// 돌아온 줄로 스크롤하고 한 번 밝힌다 (`Reveal`).
enum Undo {
    /// 이름 달린 되돌리기 한 건. `undo` 는 그 자체로 다시 되돌릴 수 있게 등록한다.
    static func register(
        _ name: String, on manager: UndoManager?, reveal: Reveal? = nil, id: ULID? = nil,
        undo: @escaping @MainActor () async -> Void
    ) {
        guard let manager else { return }
        manager.registerUndo(withTarget: Anchor.shared) { _ in
            Task { @MainActor in
                await undo()
                if let id { reveal?.show(id) }
            }
        }
        manager.setActionName(name)
    }

    /// `registerUndo(withTarget:)` 이 약한 참조로 쥘 대상. 상태는 없다.
    final class Anchor { static let shared = Anchor() }
}

/// 방금 생기거나 돌아온 줄을 보인다 — 목록이 그리로 가고 잠깐 밝아진다.
/// "Show the results of an undo or redo… scroll the document to show the restored paragraph."
@Observable
final class Reveal {
    private(set) var target: ULID?
    private var fade: Task<Void, Never>?

    func show(_ id: ULID) {
        fade?.cancel()
        target = id
        fade = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            self?.target = nil
        }
    }
}
