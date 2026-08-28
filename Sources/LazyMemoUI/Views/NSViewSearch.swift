import AppKit

extension NSView {
    /// 호스팅 뷰 계층에서 첫 `NSTextView` 를 찾는다.
    ///
    /// SwiftUI 안에 있는 텍스트 뷰를 first responder 로 만들려면 필요하다 —
    /// 단축키 한 번에 커서가 서 있어야 한다는 §8 의 요구 때문이다.
    var firstTextView: NSTextView? {
        if let textView = self as? NSTextView { return textView }
        for subview in subviews {
            if let found = subview.firstTextView { return found }
        }
        return nil
    }
}
