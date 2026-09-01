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
    /// 두 종이가 얼마나 다른가 — **눈이 재는 거리**(CIE Lab, ΔE).
    ///
    /// 앞선 판은 sRGB 위의 거리로 쟀다. 그 잣대는 어두운 쪽을 과소평가한다:
    /// sRGB 값은 감마가 씌워진 저장용 숫자라, 같은 「한 걸음」이 밝은 자리에서는
    /// 눈에 거의 안 보이고 어두운 자리에서는 크게 보인다. 그래서 **어두운 종이가
    /// 색을 많이 먹어야만 통과하는 시험**이 되었고, 실제로 그 압력이 다크의
    /// 여섯 장을 종이가 아니라 색 판으로 만들었다 (`PaperTint.dark`).
    ///
    /// Lab 은 그 왜곡을 펴 놓은 자리다. 여기서 재면 「빛에서 되던 만큼은
    /// 어둠에서도」가 **밝기를 맞추라는 말이 아니라 눈에 같은 만큼 갈리라는 말**이
    /// 된다. 잣대를 바꾸는 것은 그 자체가 한 번의 결정이라 여기 적어 둔다.
    private func distance(_ left: NSColor, _ right: NSColor) -> Double {
        let a = lab(left), b = lab(right)
        let dl = a.0 - b.0, da = a.1 - b.1, db = a.2 - b.2
        return (dl * dl + da * da + db * db).squareRoot()
    }

    /// sRGB → CIE Lab (D65). 손으로 적는 이유는 `MonthGridGeometry` 와 같다 —
    /// 색 공간 변환을 시스템에 맡기면 어느 외관에서 해석됐는지가 값에 섞인다.
    private func lab(_ color: NSColor) -> (Double, Double, Double) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return (0, 0, 0) }
        // 감마를 벗긴다.
        let linear = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let x = linear[0] * 0.4124564 + linear[1] * 0.3575761 + linear[2] * 0.1804375
        let y = linear[0] * 0.2126729 + linear[1] * 0.7151522 + linear[2] * 0.0721750
        let z = linear[0] * 0.0193339 + linear[1] * 0.1191920 + linear[2] * 0.9503041
        // D65 백색점.
        func f(_ t: Double) -> Double {
            t > 216.0 / 24389.0 ? pow(t, 1.0 / 3.0) : (841.0 / 108.0) * t + 4.0 / 29.0
        }
        let fx = f(x / 0.95047), fy = f(y), fz = f(z / 1.08883)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
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

    /// 여기 못 미치면 나란히 놓아도 같은 종이로 보인다.
    ///
    /// ΔE 2.3 이 「겨우 다르다」고 느끼는 한 걸음(JND)이다. 두 걸음을 바닥으로
    /// 삼는다 — 종이는 나란히 붙어 있지 않고 바탕화면 여기저기 흩어져 있어서,
    /// 겨우 다른 정도로는 **기억해서 알아보는** 데 못 미친다.
    private let floor = 5.0

    @Test("빛 모드에서 여섯 색이 서로 다른 종이다")
    func lightPapersAreDistinct() {
        #expect(closestPair(dark: false) > floor)
    }

    @Test("다크 모드에서도 여섯 색이 서로 다른 종이다 — 같은 숯색으로 뭉치지 않는다")
    func darkPapersAreDistinct() {
        let dark = closestPair(dark: true)
        #expect(dark > floor)
        // 빛에서 갈리는 만큼은 어둠에서도 갈려야 한다. 이것이 **눈으로 재는**
        // 항목이라는 데 값이 걸려 있다 — sRGB 로 재던 시절에는 이 한 줄이
        // "어둠에서 색을 더 먹어라" 로 읽혀서, 통과하는 유일한 길이 종이를
        // 색 판으로 만드는 것이었다.
        #expect(dark >= closestPair(dark: false) * 0.9)
    }

    /// **어두운 종이는 바탕 곁에 머문다** — 색이 면을 차지하면 그건 종이가 아니다.
    ///
    /// 위의 두 항목만으로는 이쪽이 지켜지지 않는다. "여섯이 갈리는가" 는 색을
    /// 키우면 언제나 통과하므로, 갈리라는 압력만 있고 물러나라는 압력이 없으면
    /// 다음 사람이 값을 만질 때 다시 진한 쪽으로 흘러간다. 앞선 판이 그렇게
    /// 됐다 — 여섯 장이 맨 종이보다 L\* 11 이나 밝았다.
    @Test("숯색 종이는 맨 종이 곁에 머문다 — 색 판이 되지 않는다")
    func darkPapersStayNearTheBase() {
        let base = lab(PaperTint.base(dark: true)).0
        for color in MemoColor.allCases {
            let paper = lab(PaperTint.surface(ink: color.ink, dark: true)).0
            #expect(paper - base < 6)
            // 그렇다고 맨 종이와 같지는 않다. 색은 있어야 한다.
            #expect(paper > base)
        }
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

    /// **떠 있는 것은 바탕보다 밝다.** 빛은 위에서 온다 — 이 방향이 외관을
    /// 따라 뒤집히면 떠 있는 조각이 파인 구멍으로 보인다. 실제로 다크에서
    /// 그랬다: 조작 캡슐을 맨 종이로 칠했는데 그것이 색이 스민 종이보다
    /// 어두웠다.
    @Test("겹쳐 뜨는 조각은 어느 외관에서도 종이보다 밝다")
    func raisedIsAlwaysLighterThanItsPaper() {
        for dark in [false, true] {
            for color in MemoColor.allCases {
                let paper = luminance(PaperTint.surface(ink: color.ink, dark: dark))
                let chip = luminance(PaperTint.raised(ink: color.ink, dark: dark))
                #expect(chip > paper)
                // 갈리는 것이 목적이지 다른 재질이 되는 것이 아니다.
                #expect(chip - paper > 0.01)
            }
        }
    }

    @Test("떠 있는 조각 위에서도 조작이 읽힌다")
    func controlsReadOnTheRaisedChip() {
        for dark in [false, true] {
            let chip = luminance(PaperTint.raised(ink: MemoColor.yellow.ink, dark: dark))
            let ink = luminance(inkColor(dark: dark))
            #expect((max(ink, chip) + 0.05) / (min(ink, chip) + 0.05) > 4.5)
        }
    }

    /// 본문 크기의 글이므로 4.5:1 이다. 한 값으로 두었을 때 다크에서 3.5:1 이었다.
    @Test("링크는 여섯 색 어느 종이 위에서도 본문만큼 읽힌다")
    func linksAreReadableOnEveryPaper() {
        for dark in [false, true] {
            var link = NSColor.blue
            NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
                link = Paper.linkNSColor.usingColorSpace(.sRGB) ?? .blue
            }
            let ink = luminance(link)

            // 맨 종이만 재면 모자란다 — 링크는 어느 색 종이에도 붙는다.
            let papers = MemoColor.allCases.map { PaperTint.surface(ink: $0.ink, dark: dark) }
                + [PaperTint.base(dark: dark)]
            for paper in papers.map(luminance) {
                #expect((max(ink, paper) + 0.05) / (min(ink, paper) + 0.05) > 4.5)
            }
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
