import LazyMemoCore
import SwiftUI
import UIKit

/// 종이 위의 글 칸 — `UITextView` 를 감싼다.
///
/// SwiftUI 의 `TextEditor` 로는 두 가지를 못 한다: 한글 조합 중인지
/// (`markedTextRange`) 아는 것, 그리고 바깥에서 온 글을 반영할 때 커서를
/// 제자리에 두는 것. 맥의 `MemoTextSync` 세 규칙을 그대로 지키려면 이게 필요하다.
///
/// 마크다운은 꾸미지 않는다 — 다만 **기계가 적은 것은 감춘다** (`MachineLines`): 사진 참조와
/// 「## 가는 길」 절은 머리의 카드가 대신 서므로 글 칸에서는 자리만 차지했고, 링크의 `[`·`](주소)` 는
/// 이름만 남는다 (2026-09-17 사용자). 글자는 그대로다(D4) — 글꼴을 보이지 않을 만큼 줄일 뿐이라
/// 파일과 커서 위치가 어긋나지 않는다. 감춘 곳에 커서가 들어가면 밖으로 내보낸다 — 안 보이는 데 친
/// 글자는 잃은 글자다. 링크는 강조색으로만 — 적는 칸이라 눌러서 열지는 않는다.
/// ⌫ 가 감춘 사진 참조에 닿으면 참조를 한 덩이로 뗀다 — `)` 하나만 떼면 참조가 깨져 경로가 드러난다 (맥과 같다).
///
/// 목록 줄은 맥과 같은 규칙으로 산다 (`ListEditing`): `- [ ] 우유` 에서 ⏎ 를 치면 다음 줄에 `- [ ] ` 가 서고,
/// 빈 머리에서 치면 목록에서 나온다. 체크상자 `[ ]` 는 **키보드가 내려가 있을 때** 누르면 뒤집힌다 — 적는 중의
/// 누르기는 커서를 놓는 손이다(맥의 「편집 중이 아닐 때만 링크를 연다」와 같은 갈래).
struct PaperTextView: UIViewRepresentable {
    @Binding var text: String
    /// 키보드가 올라와 있는지. 글 칸이 올리고 내리며, 바깥이 `false` 로 놓으면
    /// 키보드를 내린다 — 편집의 「완료」가 이 길로 내린다.
    @Binding var editing: Bool
    /// 열 때 키보드를 올릴지. 열어서 읽는 일이 적는 일만큼 많아 기본은 아니다.
    var focusesOnAppear = false

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
        context.coordinator.restyle(view)
        // 글자 크기 설정이 바뀌면 바탕 글꼴부터 다시 깐다.
        view.registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: UITextView, _) in
            (view.delegate as? Coordinator)?.restyle(view)
        }
        if focusesOnAppear {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        // 모델 → 뷰. 조합 중이면 되밀지 않고, 같으면 대입하지 않고, 커서는 되돌린다.
        // 바깥이 키보드를 내리라고 했다. 올리는 쪽은 사람의 손(탭)만 — 열 때 튀어
        // 오르지 않는다는 규칙을 지킨다.
        if !editing, view.isFirstResponder {
            DispatchQueue.main.async { view.resignFirstResponder() }
        }
        guard view.markedTextRange == nil, view.text != text else { return }
        let caret = view.selectedRange.location
        view.text = text
        context.coordinator.restyle(view)
        view.selectedRange = NSRange(location: min(caret, (text as NSString).length), length: 0)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PaperTextView
        /// 지금 감춰 둔 구간 — 커서 규칙이 본다.
        private var hidden: [MachineLines.Hidden] = []
        private var isMovingCaret = false

        init(_ parent: PaperTextView) { self.parent = parent }

        /// 눈에 보이지 않을 만큼 작은 글꼴 — 맥의 `MarkdownStyler` 와 같은 수.
        private static let hiddenSize: CGFloat = 0.01
        /// 체크상자 머리(`- [ ] `)에 붙이는 텍스트 아이템 꼬리표 — 누를 수 있는 글 조각이 된다.
        private static let checkboxTag = "lazymemo.checkbox"

        private var baseAttributes: [NSAttributedString.Key: Any] {
            [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor(Paper.ink)]
        }

        /// 바탕부터 다시 깔고 기계의 구간을 감춘다. **조합 중에는 하지 않는다** — 속성을 통째로 다시 까는 동안
        /// 조합 밑줄이 지워져 한글 입력이 어디까지 됐는지 알 수 없게 된다 (맥과 같은 규칙).
        func restyle(_ view: UITextView) {
            guard view.markedTextRange == nil else { return }
            let text = view.text ?? ""
            hidden = MachineLines.hidden(in: text)
            let storage = view.textStorage
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: full)
            for span in MarkdownScanner.spans(in: text) where span.range.location + span.range.length <= storage.length {
                switch span.kind {
                case .link:
                    storage.addAttribute(.foregroundColor, value: UIColor(Theme.accentInk), range: span.range)
                case .checkbox:
                    // 머리를 누를 수 있는 조각으로 — 누르면 `primaryActionFor` 가 뒤집는다.
                    storage.addAttribute(.textItemTag, value: Self.checkboxTag, range: span.range)
                default:
                    continue
                }
            }
            for item in hidden where item.range.location + item.range.length <= storage.length {
                storage.addAttributes([.font: UIFont.systemFont(ofSize: Self.hiddenSize), .foregroundColor: UIColor.clear], range: item.range)
            }
            storage.endEditing()
            view.typingAttributes = baseAttributes
        }

        func textViewDidChange(_ view: UITextView) {
            // 조합 중의 중간 글자는 모델에 올리지 않는다 — 올리면 저장이 자모를 쪼갠다.
            guard view.markedTextRange == nil else { return }
            restyle(view)
            parent.text = view.text
        }

        /// 커서가 감춘 구간에 들어가면 밖으로. 치는 글자는 늘 바탕 글꼴 — 감춘 글자 뒤에서 치면 그 글꼴을
        /// 물려받아 친 글자까지 사라진다.
        func textViewDidChangeSelection(_ view: UITextView) {
            guard !isMovingCaret, view.markedTextRange == nil else { return }
            view.typingAttributes = baseAttributes
            let selection = view.selectedRange
            guard selection.length == 0, !hidden.isEmpty else { return }
            let moved = MachineLines.caret(selection.location, avoiding: hidden, in: view.text ?? "")
            guard moved != selection.location else { return }
            isMovingCaret = true
            view.selectedRange = NSRange(location: moved, length: 0)
            isMovingCaret = false
        }

        /// 지우기가 감춘 사진 참조에 걸치면 참조 전체로 (`MachineLines.deletion`). 넓힌 구간을 잡고 다시 지우게
        /// 하므로 되돌리기와 `textViewDidChange` 흐름이 그대로다 — 안쪽 호출은 이미 넓힌 구간이라 그냥 지난다.
        func textView(_ view: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard view.markedTextRange == nil else { return true }
            // ⏎ — 목록 줄이면 머리를 잇거나 뗀다. 선택을 그 자리에 두고 키보드가 친 것처럼 넣어 되돌리기와
            // `textViewDidChange` 흐름이 그대로다 (`ListEditing.onReturn`).
            if text == "\n", let edit = ListEditing.onReturn(in: view.text ?? "", selection: range) {
                view.selectedRange = edit.range
                if edit.replacement.isEmpty { view.deleteBackward() } else { view.insertText(edit.replacement) }
                return false
            }
            guard text.isEmpty else { return true }
            let widened = MachineLines.deletion(range, in: view.text ?? "")
            guard widened != range else { return true }
            view.selectedRange = widened
            view.deleteBackward()
            return false
        }

        /// 체크상자 머리를 눌렀다 — 키보드가 내려가 있을 때만 뒤집는다. 적는 중의 누르기는 커서를 놓는 손이다.
        func textView(_ view: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .tag(let tag) = textItem.content, tag == Self.checkboxTag else { return defaultAction }
            guard !view.isFirstResponder else { return nil }
            let location = textItem.range.location
            return UIAction { [weak view, weak self] _ in
                guard let view, let self, view.markedTextRange == nil,
                      let edit = ListEditing.toggleCheckbox(inLineContaining: location, in: view.text ?? "")
                else { return }
                // 괄호 안 한 글자만 — 파일도 커서도 어긋나지 않는다. 바꾼 뒤 모델에 올리는 길은 타자와 같다.
                view.textStorage.replaceCharacters(in: edit.range, with: edit.replacement)
                self.textViewDidChange(view)
            }
        }

        /// 길게 눌러도 체크상자에는 메뉴가 없다 — 할 수 있는 것은 뒤집기 하나다.
        func textView(_ view: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            if case .tag(let tag) = textItem.content, tag == Self.checkboxTag { return nil }
            return .init(menu: defaultMenu)
        }

        func textViewDidBeginEditing(_ view: UITextView) { parent.editing = true }
        func textViewDidEndEditing(_ view: UITextView) {
            parent.text = view.text
            parent.editing = false
        }
    }
}
