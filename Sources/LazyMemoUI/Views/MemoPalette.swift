import AppKit
import LazyMemoCore
import SwiftUI

/// 종이의 색.
///
/// 처음엔 문구점 접착 메모지의 원색(카나리아 노랑 따위)을 그대로 옮겼다가
/// 되돌렸다. **그건 현실의 종이가 아니라 2011년의 스큐어모피즘이다** — 진한
/// 노랑 바탕에 파란 괘선은 리갈패드를 흉내 낸 옛 메모 앱의 인상이고, 지금
/// 보면 촌스럽다.
///
/// 지금 기준은 **좋은 노트**다 (무지·로이텀·필드노트). 종이는 거의 미색에
/// 가깝고, 색은 그 위에 아주 옅게 스며 있을 뿐이다. 색이 신원을 말하되
/// 종이가 색에 잡아먹히지 않는다.
extension MemoColor {
    /// 종이에 스며든 색. 채도가 아니라 **온기**로 구분된다.
    var ink: Color {
        switch self {
        case .yellow: Color(red: 0.82, green: 0.66, blue: 0.28)
        case .green: Color(red: 0.42, green: 0.62, blue: 0.42)
        case .blue: Color(red: 0.36, green: 0.55, blue: 0.72)
        case .purple: Color(red: 0.53, green: 0.47, blue: 0.70)
        case .pink: Color(red: 0.78, green: 0.48, blue: 0.56)
        case .gray: Color(red: 0.52, green: 0.51, blue: 0.48)
        }
    }

    /// 점·막대처럼 작게 찍을 때.
    var tint: Color { ink }

    var label: String {
        switch self {
        case .yellow: "노랑"
        case .green: "초록"
        case .blue: "파랑"
        case .purple: "보라"
        case .pink: "분홍"
        case .gray: "무채"
        }
    }
}

enum Paper {
    /// 종이 바탕. 라이트는 미색, 다크는 따뜻한 숯색.
    ///
    /// 다크 모드에서 밝은 종이를 그대로 두면 어두운 화면에 흰 판이 박혀
    /// 눈이 아프다. 검은 문구류가 실제로 있고 그쪽이 훨씬 낫다.
    static let surfaceNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.137, green: 0.129, blue: 0.118, alpha: 1)
            : NSColor(srgbRed: 0.980, green: 0.969, blue: 0.949, alpha: 1)
    }

    /// 종이 위의 잉크.
    static let inkNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.902, green: 0.886, blue: 0.855, alpha: 1)
            : NSColor(srgbRed: 0.161, green: 0.149, blue: 0.129, alpha: 1)
    }

    static var surface: Color { Color(nsColor: surfaceNSColor) }
    static var ink: Color { Color(nsColor: inkNSColor) }
    static var fadedInk: Color { Color(nsColor: inkNSColor).opacity(0.52) }

    static let linkColor = Color(red: 0.28, green: 0.47, blue: 0.70)

    /// 글줄 간격. 좋은 종이는 글이 숨 쉴 자리를 준다.
    static let linePitch: CGFloat = 23
    static let bodySize: CGFloat = 14
    /// 도트 그리드 간격.
    static let dotPitch: CGFloat = 23
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
