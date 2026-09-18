import Foundation
import Testing
@testable import LazyMemoCore

/// 여덟 벌의 종이가 **전부 읽히는가** (`ThemeCatalog`).
///
/// 테마를 고르게 하는 순간 색이 여덟 배로 늘어난다. 한 벌일 때는 눈으로 보고
/// 「호박색 글씨가 안 읽힌다」를 알아챌 수 있었지만(`Theme.highlightInk` 의 5.2:1),
/// 여덟 벌 × 네 외관 = 서른두 벌에서는 그게 안 된다. **재서 못 박는다.**
@Suite("테마 카탈로그")
struct ThemeCatalogTests {
    /// 재는 자리 — 종이 위에 놓이는 글 전부.
    private struct Pair {
        let what: String
        let ink: ThemeRGB
        let paper: ThemeRGB
        let floor: Double
    }

    private func pairs(_ v: ThemeVariant) -> [Pair] {
        [
            Pair(what: "본문 잉크", ink: v.ink, paper: v.surface, floor: ThemeContrast.text),
            Pair(what: "목록 종이 위의 잉크", ink: v.ink, paper: v.card, floor: ThemeContrast.text),
            Pair(what: "강조 글자", ink: v.accentInk, paper: v.surface, floor: ThemeContrast.text),
            Pair(what: "링크", ink: v.link, paper: v.surface, floor: ThemeContrast.text),
            Pair(what: "강조 면 위의 글자", ink: v.onAccent, paper: v.accent, floor: ThemeContrast.text),
            Pair(what: "보조 글", ink: v.secondaryInk, paper: v.surface, floor: ThemeContrast.secondary),
            Pair(what: "날짜 글자", ink: v.highlightInk, paper: v.surface, floor: ThemeContrast.secondary),
            // 날짜 칩은 바탕이 깔린 위에 글이 앉는다 — 재는 자리는 그 위다.
            Pair(
                what: "날짜 칩의 글자", ink: v.highlightInk,
                paper: v.highlightWash.composited(over: v.surface), floor: ThemeContrast.secondary
            ),
        ]
    }

    @Test("여덟 테마 × 네 벌에서 종이 위의 글이 전부 바닥 위다")
    func everyThemeIsLegible() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                for high in [false, true] {
                    let variant = spec.variant(dark: dark, highContrast: high)
                    for pair in pairs(variant) {
                        let ratio = pair.ink.composited(over: pair.paper).contrast(against: pair.paper)
                        #expect(
                            ratio >= pair.floor,
                            "\(spec.id.rawValue) · dark=\(dark) high=\(high) · \(pair.what) \(ratio)"
                        )
                    }
                }
            }
        }
    }

    /// 대비 높임은 **더 또렷해야** 한다. 이름만 그렇고 값이 같으면 켠 사람은
    /// 아무 일도 안 일어난 화면을 본다.
    @Test("대비 높임은 평소보다 또렷하다")
    func highContrastIsStronger() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                let plain = spec.variant(dark: dark)
                let hard = spec.variant(dark: dark, highContrast: true)
                #expect(
                    hard.ink.contrast(against: hard.surface) >= plain.ink.contrast(against: plain.surface),
                    "\(spec.id.rawValue)"
                )
            }
        }
    }

    /// **여섯이 갈리는가.** 색이 신원을 말하지 못하면 종이 색은 장식이고,
    /// 장식이라면 없는 편이 낫다 (`PaperPaletteTests` 와 같은 자리 — 거기는
    /// 종이로 눕힌 뒤를 재고 여기는 잉크 자체를 잰다).
    @Test("어느 테마에서도 여섯 잉크가 서로 다르다")
    func sixInksStayDistinct() {
        for spec in ThemeCatalog.all {
            let inks = MemoColor.allCases.map { spec.ink($0) }
            for (index, one) in inks.enumerated() {
                for other in inks[(index + 1)...] {
                    #expect(one.distance(to: other) > 12, "\(spec.id.rawValue)")
                }
            }
        }
    }

    @Test("id 는 ASCII 로 고정되고 겹치지 않는다")
    func idsAreStable() {
        let ids = ThemeCatalog.all.map(\.id.rawValue)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.allSatisfy { $0.isASCII && ($0.isLowercase || $0 == "-") } })
        #expect(Set(ids) == Set(ThemeID.allCases.map(\.rawValue)))
    }

    @Test("모르는 id 는 기본으로 떨어진다 — 앞선 판의 파일을 열어도 앱은 뜬다")
    func unknownIDFallsBack() {
        #expect(ThemeID.parsed("몰라") == .creamForest)
        #expect(ThemeID.parsed(nil) == .creamForest)
        #expect(ThemeID.parsed("midnight") == .midnight)
        #expect(ThemeCatalog.spec(.sepia).id == .sepia)
    }

    // MARK: 기본 테마는 오늘 화면 그대로

    /// **한 번도 테마를 고르지 않은 사람에게는 아무것도 달라지지 않아야 한다.**
    /// 그래서 숫자를 여기 한 번 더 적어 두고 대조한다 — 카탈로그를 고치다 기본을
    /// 스치면 이 줄이 빨개진다.
    @Test("크림과 포레스트의 숫자가 앞선 판 그대로다")
    func defaultThemeIsUnchanged() {
        let light = ThemeCatalog.creamForest.light
        #expect(light.surface == ThemeRGB(0.980, 0.969, 0.949))
        #expect(light.card == ThemeRGB(1, 0.993, 0.978))
        #expect(light.ink == ThemeRGB(0.161, 0.149, 0.129))
        #expect(light.secondaryInk == ThemeRGB(0.161, 0.149, 0.129, alpha: 0.64))
        #expect(light.accent == ThemeRGB(0.16, 0.32, 0.27))
        #expect(light.onAccent == ThemeRGB(0.98, 0.98, 0.94))
        #expect(light.accentInk == ThemeRGB(0.16, 0.32, 0.27))
        #expect(light.highlight == ThemeRGB(0.99, 0.76, 0.31))
        #expect(light.highlightInk == ThemeRGB(0.56, 0.37, 0.05))
        #expect(light.highlightWash == ThemeRGB(0.97, 0.72, 0.24, alpha: 0.38))
        #expect(light.link == ThemeRGB(0.20, 0.40, 0.66))
        #expect(light.ruleOpacity == 0.07)
        #expect(light.darkPaper == false)

        let dark = ThemeCatalog.creamForest.dark
        #expect(dark.surface == ThemeRGB(0.137, 0.129, 0.118))
        #expect(dark.card == ThemeRGB(0.185, 0.175, 0.16))
        #expect(dark.ink == ThemeRGB(0.902, 0.886, 0.855))
        #expect(dark.accentInk == ThemeRGB(0.65, 0.83, 0.73))
        #expect(dark.highlightInk == ThemeRGB(0.99, 0.76, 0.31))
        #expect(dark.highlightWash == ThemeRGB(0.99, 0.76, 0.31, alpha: 0.18))
        #expect(dark.link == ThemeRGB(0.56, 0.75, 1.0))
        #expect(dark.ruleOpacity == 0.08)
        #expect(dark.darkPaper == true)

        // 폰이 손으로 잡아 둔 대비 높임 (MOBILE_DESIGN §10).
        #expect(ThemeCatalog.creamForest.variant(dark: false, highContrast: true).surface
            == ThemeRGB(0.995, 0.990, 0.980))
        #expect(ThemeCatalog.creamForest.variant(dark: true, highContrast: true).ink
            == ThemeRGB(0.98, 0.97, 0.95))

        #expect(ThemeCatalog.creamForest.ink(.yellow) == ThemeRGB(0.82, 0.66, 0.28))
        #expect(ThemeCatalog.creamForest.ink(.purple) == ThemeRGB(0.58, 0.44, 0.72))
        #expect(ThemeCatalog.creamForest.ink(.gray) == ThemeRGB(0.52, 0.51, 0.48))
    }

    // MARK: 색을 적는 법

    @Test("색은 #rrggbb 로 적히고 그대로 돌아온다")
    func hexRoundTrips() throws {
        for color in [ThemeRGB(0.16, 0.32, 0.27), ThemeRGB(0.99, 0.76, 0.31, alpha: 0.18)] {
            let back = try #require(ThemeRGB(hex: color.hex))
            #expect(abs(back.red - color.red) < 0.004)
            #expect(abs(back.alpha - color.alpha) < 0.004)
        }
        #expect(ThemeRGB(hex: "#295245") != nil)
        #expect(ThemeRGB(hex: "295245") != nil)
        #expect(ThemeRGB(hex: "노랑") == nil)
        #expect(ThemeRGB(hex: "#12345") == nil)
    }

    // MARK: 위젯이 보는 거울

    @Test("고른 테마는 App Group 의 거울에도 적힌다 — 위젯이 같은 종이를 본다")
    func choiceMirrors() throws {
        let defaults = try #require(UserDefaults(suiteName: "lazymemo.theme.catalog.tests"))
        defaults.removePersistentDomain(forName: "lazymemo.theme.catalog.tests")
        defer { defaults.removePersistentDomain(forName: "lazymemo.theme.catalog.tests") }

        #expect(ThemeChoice.load(defaults: defaults).id == .creamForest)

        ThemeChoice.save(id: .midnight, overrides: ThemeOverrides(textStep: 2), defaults: defaults)
        let loaded = ThemeChoice.load(defaults: defaults)
        #expect(loaded.id == .midnight)
        #expect(loaded.overrides.textStep == 2)
        #expect(loaded.spec.dark.surface == ThemeCatalog.midnight.dark.surface)

        ThemeChoice.clear(defaults: defaults)
        #expect(ThemeChoice.load(defaults: defaults).id == .creamForest)
    }
}
