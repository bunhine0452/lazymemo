import AppKit
import LazyMemoAssistantUI
import LazyMemoCore
import SwiftUI

/// 「메모에게 묻기…」 — 작은 창 하나. 근거를 누르면 그 종이를 앞으로 꺼낸다.
@MainActor
final class AssistantWindow {
    private var window: NSWindow?
    private let model: AssistantModel
    private let store: MemoStore
    private let reveal: (ULID) -> Void

    init(model: AssistantModel, store: MemoStore, reveal: @escaping (ULID) -> Void) {
        self.model = model
        self.store = store
        self.reveal = reveal
    }

    func show(selected: ULID? = nil) {
        if let window, window.isVisible, selected == nil { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        window?.close()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L("메모에게 묻기")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AssistantView(
            model: model, selected: selected,
            memoTitle: { [store] id in store.memo(id)?.title },
            openMemo: { [reveal] id in reveal(id) }
        ))
        window.center()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
