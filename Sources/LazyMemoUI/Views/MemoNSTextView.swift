import AppKit
import LazyMemoCore
import UniformTypeIdentifiers

/// 붙여넣기와 **종이 다루기**를 가로채는 텍스트 뷰.
///
/// 사진을 붙이면 Vault 안의 진짜 파일로 저장하고 본문에는 마크다운 참조만
/// 남긴다. 링크를 붙이면 마크다운 링크가 된다. **둘 다 본문은 여전히 사람이
/// 읽을 수 있는 마크다운이다** — 정본이 파일이라는 D4 를 붙여넣기에서도 지킨다.
///
/// 그리고 메모 창에서는 이 뷰가 종이의 거의 전부를 덮는다. 그래서 창을 옮기고
/// 손을 떼는 조작도 여기를 지날 수밖에 없다. 가르는 기준은 하나 —
/// **지금 이 메모를 쓰고 있는 중인가.** 쓰는 중이면 글자를 다루고, 아니면
/// 종이를 다룬다.
final class MemoNSTextView: NSTextView {
    /// 이미지 데이터를 저장하고 본문에 넣을 마크다운을 돌려준다. `nil` 이면 기본 붙여넣기.
    var onPasteImage: ((Data, String) -> String?)?
    /// 링크를 본문에 넣을 마크다운으로 바꾼다.
    var onPasteLink: ((URL) -> String?)?
    /// 메모 자체를 지우는 길. 주면 오른쪽 버튼 메뉴 끝에 붙는다.
    var onDelete: (() -> Void)?
    /// ⌘⏎ — "적기 끝". Return 은 다음 줄로 가므로 확정은 이 키가 맡는다.
    var onCommandReturn: (() -> Void)?

    /// 첫 응답자가 되거나 물러났다 — 커서 줄의 기호를 되살리거나 감출 때다 (`MemoTextEditor`).
    var onFocusChange: ((NSTextView, Bool) -> Void)?
    /// 편집 중이 아닐 때 본문 끌기를 창 이동으로 넘길지. 메모 창에서만 켠다.
    var movesWindowOnDrag = false
    /// Esc 로 편집에서 손을 뗄지. 빠른 입력은 Esc 를 자기가 쓰므로 끈다.
    var blursOnEscape = false
    /// Esc 가 손을 뗀 **다음** 할 일 — 메모 창에서는 종이를 치우는 길이다
    /// (`NoteView.onEscape`). 없으면 앱만 물러난다.
    var onEscape: (() -> Void)?

    /// 이 편집기의 바탕 글꼴.
    ///
    /// `NSTextView.font` 를 쓰면 안 된다 — 그것은 **첫 글자의 글꼴**을 돌려주는데,
    /// 첫 줄이 `## 제목` 이면 감춰 둔 `## `(0.01pt)를 물고 온다. 줄머리 표시의
    /// 높이 계산이 통째로 0 이 되어 표시가 기준선 위에 얹힌다.
    var baseFont: NSFont = .systemFont(ofSize: Paper.bodySize)

    /// 손떨림을 이동으로 치지 않는 거리. 이보다 덜 움직였으면 클릭이다.
    private static let dragThreshold: CGFloat = 3
    /// 글자 끝에서 이만큼까지는 아직 글의 자리로 친다.
    private static let blankMargin: CGFloat = 8
    /// 기준선에서 글자 눈높이까지의 비율.
    ///
    /// 라틴 글꼴의 x-높이도, 줄 상자의 한가운데도 한글에는 맞지 않았다.
    /// 렌더 결과를 픽셀로 재어 얻은 값이다 — 14pt 한글은 기준선 위 10.5pt,
    /// 아래 1.5pt 를 차지하므로 눈높이는 기준선에서 4.5pt 위, 곧 0.32em 이다.
    private static let hangulCenterRatio: CGFloat = 0.32

    /// 붙여넣을 수 있는 이미지 형식. 원본 데이터를 그대로 쓰려고 종류를 따진다 —
    /// 다시 인코딩하면 화질과 용량을 괜히 잃는다.
    private static let imageTypes: [(NSPasteboard.PasteboardType, String)] = [
        (.png, "png"),
        (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg"),
        (NSPasteboard.PasteboardType(UTType.heic.identifier), "heic"),
        (.tiff, "tiff"),
    ]

    /// 붙여넣기가 읽는 붙임판. 시험만 자기 것을 끼운다 — 사람이 쓰던
    /// 클립보드를 시험이 헤집지 않게.
    var pasteboard: NSPasteboard = .general

    /// 끌어다 놓을 수 있는 것. 붙여넣기가 받는 형식과 **같아야 한다** —
    /// ⌘V 로는 들어오는데 끌어다 놓으면 안 되는 사진이 생기면, 사용자에게는
    /// 그냥 "될 때도 있고 안 될 때도 있는" 것이 된다.
    static let draggedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL] + imageTypes.map(\.0)

    /// 지금 이 메모에 글을 쓰고 있는 중인가. 모든 갈림길의 기준이다.
    private var isEditing: Bool { window?.firstResponder === self }

    /// ⌘⏎ 는 표준 선택자가 없어 `doCommandBy` 로 오지 않는다. 직접 집는다.
    ///
    /// 표준 편집 단축키도 여기서 직접 받는다 — 까닭은 `editingActions` 에 있다.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let onCommandReturn,
           event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "\r" {
            onCommandReturn()
            return true
        }
        if isEditing, let action = Self.editingAction(for: event), perform(action) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// 알아낸 편집 동작을 **우리 자신에게 곧바로** 시킨다.
    ///
    /// 여기가 두 번째 구멍이었다. 메인 메뉴를 건너뛰어 놓고도 `NSApp.sendAction(_:to:nil)`
    /// 로 보내고 있었는데, 그 함수는 대상을 **키 윈도의 응답 체인**에서 찾는다.
    /// 빠른 입력 상자는 `.nonactivatingPanel` 이라 앱이 활성이 아니면 키 윈도가
    /// 아예 없고(`NSApp.keyWindow == nil`), 그러면 첫 응답자가 바로 이 뷰인데도
    /// 대상을 못 찾아 **아무 일도 일어나지 않는다.** 글자는 쳐지는데 ⌘V 만 죽는
    /// 것이 정확히 이것이다 — 빠른 입력에서 사진이 안 붙던 까닭.
    ///
    /// 대상을 찾을 이유가 없다. 지금 글을 받고 있는 것이 우리이므로 우리가 한다.
    /// 되돌리기만 우리 것이 아니라 `undoManager` 에게 넘긴다.
    private func perform(_ action: Selector) -> Bool {
        switch action {
        case #selector(NSText.paste(_:)): paste(nil)
        case #selector(NSTextView.pasteAsPlainText(_:)): pasteAsPlainText(nil)
        case #selector(NSText.copy(_:)): copy(nil)
        case #selector(NSText.cut(_:)): cut(nil)
        case #selector(NSText.selectAll(_:)): selectAll(nil)
        case Selector(("undo:")):
            guard let undoManager, undoManager.canUndo else { return false }
            undoManager.undo()
        case Selector(("redo:")):
            guard let undoManager, undoManager.canRedo else { return false }
            undoManager.redo()
        default: return false
        }
        return true
    }

    /// ⌘V·⌘C·⌘X·⌘A·⌘Z 를 **메인 메뉴에 기대지 않고** 여기서 받는다.
    ///
    /// macOS 는 표준 편집 단축키를 메인 메뉴를 통해서만 응답 체인에 흘려보내고
    /// (`StandardMenu`), 메인 메뉴의 단축키는 **앱이 활성일 때만** 산다.
    /// 그런데 빠른 입력 상자는 `.nonactivatingPanel` 이다 — 앱을 앞으로
    /// 끌어내지 않고 키 입력만 받는 창이라, 활성화가 늦거나 거절되면
    /// **글자는 쳐지는데 ⌘V 만 죽는다.** 실제로 그렇게 나타났다.
    ///
    /// 창의 `performKeyEquivalent` 는 메인 메뉴보다 **먼저** 불리므로, 여기서
    /// 집으면 앱이 활성이든 아니든 같은 일이 일어난다. 메모 창도 같은 길을
    /// 타므로 두 곳의 동작이 갈리지 않는다.
    ///
    /// 여기서 알아낸 동작은 `perform(_:)` 이 **직접** 수행한다 — 응답 체인에
    /// 되던지면 키 윈도가 없는 그 상황에서 다시 길을 잃기 때문이다.
    private static func editingAction(for event: NSEvent) -> Selector? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.control), !flags.contains(.function)
        else { return nil }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return nil }

        let shifted = flags.contains(.shift)
        let optioned = flags.contains(.option)

        switch key {
        case "v":
            // ⌥⇧⌘V — 서식 없이 붙여넣기. 마크다운이 정본이라 이쪽도 살려 둔다.
            return (shifted && optioned) ? #selector(NSTextView.pasteAsPlainText(_:)) : #selector(NSText.paste(_:))
        case "c" where !shifted && !optioned: return #selector(NSText.copy(_:))
        case "x" where !shifted && !optioned: return #selector(NSText.cut(_:))
        case "a" where !shifted && !optioned: return #selector(NSText.selectAll(_:))
        case "z" where !optioned: return shifted ? Selector(("redo:")) : Selector(("undo:"))
        default: return nil
        }
    }

    // MARK: 끌어놓기

    /// 사진을 **끌어다 놓을 수 있다.**
    ///
    /// 붙여넣기만 되면 파인더에서 가져올 때 열기→복사→돌아오기가 필요하다.
    /// 끌어놓기는 그 세 조작을 하나로 줄인다. 처리는 붙여넣기와 같은 길을 탄다 —
    /// 파일은 Vault 안으로 들어오고 본문에는 마크다운 참조만 남는다 (D4).
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let markdown = imageMarkdown(from: sender.draggingPasteboard) {
            // 끌어다 놓은 자리에 넣는다. 커서가 있던 곳이 아니라.
            let point = convert(sender.draggingLocation, from: nil)
            placeCursor(at: point)
            window?.makeFirstResponder(self)
            insertPasted(markdown)
            return true
        }
        return super.performDragOperation(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        imageMarkdown(from: sender.draggingPasteboard) != nil
            ? .copy
            : super.draggingEntered(sender)
    }

    override func paste(_ sender: Any?) {
        if pasteHandled(pasteboard) { return }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if pasteHandled(pasteboard) { return }
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

    func imageMarkdown(from pasteboard: NSPasteboard) -> String? {
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

    // MARK: 첫 클릭

    /// **창이 활성이 아니어도 첫 클릭이 그대로 먹힌다.**
    ///
    /// 기본값이면 다른 앱을 쓰다가 메모를 눌렀을 때 첫 클릭은 앱을 깨우는 데만
    /// 쓰이고 사라진다. 사용자에게는 "눌렀는데 안 써진다" 로 보인다 — 바탕화면에
    /// 놓인 종이에서 이건 말이 안 된다.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocusChange?(self, true) }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(self, false) }
        return resigned
    }

    // MARK: 누르기 — 글자를 다루는가, 종이를 다루는가

    /// 링크는 한 번 눌러 연다. 단, **편집 중이 아닐 때만.**
    ///
    /// 언제나 열어 버리면 링크 글자를 고칠 수가 없다. 반대로 언제나 커서만
    /// 놓으면 붙여넣은 링크가 장식이 된다. ⌘클릭은 언제나 연다.
    ///
    /// 링크가 아니면 **끌기는 종이를 옮기고, 클릭은 커서를 세운다.** 메모 본문은
    /// 창의 거의 전부라, 여기서 넘겨주지 않으면 메모를 옮길 방법이 없어진다.
    override func mouseDown(with event: NSEvent) {
        // 체크상자가 먼저다. 종이를 끌거나 커서를 세우기 전에 본다.
        if event.clickCount == 1, toggleCheckbox(at: convert(event.locationInWindow, from: nil)) {
            return
        }

        let wantsOpen = !isEditing || event.modifierFlags.contains(.command)

        if wantsOpen, event.clickCount == 1,
           let destination = link(at: convert(event.locationInWindow, from: nil)),
           let url = URL(string: destination) {
            // 링크는 언제나 먼저다 — 붙여넣은 링크가 장식이 되면 안 된다.
            NSWorkspace.shared.open(url)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        // 쓰는 중이라도 **글자가 없는 자리**를 끄는 것은 종이를 옮기려는 뜻이다.
        // 그러지 않으면 방금 쓴 메모를 옮기려 할 때마다 다른 앱을 한 번
        // 눌러 편집을 끝내야 한다.
        let handlesPaper = movesWindowOnDrag && (!isEditing || isOnBlankPaper(point))

        guard handlesPaper, let window else {
            super.mouseDown(with: event)
            return
        }

        dragPaper(from: event, in: window)
    }

    /// 글자가 닿지 않는 여백인가. 마지막 줄 아래와 각 줄의 오른쪽 빈 자리다.
    private func isOnBlankPaper(_ point: CGPoint) -> Bool {
        guard let layoutManager, let textContainer,
              let storage = textStorage, storage.length > 0
        else { return true }

        let inset = textContainerInset
        let inContainer = CGPoint(x: point.x - inset.width, y: point.y - inset.height)

        if inContainer.y > layoutManager.usedRect(for: textContainer).maxY { return true }

        let glyph = layoutManager.glyphIndex(for: inContainer, in: textContainer)
        let line = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
        // 글자 끝에 바짝 붙은 곳은 아직 글의 자리다 — 커서를 놓으려는 손이 많다.
        return inContainer.x > line.maxX + Self.blankMargin
    }

    /// 종이를 끈다. 안 끌었으면 그 자리에 커서를 세운다.
    ///
    /// `performDrag` 가 마우스를 놓을 때까지 붙잡고 있으므로, 끝난 뒤 창이
    /// 실제로 움직였는지로 "끌기였나 클릭이었나" 를 가른다. 여기서 다시
    /// `super.mouseDown` 을 부르면 이미 끝난 마우스 업을 기다리며 멈춰 버린다.
    private func dragPaper(from event: NSEvent, in window: NSWindow) {
        let before = window.frame.origin
        window.performDrag(with: event)
        let after = window.frame.origin

        let moved = hypot(after.x - before.x, after.y - before.y)
        guard moved < Self.dragThreshold else { return }

        // 손이 떨린 만큼 종이가 밀려나 있으면 되돌린다. 누르기만 했는데
        // 메모가 1픽셀 움직이는 것도 조작감을 갉아먹는다.
        if moved > 0 { window.setFrameOrigin(before) }

        window.makeFirstResponder(self)
        placeCursor(at: convert(event.locationInWindow, from: nil))
    }

    private func placeCursor(at point: CGPoint) {
        guard let layoutManager, let textContainer, let storage = textStorage else { return }
        let inset = textContainerInset
        let inContainer = CGPoint(x: point.x - inset.width, y: point.y - inset.height)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(
            for: inContainer, in: textContainer, fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        setSelectedRange(NSRange(location: min(index, storage.length), length: 0))
    }

    // MARK: 줄머리 표시 그리기

    /// 감춰 둔 마커 자리에 진짜 체크상자와 점을 그린다 (`LineMarker`).
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        forEachLineMarker { marker, _, frame in
            guard frame.intersects(dirtyRect) else { return }
            marker.draw(
                at: frame.minX, centerY: frame.midY, lineHeight: frame.height,
                ink: Paper.inkNSColor
            )
        }
    }

    /// 화면에 그려진 줄머리 표시를 하나씩 짚는다.
    ///
    /// - Parameter body: 표시 종류, 그 표시가 붙은 내용 구간, 여백에서의 자리.
    func forEachLineMarker(_ body: (LineMarker, NSRange, NSRect) -> Void) {
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0
        else { return }

        let inset = textContainerInset
        let padding = textContainer.lineFragmentPadding
        let full = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(.lineMarker, in: full) { value, range, _ in
            guard let raw = value as? Int, let marker = LineMarker(rawValue: raw) else { return }

            let glyph = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: range.location, length: 1),
                actualCharacterRange: nil
            ).location
            var line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            line.origin.x += inset.width + padding
            line.origin.y += inset.height

            // 기준선에서 한글 글자 높이의 절반만큼 올린 곳이 눈높이다.
            //
            // 여기까지 두 번 틀렸다. 라틴 글꼴의 x-높이는 한글에 맞지 않고(한글은
            // x-높이라는 것이 없다), 줄 상자의 한가운데는 글자가 상자 안에서
            // 아래로 앉기 때문에 이번엔 반대로 높았다. 한글 글자는 기준선 위로
            // 약 0.72em 을 채우므로 그 절반이 실제 눈높이다.
            let baseline = line.minY + layoutManager.location(forGlyphAt: glyph).y
            let centerY = baseline - baseFont.pointSize * Self.hangulCenterRatio

            body(marker, range, NSRect(
                x: line.minX, y: centerY - line.height / 2,
                width: marker.gutter, height: line.height
            ))
        }
    }

    /// 눌린 자리에 체크상자가 있으면 표시를 뒤집는다.
    ///
    /// 게으른 사람에게 "다 했다" 를 알리려고 `[ ]` 를 `[x]` 로 **글자를 고치게
    /// 하는 것**은 불편의 극치다. 눌러서 끝나야 한다. 창에 포커스가 없어도
    /// 되는데, 바탕화면의 종이는 지나가다 툭 누르는 물건이기 때문이다.
    func toggleCheckbox(at point: CGPoint) -> Bool {
        var target: NSRange?
        forEachLineMarker { marker, range, frame in
            guard marker.isCheckbox, target == nil else { return }
            let box = marker.box(at: frame.minX, centerY: frame.midY, lineHeight: frame.height)
            // 누르는 자리는 그림보다 넉넉해야 한다. 12pt 사각형을 정확히
            // 맞히라고 요구하면 그것부터가 불편이다.
            guard box.insetBy(dx: -5, dy: -4).contains(point) else { return }
            target = range
        }

        guard let target, let storage = textStorage else { return false }
        let source = storage.string as NSString
        let lineStart = source.lineRange(for: target).location
        let marker = NSRange(location: lineStart, length: target.location - lineStart)
        let bracket = source.range(of: "[", options: [], range: marker).location
        guard bracket != NSNotFound, bracket + 2 < source.length else { return false }

        let slot = NSRange(location: bracket + 1, length: 1)
        let replacement = source.substring(with: slot) == " " ? "x" : " "
        guard shouldChangeText(in: slot, replacementString: replacement) else { return false }
        storage.replaceCharacters(in: slot, with: replacement)
        didChangeText()
        return true
    }

    // MARK: 손 떼기

    /// Esc — 편집에서 손을 뗀다. 메모 창이면 종이째 치운다 (`onEscape`).
    ///
    /// 첫 응답자를 놓는 것만으로는 부족하다. 상주 앱이 활성인 채로 남으면
    /// 사용자가 하던 앱으로 키보드가 돌아가지 않아, 그 다음 타자가 허공으로
    /// 간다. 앱을 물러나게 해야 종이도 바탕화면으로 내려앉는다 — 종이를
    /// 치우는 길(`onEscape`)도 끝에서 같은 일을 한다.
    ///
    /// **한글 조합 중에는 손대지 않는다.** 조합 중의 Esc 는 입력기의 것이다 —
    /// 「장」을 치다 만 자모를 거두는 키가 종이를 서랍에 넣으면 안 된다.
    ///
    /// `super` 를 부르지 않는다. `NSTextView` 는 이 선택자를 **구현하지 않아**
    /// 부르면 그대로 떨어진다(unrecognized selector). 우리 몫이 아니면 응답자
    /// 사슬을 손으로 잇는다 — `tryToPerform` 은 받는 이가 없으면 조용히 끝난다.
    override func cancelOperation(_ sender: Any?) {
        guard !hasMarkedText() else { return }
        guard blursOnEscape || onEscape != nil else {
            nextResponder?.tryToPerform(#selector(cancelOperation(_:)), with: sender)
            return
        }
        window?.makeFirstResponder(nil)
        if let onEscape {
            onEscape()
        } else {
            NSApplication.shared.deactivate()
        }
    }

    // MARK: 오른쪽 버튼 — 지우는 유일한 길

    /// 표준 편집 항목 뒤에 메모 자체에 대한 조작을 붙인다.
    ///
    /// 조작 줄(호버)에 휴지통을 하나 더 두는 쪽도 있었지만, 「치우기(×)」 바로
    /// 옆에 「지우기」가 서면 둘이 닮아서 잘못 누른다. 지우기는 자주 하는 일이
    /// 아니므로 오른쪽 버튼 뒤에 두는 편이 안전하고, macOS 에서 이 자리는
    /// 사람들이 이미 찾아보는 곳이다.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard onDelete != nil else { return menu }

        if !menu.items.isEmpty { menu.addItem(.separator()) }
        let item = NSMenuItem(title: L("이 메모 지우기"), action: #selector(deleteMemo), keyEquivalent: "")
        item.target = self
        // 되돌릴 수 있다는 것을 누르기 **전에** 알려준다 (D6).
        item.subtitle = L("메뉴바 「최근 삭제」에서 되돌릴 수 있습니다")
        menu.addItem(item)
        return menu
    }

    @objc private func deleteMemo() {
        onDelete?()
    }

    // MARK: 링크 찾기

    override func resetCursorRects() {
        super.resetCursorRects()
        // 링크 위에서는 손가락 커서가 떠야 누를 수 있다는 것이 보인다.
        guard let storage = textStorage else { return }
        storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) {
            value, range, _ in
            guard value != nil, let rect = boundingRect(for: range) else { return }
            addCursorRect(rect, cursor: .pointingHand)
        }

        // 체크상자도 누를 수 있다는 것이 보여야 누른다.
        forEachLineMarker { marker, _, frame in
            guard marker.isCheckbox else { return }
            let box = marker.box(at: frame.minX, centerY: frame.midY, lineHeight: frame.height)
            addCursorRect(box.insetBy(dx: -5, dy: -4), cursor: .pointingHand)
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
