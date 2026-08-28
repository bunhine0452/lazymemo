import AppKit
import LazyMemoCore
import SwiftUI

/// 빠른 입력의 표시와 지연 측정 (설계문서 §8, §11).
///
/// 목표는 **단축키에서 커서까지 150ms**다. 그래서 창과 뷰를 앱 기동 시 미리
/// 만들어 두고 위치와 표시만 토글한다 — 처음 여는 순간에 SwiftUI 계층을 짓게
/// 두면 첫 호출이 눈에 띄게 느리고, 그 한 번이 사용자의 인상을 정한다.
@MainActor
final class QuickCaptureController {
    static let width: CGFloat = 560

    private let panel: QuickCapturePanel
    private let hosting: NSHostingView<QuickCaptureView>
    private let model: QuickCaptureModel
    private let store: MemoStore
    private let windows: NoteWindowManager

    /// 마지막 표시에 걸린 시간. 성능 예산 검증용이다.
    private(set) var lastLatency: Duration?

    init(store: MemoStore, windows: NoteWindowManager) {
        self.store = store
        self.windows = windows
        self.model = QuickCaptureModel(store: store)

        let initialSize = NSSize(width: Self.width, height: 120)
        self.panel = QuickCapturePanel(contentRect: NSRect(origin: .zero, size: initialSize))

        var commit: () -> Void = {}
        var cancel: () -> Void = {}
        self.hosting = NSHostingView(rootView: QuickCaptureView(
            model: model,
            onCommit: { commit() },
            onCancel: { cancel() }
        ))
        // 높이는 결과 수에 따라 달라진다. 뷰가 창 크기를 정하게 두되 가로는 고정한다.
        hosting.sizingOptions = [.intrinsicContentSize]

        panel.contentView = hosting
        commit = { [weak self] in self?.commit() }
        cancel = { [weak self] in self?.close() }

        // 결과가 늘고 줄면 창 높이가 따라가야 한다.
        model.onLayoutChange = { [weak self] in self?.resize() }

        // loadView 와 첫 레이아웃을 지금 치른다 — 이것이 프리워밍의 실체다.
        hosting.layoutSubtreeIfNeeded()
    }

    var isOpen: Bool { panel.isVisible }

    func toggle() {
        isOpen ? close() : show()
    }

    func show() {
        let started = ContinuousClock.now

        model.reset()
        resize()
        panel.moveToCaptureAnchor()

        // 상주 앱(.accessory)은 스스로 활성화해야 키 입력을 받는다.
        // 창을 올리기 **전에** 활성화해야 첫 글자를 놓치지 않는다.
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        focusEditor()

        lastLatency = ContinuousClock.now - started
    }

    func close() {
        panel.orderOut(nil)
    }

    /// 검색 결과가 늘고 줄 때 창 높이를 따라가게 한다.
    func resize() {
        let fitting = hosting.fittingSize
        let height = max(fitting.height, 120)
        panel.setContentSize(NSSize(width: Self.width, height: height))
    }

    /// 커서가 서 있어야 "표시됐다"고 할 수 있다 (§8).
    private func focusEditor() {
        guard let textView = panel.contentView?.firstTextView else { return }
        panel.makeFirstResponder(textView)
    }

    private func commit() {
        let outcome = model.commit()
        close()

        switch outcome {
        case .create(let draft):
            Task {
                guard let memo = try? await store.create(
                    body: draft.text, due: draft.due, at: draft.at
                ) else { return }
                windows.open(memo, activating: true)
            }
        case .open(let id):
            windows.reveal(id)
        case .nothing:
            break
        }
    }
}
