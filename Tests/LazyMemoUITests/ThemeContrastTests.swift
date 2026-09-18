import AppKit
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// **여덟 테마가 전부 종이로 보이는가** — `PaperPaletteTests` 가 한 벌에 한 일을
/// 여덟 벌에 한다.
///
/// 거기서 잰 것들(여섯 장이 갈리는가·글이 읽히는가·떠 있는 것이 밝은가)은 테마
/// 하나의 성질이 아니라 **이 앱이 종이라고 부르는 것의 성질**이다. 테마를 고르게
/// 한 뒤에도 그 성질이 남아 있어야 고르는 것이 「종이 고르기」이지 「망가뜨리기」가
/// 아니다.
///
/// 전역 테마를 갈아 끼우지 않는다 — 나란히 도는 다른 시험이 남의 테마에서 색을
/// 잰다. 그래서 `PaperTint` 가 한 벌을 인자로 받는 갈래를 함께 둔다.
@MainActor
@Suite("테마 — 여덟 벌의 종이")
struct ThemeContrastTests {
    private func rgb(_ color: NSColor) -> ThemeRGB {
        guard let srgb = color.usingColorSpace(.sRGB) else { return .black }
        return ThemeRGB(
            Double(srgb.redComponent), Double(srgb.greenComponent),
            Double(srgb.blueComponent), alpha: Double(srgb.alphaComponent)
        )
    }

    private func papers(_ spec: ThemeSpec, dark: Bool) -> [ThemeRGB] {
        let variant = spec.variant(dark: dark)
        return MemoColor.allCases.map {
            rgb(PaperTint.surface(ink: spec.ink($0).color, on: variant))
        }
    }

    /// 여기 못 미치면 나란히 놓아도 같은 종이로 보인다 (`PaperPaletteTests` 와 같은 바닥).
    private let floor = 5.0

    @Test("어느 테마에서도 여섯 색이 서로 다른 종이다")
    func sixPapersStayDistinct() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                let sheets = papers(spec, dark: dark)
                for (index, one) in sheets.enumerated() {
                    for other in sheets[(index + 1)...] {
                        #expect(one.distance(to: other) > floor, "\(spec.id.rawValue) dark=\(dark)")
                    }
                }
            }
        }
    }

    @Test("어느 테마에서도 종이가 색을 먹은 뒤 글이 읽힌다")
    func inkReadsOnEveryPaper() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                let variant = spec.variant(dark: dark)
                for paper in papers(spec, dark: dark) {
                    #expect(
                        variant.ink.contrast(against: paper) > ThemeContrast.text,
                        "\(spec.id.rawValue) dark=\(dark) 잉크"
                    )
                    // 링크는 어느 색 종이에도 붙는다 — 맨 종이만 재면 모자란다.
                    #expect(
                        variant.link.contrast(against: paper) > ThemeContrast.text,
                        "\(spec.id.rawValue) dark=\(dark) 링크"
                    )
                }
            }
        }
    }

    /// **떠 있는 것은 바탕보다 밝다.** 빛은 위에서 온다 — 이 방향이 테마를 따라
    /// 뒤집히면 조작 캡슐이 조각이 아니라 파인 구멍으로 보인다.
    @Test("어느 테마에서도 겹쳐 뜨는 조각이 종이보다 밝다")
    func raisedStaysLighter() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                let variant = spec.variant(dark: dark)
                for color in MemoColor.allCases {
                    let ink = spec.ink(color).color
                    let paper = rgb(PaperTint.surface(ink: ink, on: variant)).relativeLuminance
                    let chip = rgb(PaperTint.raised(ink: ink, on: variant)).relativeLuminance
                    #expect(chip > paper, "\(spec.id.rawValue) dark=\(dark) \(color.rawValue)")
                }
            }
        }
    }

    /// **색이 면을 차지하면 그건 종이가 아니다** (§14.5). 어두운 종이에서 한 번
    /// 어겼던 규칙이라 (여섯 장이 맨 종이보다 L\* 11 이나 밝았다) 여덟 벌 전부에
    /// 같은 압력을 건다.
    @Test("어느 테마에서도 색 든 종이가 맨 종이 곁에 머문다")
    func paperStaysNearItsBase() {
        for spec in ThemeCatalog.all {
            for dark in [false, true] {
                let variant = spec.variant(dark: dark)
                let base = variant.surface.lab.l
                for paper in papers(spec, dark: dark) {
                    #expect(abs(paper.lab.l - base) < 8, "\(spec.id.rawValue) dark=\(dark)")
                }
            }
        }
    }

    // MARK: 배관 — 화면의 색이 정말 테마에서 온다

    /// 기본 테마에서 **화면이 앞선 판과 같은 색을 그리는가.** 카탈로그의 숫자만
    /// 맞고 배관이 어긋나면 시험은 초록인데 화면은 딴 색이다.
    @Test("기본 테마의 화면 색이 앞선 판 그대로다")
    func defaultPlumbingIsUnchanged() {
        for (dark, expected) in [
            (false, ThemeRGB(0.161, 0.149, 0.129)), (true, ThemeRGB(0.902, 0.886, 0.855)),
        ] {
            NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
                let ink = rgb(Paper.inkNSColor)
                #expect(abs(ink.red - expected.red) < 0.001)
                #expect(abs(ink.green - expected.green) < 0.001)
                #expect(abs(ink.blue - expected.blue) < 0.001)

                let accent = rgb(Theme.accentNSColor)
                #expect(abs(accent.red - 0.16) < 0.001)
                #expect(abs(accent.green - 0.32) < 0.001)
                #expect(abs(accent.blue - 0.27) < 0.001)

                // 강조 글자만 외관을 따라 갈린다 (다크는 밝은 세이지).
                let accentInk = rgb(Theme.accentInkNSColor)
                #expect(abs(accentInk.green - (dark ? 0.83 : 0.32)) < 0.001)
            }
        }
    }

    /// 종이가 어두운가는 **외관이 아니라 테마가** 말한다.
    @Test("미드나잇은 빛 모드에서도 어두운 종이다")
    func midnightIsDarkInBothAppearances() {
        #expect(ThemeCatalog.midnight.light.darkPaper)
        #expect(ThemeCatalog.midnight.dark.darkPaper)
        #expect(ThemeCatalog.forestNight.light.darkPaper)
        #expect(!ThemeCatalog.creamForest.light.darkPaper)
        // 그 종이에는 어두운 비율이 쓰인다 — 아니면 여섯 장이 밝은 색 판이 된다.
        let paper = PaperTint.surface(ink: ThemeCatalog.midnight.ink(.yellow).color,
                                      on: ThemeCatalog.midnight.light)
        #expect(rgb(paper).relativeLuminance < 0.2)
    }

    /// 글자 한 칸은 **전부 같은 비율로** 자란다 — 한 층만 커지면 다른 디자인이다.
    @Test("글자 한 칸이 본문과 줄 간격을 함께 키운다")
    func textStepScalesEverything() {
        #expect(Theme.scaled(14) == 14)
        #expect(ThemeOverrides.scale(step: 2) * 14 > 17)
        #expect(ThemeOverrides.scale(step: -1) * 14 < 13)
        // 줄 간격과 점 격자가 글자와 같은 자를 쓴다.
        #expect(Paper.linePitch == Theme.scaled(23))
        #expect(Paper.dotPitch == Paper.linePitch)
        #expect(Paper.bodySize == Theme.scaled(14))
    }
}
