import AppKit
import LazyMemoCore
import SwiftUI

/// 실제 종이의 색.
///
/// 화면용 색이 아니라 **문구점에서 파는 종이의 색**을 옮겼다. 카나리아
/// 노랑, 라임, 하늘, 라일락, 장미, 마닐라. 채도가 낮고 따뜻해서 위에 얹은
/// 검은 글씨가 잘 읽히고, 여러 장이 겹쳐도 화면이 시끄럽지 않다.
extension MemoColor {
    /// 종이 면 전체의 색. 실제 접착 메모지는 가장자리가 아니라 온 면이 색이다.
    var paper: Color {
        switch self {
        case .yellow: Color(red: 0.992, green: 0.941, blue: 0.616)
        case .green: Color(red: 0.847, green: 0.929, blue: 0.647)
        case .blue: Color(red: 0.729, green: 0.886, blue: 0.949)
        case .purple: Color(red: 0.867, green: 0.831, blue: 0.937)
        case .pink: Color(red: 0.976, green: 0.827, blue: 0.867)
        case .gray: Color(red: 0.910, green: 0.890, blue: 0.835)
        }
    }

    /// 점·막대처럼 작게 찍을 때. 종이색 그대로 쓰면 배경에 묻힌다.
    var tint: Color {
        switch self {
        case .yellow: Color(red: 0.93, green: 0.76, blue: 0.24)
        case .green: Color(red: 0.51, green: 0.75, blue: 0.35)
        case .blue: Color(red: 0.31, green: 0.66, blue: 0.85)
        case .purple: Color(red: 0.58, green: 0.49, blue: 0.82)
        case .pink: Color(red: 0.89, green: 0.48, blue: 0.62)
        case .gray: Color(red: 0.60, green: 0.57, blue: 0.50)
        }
    }

    var label: String {
        switch self {
        case .yellow: "노랑"
        case .green: "초록"
        case .blue: "파랑"
        case .purple: "보라"
        case .pink: "분홍"
        case .gray: "미색"
        }
    }
}

enum Paper {
    /// 종이 위의 잉크. 순수한 검정은 인쇄물처럼 딱딱하다.
    static let ink = Color(red: 0.196, green: 0.180, blue: 0.153)
    static let inkNSColor = NSColor(red: 0.196, green: 0.180, blue: 0.153, alpha: 1)

    /// 흐린 글씨 — 날짜, 태그.
    static let fadedInk = Color(red: 0.196, green: 0.180, blue: 0.153).opacity(0.55)

    /// 괘선. 종이에 인쇄된 줄이라 잉크보다 훨씬 옅다.
    static let rule = Color(red: 0.35, green: 0.42, blue: 0.52).opacity(0.22)
    /// 노트 왼쪽의 여백 선.
    static let margin = Color(red: 0.85, green: 0.36, blue: 0.38).opacity(0.35)

    /// 종이 위의 링크. 파랑이되 화면용 파랑보다 잉크에 가깝다.
    static let linkColor = Color(red: 0.16, green: 0.35, blue: 0.62)

    /// 오래된 종이가 향하는 색. 시간이 지나면 누레진다.
    static let aged = Color(red: 0.847, green: 0.796, blue: 0.686)

    /// 글줄 간격. 괘선 간격과 같아야 글이 줄 위에 앉는다.
    static let linePitch: CGFloat = 21
    static let bodySize: CGFloat = 14
}
