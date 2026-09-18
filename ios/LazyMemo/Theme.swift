import LazyMemoCore
import SwiftUI
import UIKit

/// 맥과 **같은 표**를 보는 종이·잉크 (docs/VISUAL_DESIGN.md · MOBILE_DESIGN §10).
///
/// 앞선 판은 맥의 숫자를 여기 한 번 더 적어 두었고, 위젯이 또 한 번 적어 두어
/// 세 벌이었다. 지금은 셋 다 `ThemeCatalog` 한 곳을 본다 — 테마를 고르면 세
/// 화면이 같이 바뀐다.
///
/// **종이는 콘텐츠 층의 재질이다.** 펜·탭바·툴바·시트는 조작이고 조작은 유리라
/// 여기 색을 칠하지 않는다. 커스텀 색은 라이트·다크·대비 높임 세 벌 —
/// "supply light and dark variants, and an increased contrast option".
/// 둘째 줄·시각·안내 같은 보조 글은 시스템 `.secondary` 로 — 대비를 시스템이 지킨다.
enum Paper {
    /// 종이 바탕. 기본 테마는 라이트가 미색, 다크가 따뜻한 숯색, 대비 높임이면
    /// 더 희고 더 검다.
    static let surfaceUIColor = themedUIColor { $0.surface }
    /// 목록의 종이 한 장. 바탕과 명도만 달리해 내용의 경계를 만든다.
    static let cardUIColor = themedUIColor { $0.card }
    /// 종이 위의 잉크.
    static let inkUIColor = themedUIColor { $0.ink }

    static var surface: Color { Theme.track(); return Color(uiColor: surfaceUIColor) }
    static var card: Color { Theme.track(); return Color(uiColor: cardUIColor) }
    static var ink: Color { Theme.track(); return Color(uiColor: inkUIColor) }
}

enum Theme {
    // MARK: 형태 — 테마가 건드리지 않는다

    static let chipRadius: CGFloat = 8
    static let controlRadius: CGFloat = 10

    // MARK: 색 — 강조는 아껴 쓴다 ("reserve it for… status indicators or primary actions")

    /// 주요 행동의 면(「남기기」)·오늘의 원. 글자에 쓰면 안 된다 (`accentInk`).
    static let accentUIColor = themedUIColor { $0.accent }
    static var accent: Color { track(); return Color(uiColor: accentUIColor) }
    static let onAccentUIColor = themedUIColor { $0.onAccent }
    static var onAccent: Color { track(); return Color(uiColor: onAccentUIColor) }

    /// 작은 글자와 아이콘 — 어두운 종이에서는 밝은 쪽으로.
    static let accentInkUIColor = themedUIColor { $0.accentInk }
    static var accentInk: Color { track(); return Color(uiColor: accentInkUIColor) }

    /// 앱이 대신 읽어 준 날짜의 글자색. 밝은 종이에서는 잉크 쪽으로 가라앉힌다
    /// (기본 테마는 5.2:1). 여덟 테마가 전부 바닥 위에 있는지는 `ThemeContrastTests` 가 잰다.
    static let highlightInkUIColor = themedUIColor { $0.highlightInk }
    static var highlightInk: Color { track(); return Color(uiColor: highlightInkUIColor) }
    static let highlightWashUIColor = themedUIColor { $0.highlightWash }
    static var highlightWash: Color { track(); return Color(uiColor: highlightWashUIColor) }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑. **테마 밖이다**(관행이다).
    /// 어두운 종이에서는 둘 다 밝은 쪽으로 올린다 — 안 그러면 주말만 안 읽힌다.
    static let sundayInkUIColor = paperAwareUIColor(
        onLight: UIColor(red: 0.76, green: 0.36, blue: 0.34, alpha: 1),
        onDark: UIColor(red: 0.94, green: 0.58, blue: 0.54, alpha: 1)
    )
    static let saturdayInkUIColor = paperAwareUIColor(
        onLight: UIColor(red: 0.36, green: 0.55, blue: 0.72, alpha: 1),
        onDark: UIColor(red: 0.52, green: 0.68, blue: 0.96, alpha: 1)
    )
    static var sundayInk: Color { track(); return Color(uiColor: sundayInkUIColor) }
    static var saturdayInk: Color { track(); return Color(uiColor: saturdayInkUIColor) }

    /// **본문이 색을 읽었다고 알린다** (맥의 `Theme.track` 과 같다).
    ///
    /// 색을 읽는 자리가 수백 곳이라 그 전부를 관찰 대상으로 바꿀 수는 없다.
    /// 색을 돌려주는 계산 속성이 여기를 스치고 가서, SwiftUI 가 본문을 부르는
    /// 동안이면 `ThemeModel.generation` 을 읽은 것이 된다.
    nonisolated static func track() {
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated { _ = ThemeModel.shared.generation }
    }

    /// 글자는 전부 텍스트 스타일이라 고정 pt 가 없다 (MOBILE_DESIGN §10) —
    /// 크기는 Dynamic Type 이 정한다. 그래서 폰에는 「글자 크기」 칸이 없고,
    /// 얹은 것 중 그 한 칸만 맥의 것이다.
    static var textScale: Double { ThemeRuntime.shared.resolved.textScale }
}

// MARK: - 테마를 읽는 색

/// 그릴 때 테마를 읽는 색 하나. 객체는 고정되고 값만 갈린다.
///
/// **`nonisolated` 가 규칙이다.** 이 타깃은 기본 격리가 MainActor 라 그냥 두면 이 함수와
/// 그 안의 닫힘이 메인에 매이는데, SwiftUI 는 `ShapeStyle` 을 메인 밖에서 풀어
/// (`ShapeStyleResolver.updateValue`) 공급자를 부른다 — 격리 검사에 걸려 앱이 죽는다
/// (2026-09-18 폰 스모크 6건, `_swift_task_checkIsolatedSwift`). 읽는 것은 잠금으로
/// 지킨 `ThemeRuntime` 뿐이라 메인이 필요 없다.
nonisolated func themedUIColor(_ pick: @escaping @Sendable (ThemeVariant) -> ThemeRGB) -> UIColor {
    UIColor { traits in
        pick(ThemeRuntime.shared.variant(
            dark: traits.userInterfaceStyle == .dark,
            highContrast: traits.accessibilityContrast == .high
        )).uiColor
    }
}

/// 테마가 정하지 않고 **종이의 밝기만 따르는** 색 — 달력의 주말. 같은 이유로 `nonisolated`.
nonisolated func paperAwareUIColor(onLight: UIColor, onDark: UIColor) -> UIColor {
    UIColor { traits in
        ThemeRuntime.shared.variant(
            dark: traits.userInterfaceStyle == .dark,
            highContrast: traits.accessibilityContrast == .high
        ).darkPaper ? onDark : onLight
    }
}

extension ThemeRGB {
    /// 공급자 안에서 불리므로 메인에 매이면 안 된다 (`themedUIColor`).
    nonisolated var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
    nonisolated var color: Color { Color(uiColor: uiColor) }
}

extension MemoColor {
    /// 종이에 스며든 색. 채도가 아니라 온기로 구분된다 (`ThemeCatalog`).
    var ink: Color {
        Theme.track()
        return ThemeRuntime.shared.resolved.ink(self).color
    }

    var label: String {
        switch self {
        case .yellow: String(localized: "노랑")
        case .green: String(localized: "초록")
        case .blue: String(localized: "파랑")
        case .purple: String(localized: "보라")
        case .pink: String(localized: "분홍")
        case .gray: String(localized: "무채")
        }
    }
}
