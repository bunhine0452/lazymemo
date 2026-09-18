import Foundation
import Testing
import LazyMemoCore

/// 위젯의 기본 종이가 **오늘 화면 그대로인가** (`ios/LazyMemoWidgets/WidgetPaper.swift`).
///
/// 위젯 얼굴은 Xcode 프로젝트 전용 타깃이라 SwiftPM 시험이 그 코드(`WidgetTheme`)를 직접
/// 들 수 없다 — 그래서 여기서는 `WidgetTheme.paper` 가 딛고 서는 자리, `ThemeChoice.load()`
/// 가 App Group 거울이 비었을 때 돌려주는 기본값을 잰다. 예전에는 이 숫자들이
/// `WidgetPaper.swift` 안에 리터럴로 한 번 더 적혀 있었다(`Shade` 의 값들) — 테마 카탈로그를
/// 읽어 오도록 바꾸면서 그 리터럴은 지웠고, 대신 **여기서 그 기본값이 그대로인지** 잡아
/// 둔다 (`ThemeCatalogTests.defaultThemeIsUnchanged` 와 같은 자리, 위젯이 실제로 쓰는
/// 칸만 추려서).
@Suite("위젯 기본 테마 — 앱 그룹이 비었을 때")
struct WidgetThemeDefaultsTests {
    /// `ThemeChoice.shared` (App Group) 를 건드리지 않는 격리된 defaults.
    private func freshDefaults() -> UserDefaults {
        let suite = "lazymemo.widget.theme.defaults.tests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("아무 것도 고르지 않았으면 크림과 포레스트다")
    func fallsBackToCreamForest() {
        let theme = ThemeChoice.load(defaults: freshDefaults())
        #expect(theme.id == .creamForest)
        #expect(theme.overrides.isEmpty)
    }

    /// `WidgetPaper.swift` 의 `paper` 가 `theme.variant(dark:highContrast:)` 로 뽑아 쓰는
    /// 네 칸 — 라이트·다크·대비 높임 둘 — 이 예전 리터럴과 정확히 같다.
    @Test("라이트·다크·대비 높임 네 벌이 예전 WidgetPaper 리터럴과 같다")
    func fourVariantsMatchOldLiterals() {
        let theme = ThemeChoice.load(defaults: freshDefaults())

        let light = theme.variant(dark: false)
        #expect(light.surface == ThemeRGB(0.980, 0.969, 0.949))
        #expect(light.card == ThemeRGB(1, 0.993, 0.978))
        #expect(light.ink == ThemeRGB(0.161, 0.149, 0.129))
        #expect(light.accent == ThemeRGB(0.16, 0.32, 0.27))
        #expect(light.onAccent == ThemeRGB(0.98, 0.98, 0.94))
        #expect(light.accentInk == ThemeRGB(0.16, 0.32, 0.27))
        #expect(light.highlightInk == ThemeRGB(0.56, 0.37, 0.05))

        let dark = theme.variant(dark: true)
        #expect(dark.surface == ThemeRGB(0.137, 0.129, 0.118))
        #expect(dark.card == ThemeRGB(0.185, 0.175, 0.16))
        #expect(dark.ink == ThemeRGB(0.902, 0.886, 0.855))
        #expect(dark.accent == ThemeRGB(0.16, 0.32, 0.27))
        #expect(dark.onAccent == ThemeRGB(0.98, 0.98, 0.94))
        #expect(dark.accentInk == ThemeRGB(0.65, 0.83, 0.73))
        #expect(dark.highlightInk == ThemeRGB(0.99, 0.76, 0.31))

        // 대비 높임 — 폰이 손으로 잡아 둔 값만 갈리고 accentInk·highlightInk 는
        // 평소 것을 그대로 물려받는다 (예전 `Shade` 의 lightHigh/darkHigh 기본값과 같다).
        let lightHigh = theme.variant(dark: false, highContrast: true)
        #expect(lightHigh.surface == ThemeRGB(0.995, 0.990, 0.980))
        #expect(lightHigh.card == ThemeRGB(1, 0.993, 0.978))
        #expect(lightHigh.ink == ThemeRGB(0.08, 0.07, 0.06))
        #expect(lightHigh.accentInk == ThemeRGB(0.16, 0.32, 0.27))
        #expect(lightHigh.highlightInk == ThemeRGB(0.56, 0.37, 0.05))

        let darkHigh = theme.variant(dark: true, highContrast: true)
        #expect(darkHigh.surface == ThemeRGB(0.06, 0.055, 0.05))
        #expect(darkHigh.card == ThemeRGB(0.14, 0.14, 0.14))
        #expect(darkHigh.ink == ThemeRGB(0.98, 0.97, 0.95))
        #expect(darkHigh.accentInk == ThemeRGB(0.65, 0.83, 0.73))
        #expect(darkHigh.highlightInk == ThemeRGB(0.99, 0.76, 0.31))
    }

    /// `NowFaces` 의 잉크 획(`theme.ink(for:)`)이 기대는 여섯 메모 색 — 예전
    /// `MemoColor.widgetInk` 리터럴과 같다.
    @Test("메모 잉크 여섯이 예전 widgetInk 리터럴과 같다")
    func memoInksMatchOldLiterals() {
        let theme = ThemeChoice.load(defaults: freshDefaults())
        #expect(theme.ink(.yellow) == ThemeRGB(0.82, 0.66, 0.28))
        #expect(theme.ink(.green) == ThemeRGB(0.42, 0.62, 0.42))
        #expect(theme.ink(.blue) == ThemeRGB(0.36, 0.55, 0.72))
        #expect(theme.ink(.purple) == ThemeRGB(0.58, 0.44, 0.72))
        #expect(theme.ink(.pink) == ThemeRGB(0.78, 0.48, 0.56))
        #expect(theme.ink(.gray) == ThemeRGB(0.52, 0.51, 0.48))
    }
}
