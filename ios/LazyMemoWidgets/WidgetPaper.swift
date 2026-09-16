import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 종이·잉크·포레스트 — 앱과 같은 값 (`ios/LazyMemo/Theme.swift`·`Sources/LazyMemoUI/Views/Theme.swift`,
/// docs/VISUAL_DESIGN.md). 위젯은 앱 모듈을 들 수 없어 같은 숫자를 여기 한 번 더 적는다 — 바꾸려면 셋을 같이.
///
/// 위젯의 바탕은 종이다. 홈 화면 위에서도 이 앱의 것은 크림색 한 장으로 보여야 한다.
/// 잠금 화면(accessory)은 시스템이 색을 걷어 내므로 거기서는 이 색을 쓰지 않는다.
enum Paper {
    /// 종이 바탕. 라이트는 미색, 다크는 따뜻한 숯색. 대비 높임이면 더 희고 더 검다.
    static let surface = Shade(
        light: (0.980, 0.969, 0.949), dark: (0.137, 0.129, 0.118),
        lightHigh: (0.995, 0.990, 0.980), darkHigh: (0.06, 0.055, 0.05)
    ).color

    /// 종이 위의 한 장 — 바탕과 명도만 달리해 경계를 만든다.
    static let card = Shade(
        light: (1, 0.993, 0.978), dark: (0.185, 0.175, 0.16),
        lightHigh: (1, 0.993, 0.978), darkHigh: (0.14, 0.14, 0.14)
    ).color

    /// 종이 위의 잉크.
    static let ink = Shade(
        light: (0.161, 0.149, 0.129), dark: (0.902, 0.886, 0.855),
        lightHigh: (0.08, 0.07, 0.06), darkHigh: (0.98, 0.97, 0.95)
    ).color
}

enum Theme {
    /// 주요 행동의 면 — 글자에 쓰면 안 된다 (`accentInk`).
    static let accent = Color(red: 0.16, green: 0.32, blue: 0.27)
    static let onAccent = Color(red: 0.98, green: 0.98, blue: 0.94)
    /// 아이콘의 둘째 획 — 세이지.
    static let sage = Color(red: 0.70, green: 0.84, blue: 0.60)

    /// 작은 글자와 아이콘 — 다크에서는 밝은 세이지.
    static let accentInk = Shade(light: (0.16, 0.32, 0.27), dark: (0.65, 0.83, 0.73)).color

    /// 앱이 대신 읽어 준 시각의 글자색 — 잉크 쪽으로 가라앉힌 호박색 (5.2:1).
    static let highlightInk = Shade(light: (0.56, 0.37, 0.05), dark: (0.99, 0.76, 0.31)).color

    static let cardRadius: CGFloat = 14
}

/// 라이트·다크·대비 높임의 네 벌을 한 `Color` 로. 플랫폼마다 외관을 묻는 길이 달라 여기서 가른다.
struct Shade {
    typealias RGB = (red: Double, green: Double, blue: Double)
    let light: RGB
    let dark: RGB
    let lightHigh: RGB
    let darkHigh: RGB

    init(light: RGB, dark: RGB, lightHigh: RGB? = nil, darkHigh: RGB? = nil) {
        self.light = light
        self.dark = dark
        self.lightHigh = lightHigh ?? light
        self.darkHigh = darkHigh ?? dark
    }

    private func pick(dark: Bool, high: Bool) -> RGB {
        switch (dark, high) {
        case (false, false): return light
        case (false, true): return lightHigh
        case (true, false): return self.dark
        case (true, true): return darkHigh
        }
    }

    var color: Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let rgb = pick(dark: traits.userInterfaceStyle == .dark, high: traits.accessibilityContrast == .high)
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            ])
            let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let high = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            let rgb = pick(dark: dark, high: high)
            return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
        #endif
    }
}

/// 앱 아이콘의 두 글줄 — 「적기」 위젯의 얼굴. 맥의 `MemoBrandMark` 와 같은 획.
struct BrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        Canvas { context, box in
            var first = Path()
            first.move(to: CGPoint(x: box.width * 0.23, y: box.height * 0.36))
            first.addLine(to: CGPoint(x: box.width * 0.77, y: box.height * 0.36))
            context.stroke(first, with: .color(Theme.onAccent), style: StrokeStyle(lineWidth: size * 0.096, lineCap: .round))
            var second = Path()
            second.move(to: CGPoint(x: box.width * 0.23, y: box.height * 0.58))
            second.addCurve(
                to: CGPoint(x: box.width * 0.73, y: box.height * 0.73),
                control1: CGPoint(x: box.width * 0.62, y: box.height * 0.58),
                control2: CGPoint(x: box.width * 0.66, y: box.height * 0.70)
            )
            context.stroke(second, with: .color(Theme.sage), style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
        }
        .frame(width: size, height: size)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .accessibilityHidden(true)
    }
}
