import AppKit
import SwiftUI
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 종이에서 ⏎ 를 치면 목록 머리가 이어지는가 — **진짜 텍스트 뷰**에 실제로 친다.
///
/// 규칙 자체는 `ListEditing` 시험이 못 박는다. 여기서 보는 것은 배선이다: `insertNewline` 이 그 규칙을
/// 타는지, 되돌리기가 한 걸음으로 이어지는지, 조합 중에는 손대지 않는지, 빈 머리를 뗄 때 글자가 실제로
/// 지워지는지(`insertText` 에 빈 글을 준다).
@MainActor
@Suite("종이 — 목록 줄의 ⏎")
struct ListReturnTests {
    private final class Box { var text = "" }

    private func makeEditor(_ initial: String) -> (MemoNSTextView, NSWindow) {
        let font = NSFont.systemFont(ofSize: Paper.bodySize)
        let textView = MemoTextEditor.makeTextView(
            font: font, insets: NSSize(width: Theme.loose, height: Theme.loose), linePitch: Paper.linePitch
        )
        let box = Box()
        box.text = initial
        let coordinator = MemoTextEditor.Coordinator(
            text: Binding(get: { box.text }, set: { box.text = $0 }),
            onEdit: { _ in }, onCommand: { _, _ in false }
        )
        coordinator.stylesMarkdown = true
        coordinator.baseFont = font
        coordinator.paragraph = textView.defaultParagraphStyle
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.string = initial

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        coordinator.restyle(textView)
        // 되돌리기 시험을 위해 — 창의 undoManager 가 텍스트 뷰의 것이다.
        withExtendedLifetime(coordinator) {}
        return (textView, window)
    }

    private func caret(_ textView: NSTextView, at location: Int) {
        textView.setSelectedRange(NSRange(location: location, length: 0))
    }

    @Test("체크상자 줄 끝의 ⏎ 는 다음 줄에 빈 상자를 세운다 — 커서는 그 뒤")
    func continuesChecklist() {
        let (textView, window) = makeEditor("- [ ] 우유")
        defer { window.orderOut(nil) }
        caret(textView, at: 8)
        textView.insertNewline(nil)
        #expect(textView.string == "- [ ] 우유\n- [ ] ")
        #expect(textView.selectedRange() == NSRange(location: 15, length: 0))

        textView.insertText("계란", replacementRange: textView.selectedRange())
        #expect(textView.string == "- [ ] 우유\n- [ ] 계란")
    }

    @Test("빈 상자의 ⏎ 는 머리를 떼고 목록에서 나온다")
    func emptyItemLeavesTheList() {
        let (textView, window) = makeEditor("- [ ] 우유\n- [ ] ")
        defer { window.orderOut(nil) }
        caret(textView, at: 15)
        textView.insertNewline(nil)
        #expect(textView.string == "- [ ] 우유\n")
        #expect(textView.selectedRange() == NSRange(location: 9, length: 0))
        // 그 다음 ⏎ 는 그냥 줄바꿈이다.
        textView.insertNewline(nil)
        #expect(textView.string == "- [ ] 우유\n\n")
    }

    @Test("목록이 아닌 줄의 ⏎ 는 예전과 같다")
    func plainReturnIsUnchanged() {
        let (textView, window) = makeEditor("치과")
        defer { window.orderOut(nil) }
        caret(textView, at: 2)
        textView.insertNewline(nil)
        #expect(textView.string == "치과\n")
    }

    @Test("되돌리기 한 번에 이은 머리가 통째로 물러난다")
    func undoIsOneStep() {
        let (textView, window) = makeEditor("- 우유")
        defer { window.orderOut(nil) }
        caret(textView, at: 4)
        textView.insertNewline(nil)
        #expect(textView.string == "- 우유\n- ")
        textView.undoManager?.undo()
        #expect(textView.string == "- 우유")
    }

    @Test("조합 중의 ⏎ 는 손대지 않는다 — 입력기의 키다")
    func leavesCompositionAlone() {
        let (textView, window) = makeEditor("- 우")
        defer { window.orderOut(nil) }
        caret(textView, at: 3)
        textView.setMarkedText("ㅠ", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 3, length: 0))
        #expect(textView.hasMarkedText())
        textView.insertNewline(nil)
        // 우리 규칙이 끼어들었다면 「- 」 가 이어졌을 것이다.
        #expect(!textView.string.contains("\n- "))
    }
}
