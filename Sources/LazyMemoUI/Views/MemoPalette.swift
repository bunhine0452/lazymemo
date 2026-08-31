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

    static let linkColor = Color(red: 0.28, green: 0.47, blue: 0.70)

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
    /// 숯색 종이. **더 진하게 스민다** — 어두운 바탕에서 옅은 색은 색이 아니라 얼룩이다.
    public static let dark = Recipe(bleed: 0.36, saturationCap: 0.49, brightness: 0.50)

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
