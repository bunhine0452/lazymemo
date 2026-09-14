#if os(macOS)
import AppKit
import LazyMemoCore
import SwiftUI

/// 맥의 다시 보기·알림 설정 창. 한 번에 하나만 — 종이마다 창을 두면 창이 종이를 덮는다.
///
/// 이 앱은 Dock 도 메뉴 막대도 차지하지 않으므로(`AppDelegate`) 창을 띄울 때
/// 스스로 앞으로 나와야 한다 (`WelcomeWindow` 와 같다).
@MainActor public enum RecallWindow {
    private static var window: NSWindow?

    public static func show(store: MemoStore, id: ULID) {
        present(RecallEditor(store: store, id: id), title: L("다시 보기 · lazymemo"))
    }

    public static func settings() {
        present(ReminderSettingsView().padding(24).frame(width: 440), title: L("알림 · lazymemo"))
    }

    private static func present<V: View>(_ view: V, title: String) {
        window?.close()
        // contentViewController 로 붙이면 창이 뷰의 크기에 맞춰진다.
        let next = NSWindow(contentViewController: NSHostingController(rootView: view))
        next.styleMask = [.titled, .closable]
        next.title = title
        next.isReleasedWhenClosed = false
        next.center()
        window = next
        NSApp.activate()
        next.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
        window = nil
    }
}
#endif
