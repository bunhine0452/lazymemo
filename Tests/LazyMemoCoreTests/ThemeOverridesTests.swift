import Foundation
import Testing
@testable import LazyMemoCore

/// 사람이 얹은 색이 **글을 가리지 않는가** (`ThemeOverrides`).
///
/// 고를 자유와 망가뜨릴 자유는 다르다. 고른 색은 지키되, 그 색으로 글을 못 읽게
/// 되는 자리에서는 앱이 되끌어 올린다 — 그 되끌기가 실제로 도는지 잰다.
@Suite("테마 커스터마이징")
struct ThemeOverridesTests {
    @Test("아무것도 안 얹으면 고른 테마 그대로다")
    func emptyChangesNothing() {
        for spec in ThemeCatalog.all {
            #expect(spec.applying(.none).light == spec.light)
            #expect(spec.applying(.none).dark == spec.dark)
        }
        #expect(ThemeOverrides.none.isEmpty)
        #expect(ResolvedTheme(id: .creamForest).spec.light == ThemeCatalog.creamForest.light)
    }

    /// 미색 종이 위에 밝은 노랑을 강조색으로 골랐다 — 면은 그 노랑이지만
    /// **글자는 저절로 가라앉는다.**
    @Test("고른 강조색에서 글자 색이 유도된다")
    func accentDerivesItsInk() {
        let bright = ThemeRGB(0.99, 0.85, 0.20)
        let spec = ThemeCatalog.creamForest.applying(ThemeOverrides(accent: bright))
        for dark in [false, true] {
            let variant = spec.variant(dark: dark)
            // 면은 고른 그대로.
            #expect(variant.accent == bright)
            // 그 위의 글자는 읽힌다.
            #expect(variant.onAccent.contrast(against: variant.accent) >= ThemeContrast.text)
            // 종이 위의 글자로 쓸 때는 읽힌다 — 노랑 그대로면 미색 종이에서 1.2:1 이다.
            #expect(variant.accentInk.contrast(against: variant.surface) >= ThemeContrast.text)
        }
        // 밝은 종이에서는 실제로 가라앉았다. 어두운 종이에서는 그 노랑이 이미
        // 또렷하므로 그대로 쓴다 — 방향이 종이를 따른다.
        #expect(spec.light.accentInk != bright)
        #expect(spec.light.accentInk.relativeLuminance < bright.relativeLuminance)
        #expect(spec.dark.accentInk == bright)
    }

    /// 어두운 강조색에서는 그 위의 글자가 **밝은 쪽으로** 간다 — 방향이 따라 뒤집힌다.
    @Test("어두운 강조색 위의 글자는 밝아진다")
    func onAccentFollowsTheFace() {
        let deep = ThemeRGB(0.08, 0.10, 0.12)
        let variant = ThemeCatalog.creamForest.applying(ThemeOverrides(accent: deep)).light
        #expect(variant.onAccent.relativeLuminance > 0.5)
        #expect(variant.onAccent.contrast(against: deep) >= ThemeContrast.text)
    }

    /// **종이 색을 잉크와 같게 골라도 글이 남는다.** 16% 로 시작해 바닥을 못
    /// 지키면 물러난다 — 고른 색보다 읽히는 것이 먼저다.
    @Test("종이에 스미는 색이 잉크를 삼키지 않는다")
    func paperTintBacksOffForTheInk() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                let ink = spec.variant(dark: dark).ink
                let applied = spec.applying(ThemeOverrides(paperTint: ink)).variant(dark: dark)
                #expect(applied.ink.contrast(against: applied.surface) >= ThemeContrast.text, "\(spec.id.rawValue)")
            }
        }
    }

    @Test("고른 잉크도 종이 위에서 바닥을 지킨다")
    func chosenInkIsPulledUp() {
        // 미색 종이에 거의 흰 잉크 — 그대로 두면 1.1:1 이다.
        let pale = ThemeRGB(0.94, 0.93, 0.90)
        let light = ThemeCatalog.creamForest.applying(ThemeOverrides(ink: pale)).light
        #expect(light.ink.contrast(against: light.surface) >= ThemeContrast.text)
        #expect(light.secondaryInk.composited(over: light.surface)
            .contrast(against: light.surface) >= ThemeContrast.secondary)
    }

    /// 얹은 것이 있어도 **서른두 벌 전부**가 여전히 바닥 위여야 한다 —
    /// 대비 높임 판은 얹기 전에 만들어지므로 따로 재지 않으면 새어 나간다.
    @Test("얹은 뒤에도 네 벌이 전부 읽힌다")
    func overridesKeepEveryVariantLegible() {
        let rough = ThemeOverrides(
            accent: ThemeRGB(0.98, 0.92, 0.30),
            paperTint: ThemeRGB(0.10, 0.10, 0.12),
            ink: ThemeRGB(0.55, 0.55, 0.55)
        )
        for spec in ThemeCatalog.all {
            let applied = spec.applying(rough)
            for dark in [false, true] {
                for high in [false, true] {
                    let v = applied.variant(dark: dark, highContrast: high)
                    #expect(v.ink.contrast(against: v.surface) >= ThemeContrast.text, "\(spec.id.rawValue)")
                    #expect(v.accentInk.contrast(against: v.surface) >= ThemeContrast.text, "\(spec.id.rawValue)")
                    #expect(v.link.contrast(against: v.surface) >= ThemeContrast.text, "\(spec.id.rawValue)")
                    #expect(v.onAccent.contrast(against: v.accent) >= ThemeContrast.text, "\(spec.id.rawValue)")
                }
            }
        }
    }

    @Test("글자 한 칸은 -1 … +2 를 넘지 않는다")
    func textStepIsClamped() {
        #expect(ThemeOverrides(textStep: 9).textStep == 2)
        #expect(ThemeOverrides(textStep: -9).textStep == -1)
        #expect(ThemeOverrides(textStep: nil).textScale == 1.0)
        #expect(ThemeOverrides(textStep: 0).textScale == 1.0)
        #expect(ThemeOverrides(textStep: 2).textScale > 1.2)
        #expect(ThemeOverrides(textStep: -1).textScale < 1.0)
    }

    // MARK: 파일에 적히는 모양

    @Test("설정 파일에 적히고 그대로 돌아온다 — 색은 한 조각으로")
    func settingsRoundTrip() throws {
        var settings = Settings()
        settings.theme = ThemeID.sepia.rawValue
        settings.themeOverrides = ThemeOverrides(
            accent: ThemeRGB(0.16, 0.32, 0.27), textStep: 1, paperTexture: false
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(settings)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("#295245"))

        let back = try JSONDecoder().decode(Settings.self, from: data)
        #expect(back.theme == "sepia")
        #expect(back.themeOverrides?.textStep == 1)
        #expect(back.themeOverrides?.paperTexture == false)
        // 한 조각으로 적으면 색은 256 칸으로 끊긴다 — 눈에는 같은 색이고,
        // 손으로 고칠 수 있는 파일을 얻는 값이다.
        #expect(back.themeOverrides?.accent?.hex == "#295245")
        #expect(back.themeOverrides?.paperTint == nil)
        #expect(back.vaultPath == nil)
    }

    /// 앞선 판이 적어 둔 파일에는 이 두 칸이 없다. 없어도 열려야 한다.
    @Test("테마 칸이 없는 옛 설정 파일도 열린다")
    func oldSettingsStillOpen() throws {
        let old = Data(#"{"embedsLinks":true,"greeted":true}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: old)
        #expect(settings.theme == nil)
        #expect(settings.themeOverrides == nil)
        #expect(settings.embedsLinks == true)
        #expect(ResolvedTheme(id: ThemeID.parsed(settings.theme)).id == .creamForest)
    }
}
