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

    /// 소개 영상 주행(`DemoTour`)의 무대 — 창을 이 구역 한가운데, 이 층에 세운다.
    /// 무대의 바탕이 일반 창보다 위에 깔리므로 보통 층의 창은 그 뒤에 숨는다.
    public static var demo: (stage: CGRect, level: NSWindow.Level)?

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
        if let demo {
            next.level = demo.level
            // 크기는 SwiftUI 가 화면에 올린 **다음 턴**에야 정한다 — 그 전의 frame 으로
            // 자리를 잡으면 위가 무대 밖으로 잘린다. 자리를 잡을 때까지는 보이지 않게.
            next.alphaValue = 0
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    let size = next.frame.size
                    let y = max(demo.stage.minY + 16, min(demo.stage.midY - size.height / 2, demo.stage.maxY - size.height - 16))
                    next.setFrameOrigin(CGPoint(x: demo.stage.midX - size.width / 2, y: y))
                    next.alphaValue = 1
                }
            }
        }
        NSApp.activate()
        next.makeKeyAndOrderFront(nil)
    }

    public static func close() {
        window?.close()
        window = nil
    }
}
#endif
