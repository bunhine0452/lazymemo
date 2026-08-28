import AppKit

/// 모델 → 텍스트 뷰 방향의 되밀기 규칙 (설계문서 §8).
///
/// 별도 타입으로 뽑은 이유는 **테스트하기 위해서**다. 한글 조합이 깨지는 버그는
/// 사람이 타자를 쳐 봐야만 드러나는 종류라 회귀가 쉬운데, 규칙을 순수 함수로
/// 떼어 두면 `NSTextView` 의 조합 상태를 흉내 내어 자동으로 지킬 수 있다.
public enum MemoTextSync {
    /// 텍스트 뷰에 문자열을 반영한다.
    ///
    /// - 조합 중(`hasMarkedText`)이면 **아무것도 하지 않는다.** 여기서 `string`
    ///   을 대입하면 입력 중인 한글의 자모가 흩어진다.
    /// - 내용이 같으면 건드리지 않는다. 대입만으로도 선택 범위가 초기화된다.
    /// - 반영할 때는 커서를 원래 자리에 되돌린다. 안 그러면 문서 끝으로 튄다.
    ///
    /// - Returns: 실제로 반영했으면 `true`.
    @discardableResult
    public static func apply(_ text: String, to textView: NSTextView) -> Bool {
        guard !textView.hasMarkedText() else { return false }
        guard textView.string != text else { return false }

        let caret = textView.selectedRange().location
        textView.string = text
        textView.setSelectedRange(NSRange(
            location: min(caret, (text as NSString).length),
            length: 0
        ))
        return true
    }
}
