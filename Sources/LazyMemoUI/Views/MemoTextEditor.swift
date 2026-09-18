import AppKit
import LazyMemoCore
import SwiftUI

/// `NSTextView` 기반 편집기 (설계문서 §8).
///
/// SwiftUI `TextEditor` 를 쓰지 않는 이유는 **한글 IME 조합** 하나다. 조합 중인
/// 글자는 아직 문자열이 아니라 텍스트 뷰가 들고 있는 임시 상태인데, 상위에서
/// 문자열을 되밀어 넣으면 그 상태가 깨져 자모가 흩어진다. `NSTextView` 에
/// 조합을 통째로 맡기고, 우리는 조합이 끝난 결과만 읽는다.
struct MemoTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: Paper.bodySize)
    var insets: NSSize = NSSize(width: 12, height: 10)
    /// 괘선 간격. 주면 글줄이 그 높이에 맞춰 앉는다.
    var linePitch: CGFloat?
    /// 마크다운을 친 자리에서 바로 꾸밀지. 빠른 입력처럼 한 줄 적고 마는
    /// 자리에서는 끈다 — 치는 동안 글자가 계속 움직이면 오히려 방해가 된다.
    var stylesMarkdown = false
    /// 꾸밈은 끄되 **사진 참조만** 감출지. 빠른 입력이 이것만 켠다 —
    /// 붙인 사진은 조각으로 보이므로 경로 글자는 자리만 차지한다.
    var hidesImageReferences = false
    var onPasteImage: ((Data, String) -> String?)?
    var onPasteLink: ((URL) -> String?)?
    /// 메모 자체를 지우는 길. 오른쪽 버튼 메뉴에 붙는다.
    var onDelete: (() -> Void)?
    /// 편집 중이 아닐 때 본문 끌기로 창을 옮길지. 메모 창에서만 켠다 —
    /// 본문이 창을 거의 다 덮고 있어서, 넘겨주지 않으면 옮길 자리가 없다.
    var movesWindow = false
    /// Esc 로 편집에서 손을 뗄지. 빠른 입력은 Esc 를 자기가 쓰므로 끈다.
    var blursOnEscape = false
    /// Esc 가 손을 뗀 다음 할 일 — 메모 창은 여기서 종이를 치운다.
    var onEscape: (() -> Void)?
    /// 조합이 끝난 시점의 텍스트만 흘려보낸다. 자동 저장이 여기에 걸린다.
    var onEdit: (String) -> Void = { _ in }
    /// Return·Esc·화살표를 가로챈다. `true` 를 돌려주면 텍스트 뷰는 처리하지 않는다.
    ///
    /// 텍스트 뷰를 함께 넘기는 이유: 여러 줄이 되면 ↑↓ 가 글줄 이동과 목록
    /// 이동을 겸해야 해서, 지금 커서가 첫 줄인지 끝 줄인지를 알아야 한다.
    var onCommand: (Selector, NSTextView) -> Bool = { _, _ in false }
    /// ⌘⏎ — 적기 끝.
    var onCommandReturn: (() -> Void)?
    /// 글이 차지한 높이. 빠른 입력 상자가 줄 수에 맞춰 자라는 근거다.
    var onHeightChange: ((CGFloat) -> Void)?

    /// 편집기의 텍스트 뷰를 짓는다.
    ///
    /// 미리보기 렌더(`PreviewRenderer`)도 **이 함수를 쓴다.** 설정이 갈라지는
    /// 순간 미리보기는 실제 화면과 다른 것을 그리고, 그러면 눈으로 확인하는
    /// 일 자체가 거짓말이 된다.
    @MainActor
    static func makeTextView(font: NSFont, insets: NSSize, linePitch: CGFloat?) -> MemoNSTextView {
        let textView = MemoNSTextView()
        textView.baseFont = font
        textView.drawsBackground = false
        textView.isRichText = false
        textView.font = font
        textView.textColor = Paper.inkNSColor
        textView.insertionPointColor = Paper.inkNSColor
        textView.textContainerInset = insets

        // 글줄 높이를 못박아 괘선 위에 앉게 한다. 종이의 줄 간격이 글자
        // 크기에 따라 흔들리면 줄과 글이 어긋나 가짜처럼 보인다.
        if let pitch = linePitch {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = pitch
            paragraph.maximumLineHeight = pitch
            textView.defaultParagraphStyle = paragraph
            textView.typingAttributes = [
                .font: font,
                .paragraphStyle: paragraph,
                .foregroundColor: Paper.inkNSColor,
            ]
        }
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        // 마크다운이 정본이다 (D4). 따옴표·하이픈을 예쁘게 바꾸면 파일이 오염된다.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        return textView
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = Self.makeTextView(font: font, insets: insets, linePitch: linePitch)
        textView.delegate = context.coordinator
        textView.onPasteImage = onPasteImage
        textView.onPasteLink = onPasteLink
        textView.onDelete = onDelete
        textView.onCommandReturn = onCommandReturn
        textView.movesWindowOnDrag = movesWindow
        textView.blursOnEscape = blursOnEscape
        textView.onEscape = onEscape
        textView.deletesPhotoReferencesWhole = stylesMarkdown || hidesImageReferences
        textView.string = text

        scrollView.documentView = textView
        textView.registerForDraggedTypes(MemoNSTextView.draggedTypes)
        context.coordinator.textView = textView
        textView.onFocusChange = { [weak coordinator = context.coordinator] view, focused in
            coordinator?.focusChanged(view, focused: focused)
        }
        context.coordinator.onHeightChange = onHeightChange
        context.coordinator.stylesMarkdown = stylesMarkdown
        context.coordinator.hidesImageReferences = hidesImageReferences
        context.coordinator.baseFont = font
        context.coordinator.paragraph = textView.defaultParagraphStyle
        context.coordinator.restyle(textView)
        // 첫 높이는 레이아웃이 끝난 다음에야 알 수 있다.
        DispatchQueue.main.async { context.coordinator.reportHeight() }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // 닫힘 위에 붙잡힌 값들은 갱신될 때마다 갈아 끼운다.
        (textView as? MemoNSTextView)?.onDelete = onDelete
        (textView as? MemoNSTextView)?.onCommandReturn = onCommandReturn
        (textView as? MemoNSTextView)?.onEscape = onEscape
        context.coordinator.onHeightChange = onHeightChange
        // 조합 보호 규칙은 MemoTextSync 에 있다 — 테스트가 그쪽을 지킨다.
        if MemoTextSync.apply(text, to: textView) {
            context.coordinator.restyle(textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEdit: onEdit, onCommand: onCommand)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>
        private let onEdit: (String) -> Void
        private let onCommand: (Selector, NSTextView) -> Bool
        var onHeightChange: ((CGFloat) -> Void)?
        private var reportedHeight: CGFloat = -1
        weak var textView: NSTextView?

        var stylesMarkdown = false
        var hidesImageReferences = false
        var baseFont: NSFont = .systemFont(ofSize: Paper.bodySize)
        var paragraph: NSParagraphStyle?

        private var isRestyling = false
        private var isMovingCaret = false
        private var activeLine: NSRange?

        /// 꾸밈을 다시 입힌다. 빠른 입력은 **사진 참조 감추기만** 한다.
        ///
        /// **조합 중에는 하지 않는다.** 속성을 통째로 다시 까는 동안 조합
        /// 밑줄이 지워져 한글 입력이 어디까지 됐는지 알 수 없게 된다.
        func restyle(_ textView: NSTextView, focused: Bool? = nil) {
            guard stylesMarkdown || hidesImageReferences, !textView.hasMarkedText(),
                  let storage = textView.textStorage
            else { return }

            let selection = textView.selectedRange()
            // 커서 줄은 **글을 치고 있는 동안에만** 있다. 첫 응답자가 아닌 종이의
            // 선택은 글 끝에 놓인 기본값이라, 그것을 커서로 치면 바탕화면의 모든
            // 종이가 마지막 줄만 `- [ ]` 원문을 드러낸 채 서 있다.
            let hasFocus = focused ?? (textView.window?.firstResponder === textView)
            activeLine = hasFocus ? (textView.string as NSString).lineRange(for: selection) : nil

            isRestyling = true
            if stylesMarkdown {
                MarkdownStyler.apply(
                    to: storage, baseFont: baseFont, paragraph: paragraph, activeLine: activeLine
                )
            } else {
                MarkdownStyler.hideImageReferences(to: storage, baseFont: baseFont, paragraph: paragraph)
            }
            textView.setSelectedRange(selection)
            isRestyling = false
            unhideTypingAttributes(textView)
        }

        /// 커서가 다른 줄로 가면 기호를 감추고, 온 줄에서는 되살린다.
        ///
        /// 사진 참조는 커서 줄에서도 감춘 채라(`MarkdownStyler`) 커서를 그 안에 들이지 않는다 —
        /// 보이지 않는 곳에 친 글자는 잃은 글자다. 폰의 글 칸과 같은 규칙 (`MachineLines.caret`).
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRestyling, !isMovingCaret, stylesMarkdown || hidesImageReferences,
                  let textView = notification.object as? NSTextView,
                  !textView.hasMarkedText()
            else { return }

            if keepCaretOutOfPhotos(textView) { return }
            unhideTypingAttributes(textView)
            let line = (textView.string as NSString).lineRange(for: textView.selectedRange())
            guard line != activeLine else { return }
            restyle(textView)
        }

        /// 커서가 감춘 사진 참조 안에 들어갔으면 그 뒤로. 옮겼으면 `true` — 옮긴 자리에서 이 콜백이 다시 온다.
        /// 선택 구간(길이가 있는 것)은 두 손이 잡은 것이라 건드리지 않는다.
        private func keepCaretOutOfPhotos(_ textView: NSTextView) -> Bool {
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return false }
            let text = textView.string
            let photos = MarkdownScanner.spans(in: text).compactMap { span -> MachineLines.Hidden? in
                guard case .image = span.kind else { return nil }
                return MachineLines.Hidden(range: span.range, kind: .photo)
            }
            let moved = MachineLines.caret(selection.location, avoiding: photos, in: text)
            guard moved != selection.location else { return false }
            isMovingCaret = true
            textView.setSelectedRange(NSRange(location: moved, length: 0))
            isMovingCaret = false
            return true
        }

        /// 감춘 글자(0.01pt) 바로 뒤에 선 커서는 그 글꼴을 물려받는다 — 조합 중의 한글이 보이지 않게 된다
        /// (조합 중엔 다시 꾸미지 않으므로). 치는 글자는 바탕 글꼴로.
        private func unhideTypingAttributes(_ textView: NSTextView) {
            guard let font = textView.typingAttributes[.font] as? NSFont, font.pointSize < 1 else { return }
            textView.typingAttributes = MarkdownStyler.baseAttributes(baseFont, paragraph)
        }

        /// 글이 차지한 높이를 알린다. 같은 값이면 알리지 않는다 —
        /// SwiftUI 상태를 다시 흔들면 갱신이 끝없이 돈다.
        func reportHeight() {
            guard let onHeightChange, let textView,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer
            else { return }
            layoutManager.ensureLayout(for: container)
            let height = (layoutManager.usedRect(for: container).height
                + textView.textContainerInset.height * 2).rounded()
            guard abs(height - reportedHeight) > 0.5 else { return }
            reportedHeight = height
            onHeightChange(height)
        }

        init(
            text: Binding<String>,
            onEdit: @escaping (String) -> Void,
            onCommand: @escaping (Selector, NSTextView) -> Bool
        ) {
            self.text = text
            self.onEdit = onEdit
            self.onCommand = onCommand
        }

        /// Return 으로 저장하고 Esc 로 닫는 동선(빠른 입력)을 위한 것.
        ///
        /// **조합 중이면 넘기지 않는다.** 한글 입력에서 Return 은 먼저
        /// 조합을 확정하는 키다. 여기서 가로채면 마지막 글자를 잃는다.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            return onCommand(selector, textView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let current = textView.string
            text.wrappedValue = current
            restyle(textView)
            reportHeight()

            // 조합 중인 자모는 아직 확정된 글자가 아니다. 그대로 저장하면
            // 파일에 "ㅊ" 같은 중간 상태가 남는다.
            guard !textView.hasMarkedText() else { return }
            onEdit(current)
        }

        /// 포커스가 오가면 커서 줄이 생기거나 없어진다 (`MemoNSTextView.onFocusChange`).
        /// 물러나는 중에는 창이 아직 이 뷰를 첫 응답자로 들고 있어, 값을 받아 쓴다.
        func focusChanged(_ textView: NSTextView, focused: Bool) {
            restyle(textView, focused: focused)
        }

        /// 조합이 끝나거나 포커스를 잃을 때 마지막 상태를 확정한다.
        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // 조합이 막 끝났으므로 이제 꾸밀 수 있다.
            restyle(textView)
            onEdit(textView.string)
        }
    }
}
