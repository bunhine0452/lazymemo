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

    /// 계층에서 처음 만나는 그 종류의 뷰 — 검증이 스크롤 뷰를 찾을 때 (`SettingsWindow.snapshot`).
    func firstDescendant<T: NSView>(_ type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let found = subview.firstDescendant(type) { return found }
        }
        return nil
    }
}
