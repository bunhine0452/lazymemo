import AppKit
import Foundation
import LazyMemoCore
import SwiftUI
import Testing
@testable import LazyMemoUI

/// Esc 는 종이를 치운다 (설계문서 §7.1 일곱째 규칙).
///
/// 두 길이 있다 — 본문에 커서가 있을 때(텍스트 뷰)와 손잡이만 잡아 창이 키를
/// 잡았을 때(창). 둘 다 `NoteWindowController.escape` 한곳에서 만나 ×와 같은
/// 길로 간다. 실제 키 누름은 화면이 있어야 하지만, **어느 길로 오든 같은 곳에
/// 닿는지**와 **닿으면 안 되는 때**는 여기서 잰다.
@MainActor
@Suite("Esc — 종이를 치운다")
struct NoteEscapeTests {
    @Test("본문의 Esc 는 손을 뗀 뒤 종이를 치운다")
    func textViewEscapeCloses() {
        let textView = MemoTextEditor.makeTextView(font: .systemFont(ofSize: 14), insets: .zero, linePitch: nil)
        var escaped = 0
        textView.blursOnEscape = true
        textView.onEscape = { escaped += 1 }
        textView.cancelOperation(nil)
        #expect(escaped == 1)
    }

    @Test("한글 조합 중의 Esc 는 입력기의 것이다 — 종이를 치우지 않는다")
    func composingEscapeIsLeftToInputMethod() {
        let textView = MemoTextEditor.makeTextView(font: .systemFont(ofSize: 14), insets: .zero, linePitch: nil)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = textView
        var escaped = 0
        textView.onEscape = { escaped += 1 }
        textView.setMarkedText("ㅈ", selectedRange: NSRange(location: 0, length: 1), replacementRange: NSRange(location: 0, length: 0))
        #expect(textView.hasMarkedText())
        textView.cancelOperation(nil)
        #expect(escaped == 0)
    }

    @Test("창까지 올라온 Esc 도 같은 곳으로 — 선택자 길과 키 길 모두")
    func windowEscapeRoutes() {
        let window = DesktopLevelWindow(contentRect: NSRect(x: -3000, y: -3000, width: 200, height: 140))
        defer { window.orderOut(nil) }
        var escaped = 0
        window.onEscape = { escaped += 1 }

        window.cancelOperation(nil)
        #expect(escaped == 1)

        let escape = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil,
            characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53
        )!
        window.keyDown(with: escape)
        #expect(escaped == 2)
    }

    @Test("Esc 는 치우기다 — 지우기가 아니고, 방금 지운 종이는 건드리지 않는다")
    func controllerEscapeIsPutAway() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-escape-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let previews = LinkPreviewStore(
            cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
            settings: settings
        )
        let memo = try await store.create(body: "치과 예약")

        var closed: [ULID] = []
        let controller = NoteWindowController(
            memo: memo, store: store, previews: previews, appearance: PaperAppearance(settings: settings),
            frame: NSRect(x: -3000, y: -3000, width: 260, height: 200),
            onFrameChange: { _, _ in }, onCloseRequest: { closed.append($0) }
        )
        defer { controller.window.orderOut(nil) }

        // 창의 Esc 가 컨트롤러에 배선돼 있다 — 치우기 요청이 한 번, 지우기는 없다.
        controller.window.cancelOperation(nil)
        #expect(closed == [memo.id])
        #expect(store.memo(memo.id) != nil)

        // 방금 지운 종이에는 되돌리는 줄이 서 있다 — Esc 가 그 자리를 걷어 가면 안 된다.
        await controller.model.delete()
        #expect(controller.isMourning)
        controller.escape()
        #expect(closed.count == 1)
    }
}
