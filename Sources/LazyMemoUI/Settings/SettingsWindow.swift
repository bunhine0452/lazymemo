import AppKit
import SwiftUI

/// 「lazymemo 설정」 창 — 하나만, ⌘, 로.
///
/// 이 앱은 Dock 도 메뉴 막대도 없으므로(`AppDelegate`) 창이 스스로 앞으로 나와야 한다
/// (`RecallWindow` 와 같다). 최소화·확대 단추는 없다 — HIG Settings(macOS): "Dim a settings
/// window's minimize and maximize buttons … a settings window accommodates the size of the
/// current pane". 크기는 뷰가 정한다 (`SettingsView.frame`).
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static var isOpen: Bool { window?.isVisible == true }

    /// 검증 주행만 — 사람의 손이 없으면 앱이 활성화되지 못해 창이 남의 창 뒤에 서므로,
    /// 합성 마우스가 닿도록 위로 올린다 (`LAZYMEMO_SETTINGS`).
    static var liftedForVerification = false

    static func show(_ model: SettingsScreenModel) {
        if let window {
            model.reload()
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        // 판 하나가 통째로 보이는 키까지 — 화면이 작으면 그만큼만, 나머지는 판이 스크롤한다.
        let ceiling = min(880, (NSScreen.main?.visibleFrame.height ?? 900) - 72)
        let controller = NSHostingController(rootView: SettingsView(model: model, maxHeight: ceiling))
        controller.sizingOptions = [.preferredContentSize]
        let next = NSWindow(contentViewController: controller)
        next.styleMask = [.titled, .closable]
        next.title = L("lazymemo 설정")
        next.titlebarSeparatorStyle = .none
        next.isReleasedWhenClosed = false
        if liftedForVerification { next.level = .floating }
        window = next
        NSApp.activate()
        next.makeKeyAndOrderFront(nil)
        // 크기는 SwiftUI 가 화면에 올린 **다음 턴**에야 정한다 (`RecallWindow` 와 같다) — 그 전에
        // 가운데 맞추면 판이 자란 만큼 아래가 화면 밖으로 나간다. 자란 뒤에 맞추고, 화면보다
        // 길면 화면에 맞춘다 (판은 스크롤한다).
        DispatchQueue.main.async { DispatchQueue.main.async { Self.fit(next) } }
    }

    private static func fit(_ window: NSWindow) {
        guard let screen = (window.screen ?? NSScreen.main)?.visibleFrame else { window.center(); return }
        var frame = window.frame
        frame.size.height = min(frame.height, screen.height - 40)
        frame.origin.x = screen.midX - frame.width / 2
        // 시스템 설정처럼 살짝 위에 — 한가운데는 무거워 보인다.
        frame.origin.y = screen.minY + (screen.height - frame.height) * 0.6
        window.setFrame(frame, display: true)
    }

    static func close() {
        window?.close()
        window = nil
    }

    /// 창을 그대로 그림으로 — 화면 기록 권한 없이 뷰가 스스로 그린다 (`LAZYMEMO_SETTINGS=<png>`).
    static func snapshot(to url: URL, scrolledToEnd: Bool = false) {
        guard let view = window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        if scrolledToEnd, let scroll = view.firstDescendant(NSScrollView.self), let doc = scroll.documentView {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, doc.bounds.height - scroll.contentView.bounds.height)))
            scroll.reflectScrolledClipView(scroll.contentView)
            view.layoutSubtreeIfNeeded()
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
