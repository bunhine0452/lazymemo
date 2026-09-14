import LazyMemoCore
import SwiftUI
import UIKit

/// 맥과 같은 종이·잉크·포레스트 (docs/VISUAL_DESIGN.md · MOBILE_DESIGN §10).
///
/// **종이는 콘텐츠 층의 재질이다.** 펜·탭바·툴바·시트는 조작이고 조작은 유리라
/// 여기 색을 칠하지 않는다. 커스텀 색은 라이트·다크·대비 높임 세 벌 —
/// "supply light and dark variants, and an increased contrast option".
/// 둘째 줄·시각·안내 같은 보조 글은 시스템 `.secondary` 로 — 대비를 시스템이 지킨다.
enum Paper {
    /// 종이 바탕. 라이트는 미색, 다크는 따뜻한 숯색. 대비 높임이면 더 희고 더 검다.
    static let surface = Color(uiColor: UIColor { traits in
        let dark = traits.userInterfaceStyle == .dark
        let high = traits.accessibilityContrast == .high
        switch (dark, high) {
        case (false, false): return UIColor(red: 0.980, green: 0.969, blue: 0.949, alpha: 1)
        case (false, true): return UIColor(red: 0.995, green: 0.990, blue: 0.980, alpha: 1)
        case (true, false): return UIColor(red: 0.137, green: 0.129, blue: 0.118, alpha: 1)
        case (true, true): return UIColor(red: 0.06, green: 0.055, blue: 0.05, alpha: 1)
        }
    })

    /// 목록의 종이 한 장. 바탕과 명도만 달리해 내용의 경계를 만든다.
    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return traits.accessibilityContrast == .high
                ? UIColor(white: 0.14, alpha: 1)
                : UIColor(red: 0.185, green: 0.175, blue: 0.16, alpha: 1)
        }
        return UIColor(red: 1, green: 0.993, blue: 0.978, alpha: 1)
    })

    /// 종이 위의 잉크.
    static let ink = Color(uiColor: UIColor { traits in
        let dark = traits.userInterfaceStyle == .dark
        let high = traits.accessibilityContrast == .high
        switch (dark, high) {
        case (false, false): return UIColor(red: 0.161, green: 0.149, blue: 0.129, alpha: 1)
        case (false, true): return UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
        case (true, false): return UIColor(red: 0.902, green: 0.886, blue: 0.855, alpha: 1)
        case (true, true): return UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
        }
    })
}

enum Theme {
    // MARK: 형태

    static let chipRadius: CGFloat = 8
    static let controlRadius: CGFloat = 10

    // MARK: 색 — 강조는 아껴 쓴다 ("reserve it for… status indicators or primary actions")

    /// 주요 행동의 면(「남기기」)·오늘의 원. 글자에 쓰면 안 된다 (`accentInk`).
    static let accent = Color(red: 0.16, green: 0.32, blue: 0.27)
    static let onAccent = Color(red: 0.98, green: 0.98, blue: 0.94)

    /// 작은 글자와 아이콘 — 다크에서는 밝은 세이지.
    static let accentInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.83, blue: 0.73, alpha: 1)
            : UIColor(red: 0.16, green: 0.32, blue: 0.27, alpha: 1)
    })

    /// 앱이 대신 읽어 준 날짜의 글자색. 라이트에서는 잉크 쪽으로 가라앉힌 호박색 (5.2:1).
    static let highlightInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.99, green: 0.76, blue: 0.31, alpha: 1)
            : UIColor(red: 0.56, green: 0.37, blue: 0.05, alpha: 1)
    })
    static let highlightWash = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.99, green: 0.76, blue: 0.31, alpha: 0.18)
            : UIColor(red: 0.97, green: 0.72, blue: 0.24, alpha: 0.38)
    })

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    static let sundayInk = Color(red: 0.76, green: 0.36, blue: 0.34)
    static let saturdayInk = Color(red: 0.36, green: 0.55, blue: 0.72)
}

extension MemoColor {
    /// 종이에 스며든 색. 채도가 아니라 온기로 구분된다 (`MemoPalette`).
    var ink: Color {
        switch self {
        case .yellow: Color(red: 0.82, green: 0.66, blue: 0.28)
        case .green: Color(red: 0.42, green: 0.62, blue: 0.42)
        case .blue: Color(red: 0.36, green: 0.55, blue: 0.72)
        case .purple: Color(red: 0.58, green: 0.44, blue: 0.72)
        case .pink: Color(red: 0.78, green: 0.48, blue: 0.56)
        case .gray: Color(red: 0.52, green: 0.51, blue: 0.48)
        }
    }

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
