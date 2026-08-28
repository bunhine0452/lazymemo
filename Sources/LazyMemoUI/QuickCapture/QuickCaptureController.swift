import AppKit
import LazyMemoCore
import SwiftUI

/// 빠른 입력 팝오버의 표시와 지연 측정 (설계문서 §8, §11).
///
/// 목표는 **단축키에서 커서까지 150ms**다. 그래서 팝오버와 뷰를 앱 기동 시
/// 미리 만들어 두고 표시만 토글한다 — 처음 여는 순간에 SwiftUI 계층을 짓게
/// 두면 첫 호출이 눈에 띄게 느리고, 그 한 번이 사용자의 인상을 정한다.
@MainActor
final class QuickCaptureController {
    private let popover = NSPopover()
    private let model: QuickCaptureModel
    private let store: MemoStore
    private let windows: NoteWindowManager

    /// 마지막 표시에 걸린 시간. 성능 예산 검증용이다.
    private(set) var lastLatency: Duration?

    init(store: MemoStore, windows: NoteWindowManager) {
        self.store = store
        self.windows = windows
        self.model = QuickCaptureModel(store: store)

        popover.behavior = .transient
        // 150ms 예산에 애니메이션은 사치다. 즉시 나타나는 편이 더 빠르게 느껴진다.
        popover.animates = false

        let hosting = NSHostingController(rootView: QuickCaptureView(
            model: model,
            onCommit: { [weak self] in self?.commit() },
            onCancel: { [weak self] in self?.close() }
        ))
        popover.contentViewController = hosting

        // loadView 를 지금 치른다 — 이것이 프리워밍의 실체다.
        hosting.view.layoutSubtreeIfNeeded()
    }

    var isOpen: Bool { popover.isShown }

    func toggle(from button: NSStatusBarButton) {
        isOpen ? close() : show(from: button)
    }

    func show(from button: NSStatusBarButton) {
        let started = ContinuousClock.now

        model.reset()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 상주 앱(.accessory)은 스스로 활성화해야 키 입력을 받는다.
        NSApp.activate()
        focusEditor()

        lastLatency = ContinuousClock.now - started
    }

    func close() {
        popover.performClose(nil)
    }

    /// 커서가 서 있어야 "표시됐다"고 할 수 있다 (§8).
    private func focusEditor() {
        guard let contentView = popover.contentViewController?.view,
              let textView = contentView.firstTextView
        else { return }
        contentView.window?.makeFirstResponder(textView)
    }

    private func commit() {
        switch model.commit() {
        case .create(let text):
            close()
            Task {
                guard let memo = try? await store.create(body: text) else { return }
                windows.open(memo, activating: true)
            }
        case .open(let id):
            close()
            windows.reveal(id)
        case .nothing:
            close()
        }
    }
}
