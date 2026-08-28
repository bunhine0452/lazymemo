import AppKit
import LazyMemoCore
import UniformTypeIdentifiers

/// 붙여넣기를 가로채는 텍스트 뷰.
///
/// 사진을 붙이면 Vault 안의 진짜 파일로 저장하고 본문에는 마크다운 참조만
/// 남긴다. 링크를 붙이면 마크다운 링크가 된다. **둘 다 본문은 여전히 사람이
/// 읽을 수 있는 마크다운이다** — 정본이 파일이라는 D4 를 붙여넣기에서도 지킨다.
final class MemoNSTextView: NSTextView {
    /// 이미지 데이터를 저장하고 본문에 넣을 마크다운을 돌려준다. `nil` 이면 기본 붙여넣기.
    var onPasteImage: ((Data, String) -> String?)?
    /// 링크를 본문에 넣을 마크다운으로 바꾼다.
    var onPasteLink: ((URL) -> String?)?

    /// 붙여넣을 수 있는 이미지 형식. 원본 데이터를 그대로 쓰려고 종류를 따진다 —
    /// 다시 인코딩하면 화질과 용량을 괜히 잃는다.
    private static let imageTypes: [(NSPasteboard.PasteboardType, String)] = [
        (.png, "png"),
        (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg"),
        (NSPasteboard.PasteboardType(UTType.heic.identifier), "heic"),
        (.tiff, "tiff"),
    ]

    override func paste(_ sender: Any?) {
        if pasteHandled(NSPasteboard.general) { return }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if pasteHandled(NSPasteboard.general) { return }
        super.pasteAsPlainText(sender)
    }

    private func pasteHandled(_ pasteboard: NSPasteboard) -> Bool {
        if let markdown = imageMarkdown(from: pasteboard) {
            insertPasted(markdown)
            return true
        }
        if let markdown = linkMarkdown(from: pasteboard) {
            insertPasted(markdown)
            return true
        }
        return false
    }

    /// `insertText` 로 넣어야 되돌리기와 조합 상태가 정상으로 이어진다.
    private func insertPasted(_ markdown: String) {
        insertText(markdown, replacementRange: selectedRange())
    }

    // MARK: 사진

    private func imageMarkdown(from pasteboard: NSPasteboard) -> String? {
        guard let onPasteImage else { return nil }

        // 파인더에서 끌어온 이미지 파일이 먼저다. 원본 그대로 옮길 수 있다.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            let markdown = urls.compactMap { url -> String? in
                guard let type = UTType(filenameExtension: url.pathExtension),
                      type.conforms(to: .image),
                      let data = try? Data(contentsOf: url)
                else { return nil }
                return onPasteImage(data, url.pathExtension)
            }
            if !markdown.isEmpty { return markdown.joined(separator: "\n") }
        }

        for (type, fileExtension) in Self.imageTypes {
            guard let data = pasteboard.data(forType: type) else { continue }
            return onPasteImage(data, fileExtension)
        }

        return nil
    }

    // MARK: 링크

    private func linkMarkdown(from pasteboard: NSPasteboard) -> String? {
        guard let onPasteLink,
              let raw = pasteboard.string(forType: .string)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.contains(where: \.isWhitespace),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }

        return onPasteLink(url)
    }

    // MARK: 링크 열기

    /// 링크를 한 번 눌러 연다 — 단, **편집 중이 아닐 때만.**
    ///
    /// 언제나 열어 버리면 링크 글자를 고칠 수가 없다. 반대로 언제나 커서만
    /// 놓으면 붙여넣은 링크가 장식이 된다. 지금 이 메모를 쓰고 있는 중인지로
    /// 가른다 — 쓰는 중이면 커서, 아니면 열기. ⌘클릭은 언제나 연다.
    override func mouseDown(with event: NSEvent) {
        let isEditing = window?.firstResponder === self
        let wantsOpen = !isEditing || event.modifierFlags.contains(.command)

        guard wantsOpen, event.clickCount == 1,
              let destination = link(at: convert(event.locationInWindow, from: nil)),
              let url = URL(string: destination)
        else {
            super.mouseDown(with: event)
            return
        }
        NSWorkspace.shared.open(url)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        // 링크 위에서는 손가락 커서가 떠야 누를 수 있다는 것이 보인다.
        guard let storage = textStorage else { return }
        storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) {
            value, range, _ in
            guard value != nil, let rect = boundingRect(for: range) else { return }
            addCursorRect(rect, cursor: .pointingHand)
        }
    }

    private func link(at point: CGPoint) -> String? {
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0
        else { return nil }

        let inset = textContainerInset
        let inContainer = CGPoint(x: point.x - inset.width, y: point.y - inset.height)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(
            for: inContainer, in: textContainer, fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        guard index < storage.length else { return nil }
        return storage.attribute(.link, at: index, effectiveRange: nil) as? String
    }

    private func boundingRect(for range: NSRange) -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerInset.width
        rect.origin.y += textContainerInset.height
        return rect
    }
}
