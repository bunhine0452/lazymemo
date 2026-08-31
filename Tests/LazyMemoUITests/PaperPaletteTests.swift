import AppKit
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 여섯 색이 **여섯 장의 종이로 보이는가** (`{#dark-palette}`).
///
/// 빛 모드에서 한 번 겪은 일이다 — 잉크를 그대로 섞었더니 파랑·보라는 어두워져
/// 회색으로 죽고 노랑만 색으로 읽혀서, 여섯 장이 전부 같은 흰 종이였다.
/// 밝기를 먼저 맞추고 섞는 것으로 고쳤는데, **그 비율 한 벌을 두 외관이 함께
/// 쓰고 있었다.** 어두운 바탕에서는 같은 비율이 다시 같은 숯색을 냈다.
///
/// 눈으로는 "좀 비슷한가" 까지밖에 말할 수 없어서 여기서 잰다. 색이 신원을
/// 말하지 못하면 종이 색은 장식이고, 장식이라면 없는 편이 낫다.
@MainActor
@Suite("종이 팔레트 — 여섯 색이 갈리는가")
struct PaperPaletteTests {
    /// 두 종이가 얼마나 다른가. sRGB 위의 거리 — 완벽한 지각 척도는 아니지만,
    /// **같은 잣대를 두 외관에 대는 것**이 여기서 재려는 전부다.
    private func distance(_ left: NSColor, _ right: NSColor) -> Double {
        guard let a = left.usingColorSpace(.sRGB), let b = right.usingColorSpace(.sRGB) else {
            return 0
        }
        let dr = a.redComponent - b.redComponent
        let dg = a.greenComponent - b.greenComponent
        let db = a.blueComponent - b.blueComponent
        return Double((dr * dr + dg * dg + db * db).squareRoot())
    }

    /// 그 외관에서 가장 닮은 두 장의 거리. 여기가 곧 팔레트의 약한 고리다.
    private func closestPair(dark: Bool) -> Double {
        let papers = MemoColor.allCases.map { PaperTint.surface(ink: $0.ink, dark: dark) }
        var closest = Double.greatestFiniteMagnitude
        for (index, one) in papers.enumerated() {
            for other in papers[(index + 1)...] {
                closest = min(closest, distance(one, other))
            }
        }
        return closest
    }

    /// 여기 못 미치면 나란히 놓아도 같은 종이로 보인다. 빛 모드에서 통과하던
    /// 값을 바닥으로 삼는다 — "빛에서 되던 만큼은 어둠에서도" 가 이 항목의 말이다.
    private let floor = 0.045

    @Test("빛 모드에서 여섯 색이 서로 다른 종이다")
    func lightPapersAreDistinct() {
        #expect(closestPair(dark: false) > floor)
    }

    @Test("다크 모드에서도 여섯 색이 서로 다른 종이다 — 같은 숯색으로 뭉치지 않는다")
    func darkPapersAreDistinct() {
        let dark = closestPair(dark: true)
        #expect(dark > floor)
        // 빛에서 갈리는 만큼은 어둠에서도 갈려야 한다. 예전에는 어두운 쪽이
        // 빛 쪽의 3/4 에도 못 미쳤다(무채와 노랑이 0.036).
        #expect(dark >= closestPair(dark: false) * 0.9)
    }

    @Test("어두운 종이는 색을 더 먹는다 — 스밈과 채도 상한을 따로 잡는다")
    func darkRecipeIsItsOwn() {
        #expect(PaperTint.dark.bleed > PaperTint.light.bleed)
        #expect(PaperTint.dark.brightness < PaperTint.light.brightness)
        // 상한이 한 벌로 묶여 있으면 다음에 한쪽을 고칠 때 다른 쪽이 따라 망가진다.
        #expect(PaperTint.dark != PaperTint.light)
    }

    @Test("무채는 어느 외관에서도 무채로 남는다")
    func grayStaysGray() {
        for dark in [false, true] {
            let paper = PaperTint.surface(ink: MemoColor.gray.ink, dark: dark)
                .usingColorSpace(.sRGB)!
            var saturation: CGFloat = 0
            paper.getHue(nil, saturation: &saturation, brightness: nil, alpha: nil)
            // 색을 띠는 무채는 무채가 아니다.
            #expect(saturation < 0.16)
        }
    }

    @Test("종이가 색을 먹어도 글은 읽힌다")
    func inkStaysReadableOnEveryPaper() {
        for dark in [false, true] {
            let ink = luminance(inkColor(dark: dark))
            for color in MemoColor.allCases {
                let paper = luminance(PaperTint.surface(ink: color.ink, dark: dark))
                let contrast = (max(ink, paper) + 0.05) / (min(ink, paper) + 0.05)
                // 본문 글씨의 하한 (WCAG AA).
                #expect(contrast > 4.5)
            }
        }
    }

    /// 나이가 든 종이는 색이 옅어지되 사라지지는 않는다 (철학 3).
    @Test("바랜 종이도 여전히 그 색이다")
    func agedPaperKeepsItsIdentity() {
        for dark in [false, true] {
            let fresh = PaperTint.surface(ink: MemoColor.blue.ink, dark: dark, presence: 1)
            let faded = PaperTint.surface(ink: MemoColor.blue.ink, dark: dark, presence: 0.2)
            let blank = PaperTint.base(dark: dark)
            #expect(distance(fresh, blank) > distance(faded, blank))
            #expect(distance(faded, blank) > 0)
        }
    }

    private func inkColor(dark: Bool) -> NSColor {
        var ink = NSColor.black
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            ink = Paper.inkNSColor.usingColorSpace(.sRGB) ?? .black
        }
        return ink
    }

    private func luminance(_ color: NSColor) -> Double {
        guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.redComponent)
            + 0.7152 * channel(rgb.greenComponent)
            + 0.0722 * channel(rgb.blueComponent)
    }
}
