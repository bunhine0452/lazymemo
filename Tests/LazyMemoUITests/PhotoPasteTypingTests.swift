import AppKit
import SwiftUI
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 종이에 사진을 붙인 뒤 — 참조는 감춰진 채이고, 다음에 치는 글은 보이는가.
///
/// 사용자(2026-09-17): 「맥에서 사진 붙여넣기 하면 `![](attachments/…)` 텍스트가 보여」. 붙이는 순간은
/// 멀쩡했다. 600ms 뒤 자동 저장이 파일에 쓰고, 파일 감시가 그것을 도로 읽어 오는데 `MemoFile.decode` 가
/// 끝 줄바꿈을 떼므로 본문이 「달라져」 편집기에 되밀렸고, 커서가 글 끝 = `![](…)` 줄로 튀어 감춰 둔
/// 참조가 그 줄의 규칙대로 드러났다.
@MainActor
@Suite("종이 — 사진 붙인 뒤")
struct PhotoPasteTypingTests {
    private final class Box { var text = "" }

    private func makeEditor(_ initial: String) -> (MemoNSTextView, MemoTextEditor.Coordinator, NSWindow) {
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
        textView.onPasteImage = { _, ext in "\n![](attachments/photo.\(ext))\n" }
        textView.onFocusChange = { [weak coordinator] view, focused in coordinator?.focusChanged(view, focused: focused) }
        textView.string = initial

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        coordinator.restyle(textView)
        return (textView, coordinator, window)
    }

    private func makePasteboard(named name: String) -> NSPasteboard {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        let png = image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
            .flatMap { $0.representation(using: .png, properties: [:]) }
        let board = NSPasteboard(name: NSPasteboard.Name(name))
        board.clearContents()
        board.setData(png, forType: .png)
        return board
    }

    private func fontSize(at location: Int, in textView: NSTextView) -> CGFloat? {
        (textView.textStorage?.attribute(.font, at: location, effectiveRange: nil) as? NSFont)?.pointSize
    }

    @Test("사진을 붙인 뒤 친 글자는 보인다")
    func typedTextAfterPhotoIsVisible() {
        let (textView, _, window) = makeEditor("메모")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        textView.pasteboard = makePasteboard(named: "lazymemo.test.photo-typing")
        textView.paste(nil)

        let reference = (textView.string as NSString).range(of: "![](attachments/photo.png)")
        #expect(reference.location != NSNotFound)
        #expect(fontSize(at: reference.location, in: textView) == 0.01)

        textView.insertText("가", replacementRange: textView.selectedRange())
        let typed = (textView.string as NSString).range(of: "가")
        #expect(fontSize(at: typed.location, in: textView) == Paper.bodySize)
        #expect(fontSize(at: reference.location, in: textView) == 0.01)
    }
}

extension PhotoPasteTypingTests {
    /// 결함이 살던 길을 그대로 — 끝 줄바꿈이 떨어진 본문을 편집기에 되밀면 커서가 참조 줄로 가 참조가 드러난다.
    @Test("끝 줄바꿈이 잘린 본문을 되밀면 참조가 드러난다 — 그래서 되밀지 않는다")
    func trimmedBodyPushedBackRevealsTheReference() {
        let (textView, coordinator, window) = makeEditor("메모")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        textView.pasteboard = makePasteboard(named: "lazymemo.test.photo-trim")
        textView.paste(nil)

        let trimmed = textView.string.trimmingCharacters(in: .newlines)
        if MemoTextSync.apply(trimmed, to: textView) { coordinator.restyle(textView) }
        let reference = (textView.string as NSString).range(of: "![](attachments/photo.png)")
        #expect(textView.selectedRange().location == reference.location + reference.length)
        #expect((fontSize(at: reference.location, in: textView) ?? 0) > 1)
    }

    @Test("파일이 끝 줄바꿈만 떼고 돌아오면 종이는 글을 되밀지 않는다")
    func adoptIgnoresTrailingNewlineDifference() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-adopt-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(vault: root.appending(path: "vault", directoryHint: .isDirectory),
                             support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let previews = LinkPreviewStore(cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory), settings: settings)
        var memo = try await store.create(body: "메모")
        let model = NoteModel(memo: memo, store: store, previews: previews)

        model.text = "메모\n![](attachments/photo.png)\n"
        model.edited(model.text)
        await model.flush()
        #expect(model.text == "메모\n![](attachments/photo.png)\n")

        // 파일 감시가 도로 읽어 온 것 — 끝 줄바꿈이 없다.
        memo = try #require(try? MemoFile.decode(MemoFile.encode(model.memo), fallbackID: memo.id))
        #expect(memo.body == "메모\n![](attachments/photo.png)")
        model.adopt(memo)
        #expect(model.text == "메모\n![](attachments/photo.png)\n")

        // 진짜로 바뀐 것은 따라간다.
        var changed = memo
        changed.body = "메모\n![](attachments/photo.png)\n더 적음"
        model.adopt(changed)
        #expect(model.text == changed.body)
    }
}
