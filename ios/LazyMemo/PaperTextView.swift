import SwiftUI
import UIKit

/// 종이 위의 글 칸 — `UITextView` 를 감싼다.
///
/// SwiftUI 의 `TextEditor` 로는 두 가지를 못 한다: 한글 조합 중인지
/// (`markedTextRange`) 아는 것, 그리고 바깥에서 온 글을 반영할 때 커서를
/// 제자리에 두는 것. 맥의 `MemoTextSync` 세 규칙을 그대로 지키려면 이게 필요하다.
struct PaperTextView: UIViewRepresentable {
    @Binding var text: String
    /// 열 때 키보드를 올릴지. 열어서 읽는 일이 적는 일만큼 많아 기본은 아니다.
    var focusesOnAppear = false
    var onEditingChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = UIColor(Paper.ink)
        view.tintColor = UIColor(Theme.accentInk)
        view.textContainerInset = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.text = text
        view.accessibilityIdentifier = "paper"
        if focusesOnAppear {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        // 모델 → 뷰. 조합 중이면 되밀지 않고, 같으면 대입하지 않고, 커서는 되돌린다.
        guard view.markedTextRange == nil, view.text != text else { return }
        let caret = view.selectedRange.location
        view.text = text
        view.selectedRange = NSRange(location: min(caret, (text as NSString).length), length: 0)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PaperTextView
        init(_ parent: PaperTextView) { self.parent = parent }

        func textViewDidChange(_ view: UITextView) {
            // 조합 중의 중간 글자는 모델에 올리지 않는다 — 올리면 저장이 자모를 쪼갠다.
            guard view.markedTextRange == nil else { return }
            parent.text = view.text
        }

        func textViewDidBeginEditing(_ view: UITextView) { parent.onEditingChanged(true) }
        func textViewDidEndEditing(_ view: UITextView) {
            parent.text = view.text
            parent.onEditingChanged(false)
        }
    }
}
