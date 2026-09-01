import AppKit
import LazyMemoCore
import SwiftUI

/// 종이의 색.
///
/// 처음엔 문구점 접착 메모지의 원색(카나리아 노랑 따위)을 그대로 옮겼다가
/// 되돌렸다. **그건 현실의 종이가 아니라 2011년의 스큐어모피즘이다** — 진한
/// 노랑 바탕에 파란 괘선은 리갈패드를 흉내 낸 옛 메모 앱의 인상이고, 지금
/// 보면 촌스럽다.
///
/// 지금 기준은 **좋은 노트**다 (무지·로이텀·필드노트). 종이는 거의 미색에
/// 가깝고, 색은 그 위에 아주 옅게 스며 있을 뿐이다. 색이 신원을 말하되
/// 종이가 색에 잡아먹히지 않는다.
extension MemoColor {
    /// 종이에 스며든 색. 채도가 아니라 **온기**로 구분된다.
    var ink: Color {
        switch self {
        case .yellow: Color(red: 0.82, green: 0.66, blue: 0.28)
        case .green: Color(red: 0.42, green: 0.62, blue: 0.42)
        case .blue: Color(red: 0.36, green: 0.55, blue: 0.72)
        // 보라는 파랑 쪽에서 한 걸음 물러나 있다. 색상환에서 47° 밖에 안
        // 떨어져 있던 때에는 두 종이가 나란히 놓였을 때 같은 장으로 보였다
        // (`PaperPaletteTests` 의 가장 닮은 두 장이 늘 이 둘이었다) — 종이에
        // 스미면 채도가 절반 아래로 눌리므로 잉크에서 벌려 두어야 한다.
        case .purple: Color(red: 0.58, green: 0.44, blue: 0.72)
        case .pink: Color(red: 0.78, green: 0.48, blue: 0.56)
        case .gray: Color(red: 0.52, green: 0.51, blue: 0.48)
        }
    }

    /// 점·막대처럼 작게 찍을 때.
    var tint: Color { ink }

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

enum Paper {
    /// 종이 바탕. 라이트는 미색, 다크는 따뜻한 숯색.
    ///
    /// 다크 모드에서 밝은 종이를 그대로 두면 어두운 화면에 흰 판이 박혀
    /// 눈이 아프다. 검은 문구류가 실제로 있고 그쪽이 훨씬 낫다.
    static let surfaceNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.137, green: 0.129, blue: 0.118, alpha: 1)
            : NSColor(srgbRed: 0.980, green: 0.969, blue: 0.949, alpha: 1)
    }

    /// 종이 위의 잉크.
    static let inkNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.902, green: 0.886, blue: 0.855, alpha: 1)
            : NSColor(srgbRed: 0.161, green: 0.149, blue: 0.129, alpha: 1)
    }

    static var surface: Color { Color(nsColor: surfaceNSColor) }
    static var ink: Color { Color(nsColor: inkNSColor) }
    static var fadedInk: Color { Color(nsColor: inkNSColor).opacity(0.52) }

    /// 본문 안의 링크.
    ///
    /// **한 값으로 두었더니 숯색 종이 위에서 3.5:1 이었다** — 본문 크기의 글에
    /// 필요한 4.5:1 에 못 미친다. 잉크·호박색·네이비에서 한 번씩 겪은 것과
    /// 같은 일이라 여기서도 외관마다 따로 잡는다 (§8.2).
    /// 재는 자리는 맨 종이가 아니라 **여섯 색 중 가장 불리한 종이**다 —
    /// 링크는 어느 색 종이에도 붙는다.
    static let linkNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.56, green: 0.75, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.20, green: 0.40, blue: 0.66, alpha: 1)
    }
    static var linkColor: Color { Color(nsColor: linkNSColor) }

    /// 글줄 간격. 좋은 종이는 글이 숨 쉴 자리를 준다.
    static let linePitch: CGFloat = 23
    static let bodySize: CGFloat = 14
    /// 도트 그리드 간격.
    static let dotPitch: CGFloat = 23
}

// MARK: - 잉크를 종이로

/// 잉크 한 색이 **종이 한 장**이 되는 길 (설계문서 §14.10).
///
/// 잉크를 그대로 섞으면 색마다 종이 밝기가 달라진다 — 파랑·보라는 어두워져
/// 회색으로 죽고 노랑만 색으로 읽힌다. 여섯 색을 나란히 렌더해 보니 실제로
/// 그랬다: 빛 모드에서 전부 같은 흰 종이였다. 색이 신원을 말하려면 **밝기를
/// 먼저 맞추고** 섞어야 한다.
///
/// **비율을 빛과 어둠에서 따로 잡는다.** 한 벌로 두었더니 이번에는 다크에서
/// 같은 일이 일어났다 — 어두운 바탕에 25% 만 스민 색은 여섯 장이 전부 같은
/// 숯색이었다(무채와 노랑의 거리가 빛 모드의 절반 이하였다). 어두운 종이는
/// 색을 더 먹어야 색으로 보인다.
///
/// 뷰 밖의 순수 값인 이유는 `MonthGridGeometry` 와 같다 — 여섯 장이 서로
/// 구별되는지는 나란히 놓고 재야 알 수 있고, 화면을 흘긋 봐서는 "좀 비슷한가"
/// 까지밖에 말할 수 없다 (`PaperPaletteTests`).
public enum PaperTint {
    /// 한 외관에서 종이를 짓는 비율.
    public struct Recipe: Sendable, Equatable {
        /// 종이에 스미는 색의 몫.
        public let bleed: Double
        /// 채도 상한. 원래 무채인 색은 무채로 남아야 하고(무채가 색을 띠면
        /// 그건 무채가 아니다), 진한 색은 여기서 멎어야 문구점 형광 메모지로
        /// 넘어가지 않는다.
        public let saturationCap: CGFloat
        /// 여섯 색을 같은 밝기로 눕히는 자리.
        public let brightness: CGFloat
    }

    /// 미색 종이. 색은 그 위에 아주 옅게 스민다.
    public static let light = Recipe(bleed: 0.19, saturationCap: 0.46, brightness: 0.95)
    /// 숯색 종이. **어두운 색이 스민다** — 밝은 색을 많이 섞는 것이 아니라.
    ///
    /// 앞선 판은 밝기 0.50 짜리 색을 36% 섞었다. 여섯 장을 재 보면 평균 밝기가
    /// 맨 종이보다 L\* 11 이나 높았고(12.8 → 24.1) 채도는 지금의 두 배였다.
    /// 나란히 놓으면 색은 잘 갈렸지만 **한 장씩 보면 종이가 아니라 색 판**이었다 —
    /// 올리브·자주·적갈색 사각형이 바탕화면에 박혔다. 미색 쪽에서 지키던 규칙
    /// (「종이는 거의 미색이고 색은 그 위에 스밀 뿐」)을 어둠에서만 어기고 있었다.
    ///
    /// 방향을 뒤집는다. **색을 어둡게 짙히고 조금 덜 섞는다.** 밝기를 0.28 로
    /// 내려 잉크를 깊게 만들고, 그만큼 상한을 0.68 로 올려 색을 잃지 않은 채
    /// 28% 만 눕힌다. 종이는 맨 종이에서 L\* 2.6 만 떠오르고 채도는 절반이 된다.
    ///
    /// 상한이 빛 모드보다 높은 것이 뒤집힌 것처럼 보이지만 아니다 — 상한은
    /// **섞기 전** 잉크의 채도이고, 그것을 28% 만 눕히므로 종이에 남는 색은
    /// 앞선 판보다 옅다. 그래도 여섯 장은 갈린다: 지각 거리로 재면 가장 닮은
    /// 두 장이 ΔE 6.0 으로 빛 모드의 6.1 과 같다 (`PaperPaletteTests`).
    public static let dark = Recipe(bleed: 0.28, saturationCap: 0.68, brightness: 0.28)

    public static func recipe(dark isDark: Bool) -> Recipe { isDark ? dark : light }

    /// 잉크를 종이 색으로 눕힌다.
    public static func papered(_ ink: Color, dark isDark: Bool) -> NSColor? {
        guard let rgb = NSColor(ink).usingColorSpace(.sRGB) else { return nil }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let recipe = recipe(dark: isDark)
        return NSColor(
            hue: hue,
            saturation: min(saturation * 1.5, recipe.saturationCap),
            brightness: recipe.brightness,
            alpha: 1
        ).usingColorSpace(.sRGB)
    }

    /// 그 외관에서 쓰는 맨 종이. 동적 색을 sRGB 로 바꾸는 순간 "지금 그리는
    /// 외관" 으로 굳으므로 반드시 해당 외관 **안에서** 해석해야 한다
    /// (화면 밖 렌더가 그렇다).
    public static func base(dark isDark: Bool) -> NSColor {
        var base = NSColor.white
        NSAppearance(named: isDark ? .darkAqua : .aqua)?
            .performAsCurrentDrawingAppearance {
                base = Paper.surfaceNSColor.usingColorSpace(.sRGB) ?? .white
            }
        return base
    }

    /// 종이 위에 **떠 있는 조각** — 겹쳐 뜨는 조작 캡슐의 면.
    ///
    /// 맨 종이(`Paper.surface`)로 칠했더니 다크에서 그것이 **색이 스민 종이보다
    /// 어두워졌다.** 빛은 위에서 오므로 떠 있는 것은 바탕보다 밝아야 하는데,
    /// 어두운 쪽에서만 그 방향이 뒤집혀 캡슐이 조각이 아니라 **파인 구멍**으로
    /// 보였다. 밝기의 방향은 외관을 따라 뒤집히면 안 된다.
    ///
    /// 종이의 색을 그대로 들고 올라간다 — 재질은 하나이므로(§14.5) 떠 있는
    /// 조각도 같은 종이의 한 조각이다.
    public static func raised(ink: Color, dark isDark: Bool) -> NSColor {
        let paper = surface(ink: ink, dark: isDark)
        // 어두운 종이에서는 조금만 올려도 뜬다. 밝은 종이에서는 흰 쪽으로
        // 크게 당겨야 미색 바탕에서 갈린다.
        return paper.blended(withFraction: isDark ? 0.16 : 0.55, of: .white) ?? paper
    }

    /// 완성된 종이 한 장. `presence` 는 나이가 남긴 몫이다 (철학 3).
    public static func surface(ink: Color, dark isDark: Bool, presence: Double = 1) -> NSColor {
        let base = base(dark: isDark)
        let bleed = recipe(dark: isDark).bleed * (0.4 + 0.6 * presence)
        guard let tint = papered(ink, dark: isDark),
              let mixed = base.blended(withFraction: bleed, of: tint)
        else { return base }
        return mixed
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
