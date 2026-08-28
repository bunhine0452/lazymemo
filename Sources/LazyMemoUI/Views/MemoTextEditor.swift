import AppKit
import SwiftUI

/// `NSTextView` 기반 편집기 (설계문서 §8).
///
/// SwiftUI `TextEditor` 를 쓰지 않는 이유는 **한글 IME 조합** 하나다. 조합 중인
/// 글자는 아직 문자열이 아니라 텍스트 뷰가 들고 있는 임시 상태인데, 상위에서
/// 문자열을 되밀어 넣으면 그 상태가 깨져 자모가 흩어진다. `NSTextView` 에
/// 조합을 통째로 맡기고, 우리는 조합이 끝난 결과만 읽는다.
struct MemoTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 14)
    var insets: NSSize = NSSize(width: 12, height: 10)
    /// 조합이 끝난 시점의 텍스트만 흘려보낸다. 자동 저장이 여기에 걸린다.
    var onEdit: (String) -> Void = { _ in }
    /// Return·Esc·화살표를 가로챈다. `true` 를 돌려주면 텍스트 뷰는 처리하지 않는다.
    var onCommand: (Selector) -> Bool = { _ in false }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text

        textView.drawsBackground = false
        textView.isRichText = false
        textView.font = font
        textView.textContainerInset = insets
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

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // 조합 보호 규칙은 MemoTextSync 에 있다 — 테스트가 그쪽을 지킨다.
        MemoTextSync.apply(text, to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEdit: onEdit, onCommand: onCommand)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>
        private let onEdit: (String) -> Void
        private let onCommand: (Selector) -> Bool
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            onEdit: @escaping (String) -> Void,
            onCommand: @escaping (Selector) -> Bool
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
            return onCommand(selector)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let current = textView.string
            text.wrappedValue = current

            // 조합 중인 자모는 아직 확정된 글자가 아니다. 그대로 저장하면
            // 파일에 "ㅊ" 같은 중간 상태가 남는다.
            guard !textView.hasMarkedText() else { return }
            onEdit(current)
        }

        /// 조합이 끝나거나 포커스를 잃을 때 마지막 상태를 확정한다.
        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            onEdit(textView.string)
        }
    }
}
