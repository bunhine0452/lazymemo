import LazyMemoCore
import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 위젯이 쓰는 색 한 벌 — **색이 들어오는 문은 여기 하나다.**
///
/// 값은 사람이 고른 테마(`ThemeChoice`/`ThemeCatalog`, `Sources/LazyMemoCore/Theme/`)에서
/// 온다 — 위젯은 앱 모듈을 못 들지만 `LazyMemoCore` 는 들 수 있어서, 숫자를 한 번 더
/// 적지 않고 그 카탈로그를 그대로 읽는다. 얼굴들은 전부 `@Environment(\.widgetTheme)` 로
/// 받아 쓰므로 `WidgetTheme.paper` **한 곳**만 갈아 끼우면 네 위젯이 함께 바뀐다.
///
/// 두 벌을 든다. `paper` 는 홈 화면·알림 센터의 종이, `mono` 는 시스템이 색을 걷어 가는
/// 자리(잠금 화면 vibrant, iOS 18+ 틴트·선명 렌더)의 계층색이다 — 거기서 커스텀 색을 쓰면
/// 시스템이 다시 칠해 대비가 무너진다.
struct WidgetTheme: Sendable {
    /// 종이 바탕 — `containerBackground` 가 까는 것.
    let surface: Color
    /// 종이 위의 한 장.
    let card: Color
    /// 본문 잉크.
    let ink: Color
    /// 둘째 줄·시각·안내 — 테마의 잉크를 묽게 쓴다 (`ThemeVariant.secondaryInk`).
    let secondary: Color
    /// 주요 행동의 **면** (글자에 쓰지 않는다).
    let accent: Color
    /// 그 면 위의 글자.
    let onAccent: Color
    /// 작은 강조 글자·아이콘.
    let accentInk: Color
    /// 앱이 대신 읽어 준 시각의 글자색.
    let highlightInk: Color
    /// 종이인가 — 도트 그리드와 메모 색을 쓸 수 있는 자리인가.
    let papery: Bool
    /// 메모 색 여섯의 잉크 (`ThemeSpec.ink`). `papery` 가 아닌 자리에서는 안 불린다.
    private let memoInks: [MemoColor: Color]

    /// 메모 색 하나가 종이에 스미는 잉크. 못 찾으면 본문 잉크로 물러난다.
    func ink(for color: MemoColor) -> Color { memoInks[color] ?? ink }

    /// 사람이 고른 테마를 App Group 거울(`ThemeChoice`)에서 읽어 짓는다.
    ///
    /// **테마가 들어오는 문.** 값이 아니라 계산 속성인 것이 핵심이다 — 위젯 얼굴은
    /// `.widgetPaper(.resolved(mode))` 로 그릴 때마다 이것을 새로 부르므로, 앱이 테마를
    /// 바꾸고 타임라인을 다시 그리게 하면(`WidgetRefresher`) 다음 그림에 바로 앉는다.
    /// 라이트·다크·대비 높임 네 벌은 `ThemeVariant` 가 이미 갖고 있고, 그중 어느 것을
    /// 쓸지는 **그릴 때** 외관이 정해진다 — 그래서 각 색은 `themedColor` 로 감싼 동적
    /// `Color` 다 (`UIColor { traits in … }` / `NSColor(name:) { appearance in … }`).
    ///
    /// 「미드나잇」처럼 빛 모드에서도 어두운 종이인 테마는 이걸로 저절로 된다 —
    /// `darkPaper` 는 외관이 아니라 종이 자신이 정하는 값이라(`ThemeVariant.darkPaper`),
    /// `variant(dark:highContrast:)` 가 매 외관에서 그 테마의 벌을 그대로 돌려주면
    /// 그만이다. 시스템 appearance 로 따로 뒤집을 일이 없다.
    static var paper: WidgetTheme {
        let theme = ThemeChoice.load()
        return WidgetTheme(
            surface: themedColor(theme) { $0.surface },
            card: themedColor(theme) { $0.card },
            ink: themedColor(theme) { $0.ink },
            secondary: themedColor(theme) { $0.secondaryInk },
            accent: themedColor(theme) { $0.accent },
            onAccent: themedColor(theme) { $0.onAccent },
            accentInk: themedColor(theme) { $0.accentInk },
            highlightInk: themedColor(theme) { $0.highlightInk },
            papery: true,
            memoInks: Dictionary(uniqueKeysWithValues: MemoColor.allCases.map { ($0, theme.spec.ink($0).color) })
        )
    }

    /// 시스템이 칠하는 자리 — 우리는 계층으로만 말한다. 테마를 타지 않는다.
    static let mono = WidgetTheme(
        surface: .clear, card: .clear,
        ink: .primary, secondary: .secondary,
        accent: .primary, onAccent: .black,
        accentInk: .primary, highlightInk: .primary,
        papery: false,
        memoInks: [:]
    )

    /// 렌더 모드가 색을 정한다. `.accented`(틴트·선명)와 `.vibrant`(잠금 화면)에서는 종이를 접는다.
    static func resolved(_ mode: WidgetRenderingMode) -> WidgetTheme {
        mode == .fullColor ? .paper : .mono
    }
}

/// 그릴 때 테마를 읽는 색 하나 — 앱의 `themedUIColor`/`themedColor`
/// (`ios/LazyMemo/Theme.swift` · `Sources/LazyMemoUI/Views/MemoPalette.swift`) 와 같은
/// 자리다. 객체는 하나로 고정되고 외관마다 값만 다시 잰다 — `traits`/`appearance` 닫힘은
/// 그리는 순간 아무 스레드에서나 불리므로, 미리 읽어 둔 `ResolvedTheme`(이미 네 벌을 지어
/// 둔 것)만 들여다본다.
private func themedColor(_ theme: ResolvedTheme, _ pick: @escaping @Sendable (ThemeVariant) -> ThemeRGB) -> Color {
    #if canImport(UIKit)
    return Color(uiColor: UIColor { traits in
        pick(theme.variant(
            dark: traits.userInterfaceStyle == .dark,
            highContrast: traits.accessibilityContrast == .high
        )).uiColor
    })
    #else
    return Color(nsColor: NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [
            .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
        ])
        let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
        let high = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
        return pick(theme.variant(dark: dark, highContrast: high)).nsColor
    })
    #endif
}

private extension ThemeRGB {
    #if canImport(UIKit)
    var uiColor: UIColor { UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)) }
    #else
    var nsColor: NSColor { NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)) }
    #endif

    /// 외관을 안 타는 고정 색 — 메모 잉크는 테마 안에서 외관별로 갈리지 않는다
    /// (`ThemeSpec` 의 주석 — 「여섯 잉크는 외관마다 갈리지 않는다」).
    var color: Color {
        #if canImport(UIKit)
        Color(uiColor: uiColor)
        #else
        Color(nsColor: nsColor)
        #endif
    }
}

private struct WidgetThemeKey: EnvironmentKey {
    static let defaultValue = WidgetTheme.paper
}

extension EnvironmentValues {
    var widgetTheme: WidgetTheme {
        get { self[WidgetThemeKey.self] }
        set { self[WidgetThemeKey.self] = newValue }
    }
}

/// 여백과 굵기 — 네 위젯이 같은 눈금을 쓴다.
///
/// 바깥 여백은 **적지 않는다.** 시스템이 위젯마다 표준 여백을 준다 ("use the standard margin
/// width for widgets — 16 points for most widgets"; 맥 데스크톱과 잠금 화면은 더 좁다) — 거기에
/// 우리 여백을 한 겹 더 얹으면 작은 위젯의 글자가 두 번 밀린다.
enum WidgetMetrics {
    /// 줄머리의 색 획. 굵은 도형 대신 이것 하나로 메모 색을 말한다.
    static let inkBar: CGFloat = 3
    /// 카드 줄 사이.
    static let rowGap: CGFloat = 8
    /// 머리글과 내용 사이.
    static let headGap: CGFloat = 6
    /// 「오늘부터」 줄의 고정 칸 — 날과 시각이 줄마다 같은 자리에 선다.
    static let dayColumn: CGFloat = 46
    static let timeColumn: CGFloat = 58
    static let cardRadius: CGFloat = 14
}

/// 위젯의 바탕 — 크림 한 장과 아주 옅은 도트 그리드.
///
/// 점은 **시스템 가족에만** 깐다. 잠금 화면·틴트 렌더는 시스템이 색을 걷어 가는 자리라
/// 점을 그려 봐야 흰 얼룩만 남는다 (`WidgetTheme.papery`).
struct PaperGround: View {
    let theme: WidgetTheme

    var body: some View {
        ZStack {
            theme.surface
            if theme.papery {
                DotGrid(color: theme.ink.opacity(0.055))
            }
        }
    }
}

/// 도트 그리드. `Canvas` 한 번으로 다 그린다 (맥의 `DotGrid` 와 같은 낱말).
struct DotGrid: View {
    var color: Color
    var pitch: CGFloat = 14
    var inset: CGFloat = 8

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let diameter: CGFloat = 1.4
            var y = inset
            while y < size.height - inset * 0.4 {
                var x = inset
                while x < size.width - inset * 0.4 {
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter
                        )),
                        with: .color(color)
                    )
                    x += pitch
                }
                y += pitch
            }
        }
        .allowsHitTesting(false)
    }
}

/// 앱 아이콘의 두 글줄 — 「적기」 위젯의 얼굴. 맥의 `MemoBrandMark` 와 같은 획.
struct BrandMark: View {
    var size: CGFloat = 44
    var theme: WidgetTheme = .paper

    var body: some View {
        Canvas { context, box in
            var first = Path()
            first.move(to: CGPoint(x: box.width * 0.23, y: box.height * 0.36))
            first.addLine(to: CGPoint(x: box.width * 0.77, y: box.height * 0.36))
            context.stroke(first, with: .color(theme.onAccent), style: StrokeStyle(lineWidth: size * 0.096, lineCap: .round))
            var second = Path()
            second.move(to: CGPoint(x: box.width * 0.23, y: box.height * 0.58))
            second.addCurve(
                to: CGPoint(x: box.width * 0.73, y: box.height * 0.73),
                control1: CGPoint(x: box.width * 0.62, y: box.height * 0.58),
                control2: CGPoint(x: box.width * 0.66, y: box.height * 0.70)
            )
            context.stroke(second, with: .color(Self.sage), style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
        }
        .frame(width: size, height: size)
        .background(theme.accent, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .accessibilityHidden(true)
    }

    /// 아이콘의 둘째 획 — 세이지. 브랜드라 테마를 타지 않는다.
    static let sage = Color(red: 0.70, green: 0.84, blue: 0.60)
}
