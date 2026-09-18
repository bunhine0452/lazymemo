import AppKit
import SwiftUI
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 마크다운 표 — 글자를 바꾸지 않고(§15.1) 열이 맞는가. 세로선 앞 글자의 kern 으로 맞추므로
/// 파일의 글자·길이는 그대로여야 하고, 같은 열의 세로선은 같은 x 에 서야 한다.
@MainActor
@Suite("종이 — 표의 열이 맞는다")
struct TableAlignmentTests {
    private final class Box { var text = "" }

    private func makeEditor(_ initial: String) -> (MemoNSTextView, MemoTextEditor.Coordinator, NSWindow) {
        let font = NSFont.systemFont(ofSize: Paper.bodySize)
        let textView = MemoTextEditor.makeTextView(
            font: font, insets: NSSize(width: Theme.loose, height: Theme.loose), linePitch: Paper.linePitch
        )
        let box = Box(); box.text = initial
        let coordinator = MemoTextEditor.Coordinator(
            text: Binding(get: { box.text }, set: { box.text = $0 }), onEdit: { _ in }, onCommand: { _, _ in false }
        )
        coordinator.stylesMarkdown = true
        coordinator.baseFont = font
        coordinator.paragraph = textView.defaultParagraphStyle
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.string = initial
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        coordinator.restyle(textView, focused: false)
        return (textView, coordinator, window)
    }

    /// 글자 `location` 의 왼쪽 x.
    private func x(of location: Int, in textView: NSTextView) -> CGFloat {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return -1 }
        layoutManager.ensureLayout(for: container)
        let glyph = layoutManager.glyphIndexForCharacter(at: location)
        return layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container).minX
    }

    @Test("같은 열의 세로선은 같은 x 에 선다 — 글자는 하나도 안 바뀐다")
    func columnsLineUp() {
        let text = "| 구분 | 금액 |\n| --- | --- |\n| 시급 | 10,320원 |\n| 월급(209시간) | 2,156,880원 |"
        let (textView, _, window) = makeEditor(text)
        defer { window.orderOut(nil) }
        #expect(textView.string == text)
        let source = text as NSString
        // 각 줄의 둘째·셋째 세로선
        var seconds: [CGFloat] = [], thirds: [CGFloat] = []
        var location = 0
        for row in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(row)
            let pipes = MarkdownScanner.tablePipes(in: line)
            if pipes.count == 3 {
                seconds.append(x(of: location + pipes[1], in: textView))
                thirds.append(x(of: location + pipes[2], in: textView))
            }
            location += (line as NSString).length + 1
        }
        #expect(seconds.count == 3 && thirds.count == 3)
        #expect((seconds.max()! - seconds.min()!) < 1.0, "둘째 세로선 x: \(seconds)")
        #expect((thirds.max()! - thirds.min()!) < 1.0, "셋째 세로선 x: \(thirds)")
        // 가장 넓은 칸(월급 줄)보다 좁은 칸들이 오른쪽으로 밀려 있다
        _ = source
    }

    @Test("한 줄만 고쳐도 표 전체가 다시 맞춰진다")
    func editingOneRowRealignsTheTable() {
        let text = "| 구분 | 금액 |\n| --- | --- |\n| 시급 | 10원 |"
        let (textView, coordinator, window) = makeEditor(text)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(textView)
        coordinator.focusChanged(textView, focused: true)
        // 셋째 줄 「10원」 뒤에 글자를 더 넣는다 — 그 열이 넓어져 머리 줄의 세로선도 밀려야 한다
        let insertAt = (text as NSString).range(of: "10원").location + 3
        textView.setSelectedRange(NSRange(location: insertAt, length: 0))
        textView.insertText(",000,000", replacementRange: textView.selectedRange())
        let now = textView.string as NSString
        let headerPipes = MarkdownScanner.tablePipes(in: "| 구분 | 금액 |")
        let lastLine = now.lineRange(for: NSRange(location: now.length - 1, length: 0))
        let lastPipes = MarkdownScanner.tablePipes(in: now.substring(with: lastLine).trimmingCharacters(in: .newlines))
        let headerThird = x(of: headerPipes[2], in: textView)
        let lastThird = x(of: lastLine.location + lastPipes[2], in: textView)
        #expect(abs(headerThird - lastThird) < 1.0, "머리 \(headerThird) vs 마지막 \(lastThird)")
    }
}
