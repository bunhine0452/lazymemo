import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// ⌘F 가 종이에 찾기 줄을 세우는가 — 메인 메뉴를 거치지 않고 편집기가 직접 받는 길 (`MemoNSTextView.perform`).
///
/// 메뉴의 「찾기」는 앱이 활성일 때만 살고, 텍스트 뷰는 `usesFindBar` 가 꺼져 있으면 그 선택자를 받아도
/// 아무것도 세우지 않았다 — 배선만 있고 줄은 없던 자리. 찾기 줄은 스크롤 뷰 머리에 서므로 종이(스크롤 뷰
/// 안·`findable`)에서만 서고, 빠른 입력의 한 줄 상자에서는 서지 않아야 한다.
@MainActor
@Suite("종이 — ⌘F 찾기 줄")
struct FindBarTests {
    private func makePaper(findable: Bool) -> (MemoNSTextView, NSScrollView, NSWindow) {
        let font = NSFont.systemFont(ofSize: Paper.bodySize)
        let textView = MemoTextEditor.makeTextView(
            font: font, insets: NSSize(width: Theme.loose, height: Theme.loose), linePitch: Paper.linePitch
        )
        textView.usesFindBar = findable
        textView.isIncrementalSearchingEnabled = findable
        textView.string = "장보기\n우유, 계란, 두부\n치과 예약"
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        scrollView.documentView = textView
        let window = NSWindow(contentRect: scrollView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scrollView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        return (textView, scrollView, window)
    }

    private func commandF(_ window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "f",
            isARepeat: false, keyCode: 3
        )!
    }

    @Test("종이에서 ⌘F 를 치면 찾기 줄이 선다")
    func showsTheFindBar() {
        let (textView, scrollView, window) = makePaper(findable: true)
        defer { window.orderOut(nil) }
        #expect(!scrollView.isFindBarVisible)
        #expect(textView.performKeyEquivalent(with: commandF(window)))
        #expect(scrollView.isFindBarVisible)
    }

    @Test("찾기 줄을 켜지 않은 편집기(빠른 입력)에서는 ⌘F 를 받지 않는다")
    func leavesTheCaptureBoxAlone() {
        let (textView, scrollView, window) = makePaper(findable: false)
        defer { window.orderOut(nil) }
        #expect(!textView.performKeyEquivalent(with: commandF(window)))
        #expect(!scrollView.isFindBarVisible)
    }
}
