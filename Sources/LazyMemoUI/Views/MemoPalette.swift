import AppKit
import LazyMemoCore
import SwiftUI

/// 메모 색의 시각 정의 (설계문서 §7 의 "아마추어처럼 보이지 않을 것").
///
/// 라이트·다크 양쪽에서 같은 인상을 주도록 채도를 낮추고 유리 위에 얹는다.
/// 종이 포스트잇의 원색을 그대로 쓰면 macOS 26 의 재질과 충돌한다.
extension MemoColor {
    var tint: Color {
        switch self {
        case .yellow: Color(red: 0.98, green: 0.80, blue: 0.31)
        case .green: Color(red: 0.53, green: 0.82, blue: 0.55)
        case .blue: Color(red: 0.44, green: 0.71, blue: 0.96)
        case .purple: Color(red: 0.72, green: 0.62, blue: 0.95)
        case .pink: Color(red: 0.97, green: 0.62, blue: 0.75)
        case .gray: Color(red: 0.66, green: 0.69, blue: 0.73)
        }
    }

    /// 메뉴 스와치처럼 AppKit 이 직접 그리는 자리용.
    var appKit: Color { tint }

    var label: String {
        switch self {
        case .yellow: "노랑"
        case .green: "초록"
        case .blue: "파랑"
        case .purple: "보라"
        case .pink: "분홍"
        case .gray: "회색"
        }
    }
}
