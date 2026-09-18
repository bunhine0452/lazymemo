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
///
/// 그리고 2026-09-18: 「사진 넣으면 텍스트 안 보이게 하라 했지? docx 에 사진 넣으면 텍스트 보이던?」 —
/// 커서가 그 줄에 오면 드러나는 규칙 자체를 없앴다. 참조는 언제나 감춰지고, 커서는 그 안에 못 들어가고,
/// ⌫ 는 참조를 한 덩이로 뗀다.
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
        textView.deletesPhotoReferencesWhole = true
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
    /// 결함이 살던 길 — 끝 줄바꿈이 떨어진 본문을 되밀면 커서가 참조 줄로 간다. 그래도 참조는 감춘 채다.
    @Test("끝 줄바꿈이 잘린 본문을 되밀어 커서가 참조 줄에 서도 참조는 감춘 채다")
    func trimmedBodyPushedBackKeepsTheReferenceHidden() {
        let (textView, coordinator, window) = makeEditor("메모")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        textView.pasteboard = makePasteboard(named: "lazymemo.test.photo-trim")
        textView.paste(nil)

        let trimmed = textView.string.trimmingCharacters(in: .newlines)
        if MemoTextSync.apply(trimmed, to: textView) { coordinator.restyle(textView) }
        let reference = (textView.string as NSString).range(of: "![](attachments/photo.png)")
        #expect(textView.selectedRange().location == reference.location + reference.length)
        #expect(fontSize(at: reference.location, in: textView) == 0.01)
        // 거기서 치는 글자는 바탕 글꼴 — 감춘 글꼴을 물려받지 않는다.
        #expect((textView.typingAttributes[.font] as? NSFont)?.pointSize == Paper.bodySize)
    }

    @Test("커서를 참조 안에 두면 참조 뒤로 나온다")
    func caretInsideReferenceIsPushedOut() {
        let (textView, _, window) = makeEditor("메모\n![](attachments/photo.png)\n더")
        defer { window.orderOut(nil) }
        let reference = (textView.string as NSString).range(of: "![](attachments/photo.png)")
        textView.setSelectedRange(NSRange(location: reference.location + 5, length: 0))
        #expect(textView.selectedRange() == NSRange(location: reference.location + reference.length, length: 0))
        #expect(fontSize(at: reference.location, in: textView) == 0.01)
        // 참조 머리·끝은 밖이다 — 거기 서면 그대로.
        textView.setSelectedRange(NSRange(location: reference.location, length: 0))
        #expect(textView.selectedRange().location == reference.location)
        // 선택은 건드리지 않는다.
        let selection = NSRange(location: 0, length: reference.location + 3)
        textView.setSelectedRange(selection)
        #expect(textView.selectedRange() == selection)
    }

    @Test("⌫ 는 참조를 한 덩이로 뗀다 — 먼저 줄바꿈, 다음에 사진")
    func backspaceDeletesTheWholeReference() {
        let (textView, _, window) = makeEditor("메모\n![](attachments/photo.png)\n")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.deleteBackward(nil)
        #expect(textView.string == "메모\n![](attachments/photo.png)")
        textView.deleteBackward(nil)
        #expect(textView.string == "메모\n")
        // 되돌리면 참조가 통째로 돌아오고, 여전히 감춘 채다. (런루프 없는 시험에서는 두 지우기가 한 묶음이다.)
        textView.undoManager?.undo()
        #expect(textView.string.hasPrefix("메모\n![](attachments/photo.png)"))
        #expect(fontSize(at: 3, in: textView) == 0.01)
    }

    @Test("⌦ 도 참조 앞에서 한 덩이로")
    func forwardDeleteRemovesTheWholeReference() {
        let (textView, _, window) = makeEditor("![](attachments/photo.png) 영수증")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.deleteForward(nil)
        #expect(textView.string == " 영수증")
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

    /// 사진 위의 「사진 떼기」— 참조의 줄이 빠지고 파일에 적힌다. 치던 글은 먼저 적힌다.
    @Test("사진 떼기 — 참조 줄이 빠지고, 치던 글은 남는다")
    func removePhotoDropsTheReferenceLine() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-remove-photo-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(vault: root.appending(path: "vault", directoryHint: .isDirectory),
                             support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let previews = LinkPreviewStore(cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory), settings: settings)
        let memo = try await store.create(body: "메모\n![](attachments/a.png)\n![](attachments/b.png)\n")
        let model = NoteModel(memo: memo, store: store, previews: previews)

        model.text = "메모\n![](attachments/a.png)\n![](attachments/b.png)\n덧붙임"
        model.edited(model.text)
        await model.removePhoto("attachments/a.png")
        #expect(model.text == "메모\n![](attachments/b.png)\n덧붙임")
        #expect(store.memo(memo.id)?.body == "메모\n![](attachments/b.png)\n덧붙임")
        #expect(MarkdownScanner.imagePaths(in: model.text) == ["attachments/b.png"])
    }
}
