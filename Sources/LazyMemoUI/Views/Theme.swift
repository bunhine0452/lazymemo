import AppKit
import LazyMemoCore
import SwiftUI

/// # lazymemo 디자인 철학 — 「흐릿하게 남는다」
///
/// 이 앱은 사용자가 게으르다는 것을 결함이 아니라 **전제**로 삼는다.
/// 그 전제를 끝까지 밀면 화면은 이렇게 생겨야 한다.
///
/// ## 1. 완성을 요구하지 않는다
///
/// 쓰다 만 것, 제목 없는 것, 날짜 없는 것이 **정상 상태**다. 빈칸도, 채우라는
/// 표시도, "저장" 버튼도 두지 않는다. 앱 아이콘의 흘러내리는 둘째 줄이 이
/// 문장의 그림이다.
///
/// ## 2. 시간이 유일한 구조다
///
/// 게으른 사람은 폴더도 태그도 유지하지 않는다. 유일하게 받아들이는 구조는
/// "언제"뿐이다. 그래서 달력은 보는 물건이 아니라 **만지는 물건**이고 —
/// 집어서 다른 날에 놓고, 한 번 눌러 미룬다 — 빠른 입력은 시간을 가리키는
/// 말을 스스로 읽는다. 사용자가 형식을 배우게 하지 않는다.
///
/// ## 3. 오래된 것은 스스로 물러난다
///
/// 정리하지 않는 사람의 바탕화면은 결국 낡은 종이로 덮인다. 그러니 시간이
/// 지난 것이 조용히 바래야 한다 (`MemoAge`). 사용자가 아무것도 하지 않아도
/// 화면이 정돈된다. 포인터를 올리면 다시 또렷해진다 — 읽으려는 뜻이 곧
/// 되살리는 신호다.
///
/// ## 4. 앱은 자기를 드러내지 않는다
///
/// 기본 상태의 메모는 **글자와 종이뿐**이다. 머리글도, 아이콘 줄도, 색 점도
/// 없다. 조작 버튼은 포인터가 올 때 내용 위에 겹쳐 뜨고, 자리를 차지하지 않는다.
///
/// ## 재질은 하나 — 종이
///
/// 유리(`glassEffect`)를 쓰지 않는다. 메모에서, 달력에서, 빠른 입력에서
/// 차례로 시도했다가 모두 되돌렸다. **반투명한 면 위의 글은 씻겨 나간다.**
/// 바탕화면 사진이 무엇이든 글은 읽혀야 하는데, 유리는 그 통제권을 배경에
/// 넘긴다. 빠른 입력처럼 "지금 치고 있는 글자" 가 있는 곳에서는 더더욱 그렇다.
///
/// 떠 있다는 느낌은 투명도가 아니라 **그림자와 크기와 자리**가 만든다.
/// 재질이 하나면 화면 전체가 한 물건으로 읽히기도 한다.
enum Theme {
    // MARK: 형태

    /// **종이는 각져 있다.** 둥글릴수록 UI 카드로 보인다. 재단된 종이의
    /// 모서리가 아주 살짝 무뎌진 정도만 준다.
    static let cardRadius: CGFloat = 5
    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 7
    static let borderWidth: CGFloat = 1.5

    // MARK: 여백 — 다섯 단계

    static let hairline: CGFloat = 2
    static let tight: CGFloat = 6
    static let snug: CGFloat = 10
    static let normal: CGFloat = 14
    static let loose: CGFloat = 20

    // MARK: 글자 — 넷

    /// 메모 본문. 읽는 글.
    static let body = Font.system(size: 14)
    /// 빠른 입력. 한 줄 적고 마는 자리라 크다.
    static let capture = Font.system(size: 19, weight: .light)
    static let title = Font.system(size: 13, weight: .semibold)
    static let label = Font.system(size: 11)
    static let micro = Font.system(size: 10)
    static let microMono = Font.system(size: 10, design: .monospaced)

    static let bodyLineSpacing: CGFloat = 3

    // MARK: 색

    /// 앱 마크의 판 색. 아이콘과 UI 가 같은 파랑을 쓴다.
    static let accent = Color(red: 0.44, green: 0.41, blue: 0.72)
    /// 아이콘의 흘러내리는 획 색. 오늘·지금을 가리킬 때만 쓴다.
    /// **면을 칠하는 색이다** — 글자에 쓰면 안 된다 (아래 `highlightInk`).
    static let highlight = Color(red: 0.99, green: 0.76, blue: 0.31)

    /// 같은 호박색을 **글자로 쓸 때.**
    ///
    /// 밝은 호박색은 미색 종이 위에서 읽히지 않는다 — 대비 1.5:1 로, 날짜
    /// 칩의 글씨가 "있는 줄은 알겠는데 안 읽히는" 상태였다. 앱이 대신 읽어
    /// 준 날짜는 **확인하라고 보여주는 것**이라 안 읽히면 아무 일도 안 한
    /// 것과 같다.
    ///
    /// 그래서 빛 모드에서는 같은 색을 잉크 쪽으로 가라앉힌다(5.2:1). 어두운
    /// 모드에서는 원래 호박색이 이미 또렷하므로(9.9:1) 그대로 쓴다.
    static let highlightInkNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.99, green: 0.76, blue: 0.31, alpha: 1)
            : NSColor(srgbRed: 0.56, green: 0.37, blue: 0.05, alpha: 1)
    }
    static var highlightInk: Color { Color(nsColor: highlightInkNSColor) }

    /// 호박색 칩의 바탕. 글자가 가라앉은 만큼 바탕도 또렷해져야 칩이
    /// "붙은 딱지" 로 읽힌다. 세기를 외관마다 따로 잡는다.
    static let highlightWashNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.99, green: 0.76, blue: 0.31, alpha: 0.18)
            : NSColor(srgbRed: 0.97, green: 0.72, blue: 0.24, alpha: 0.38)
    }
    static var highlightWash: Color { Color(nsColor: highlightWashNSColor) }

    /// 지우기. 종이 위에서 튀지 않을 만큼 죽인 붉은색 — 경고등이 아니라
    /// "다른 종류의 버튼" 이라는 표시다.
    static let danger = Color(red: 0.76, green: 0.36, blue: 0.34)

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    static let sunday = Color(red: 0.85, green: 0.35, blue: 0.35)
    static let saturday = Color(red: 0.35, green: 0.50, blue: 0.82)

    // MARK: 움직임

    /// 되살아나고 물러나는 속도. 튀거나 튕기지 않는다.
    static let reveal = Animation.easeOut(duration: 0.18)
    static let settle = Animation.easeInOut(duration: 0.28)
}

// MARK: - 종이

/// 메모가 놓이는 면 — **좋은 노트의 한 장.**
///
/// 앞선 두 판을 버리고 여기 왔다. 매끈한 단색 카드는 화면 위의 사각형으로
/// 보였고, 진한 노랑 바탕에 파란 괘선은 옛 메모 앱의 인상이라 촌스러웠다.
///
/// 지금 기준은 셋이다.
///
/// 1. **종이는 거의 미색이다.** 색은 그 위에 스며 있을 뿐, 종이를 잡아먹지 않는다.
/// 2. **줄이 아니라 점이다.** 가로 괘선은 학습장·리갈패드를 부른다. 도트
///    그리드는 지금 문구류의 언어이고, 글을 줄에 맞출 의무도 지우지 않는다.
/// 3. **표면이 아주 조금 고르지 않다.** 알아채지 못할 만큼의 결이 종이를 물건으로 만든다.
struct PaperSurface: View {
    let tint: Color
    var age: MemoAge = .fresh
    var radius: CGFloat = Theme.cardRadius
    /// 도트 그리드를 깔지. 빠른 입력처럼 한 줄짜리 자리에서는 끈다.
    var dotted = true

    @Environment(\.colorScheme) private var colorScheme

    /// 종이에 스민 색의 세기. 나이가 들수록 옅어진다 (철학 3).
    private var bleed: Double {
        (colorScheme == .dark ? 0.26 : 0.19) * (0.4 + 0.6 * age.presence)
    }

    /// 잉크를 **종이 색**으로 바꾼다.
    ///
    /// 잉크를 그대로 섞으면 색마다 종이 밝기가 달라진다 — 파랑·보라는 어두워져
    /// 회색으로 죽고 노랑만 색으로 읽힌다. 여섯 색을 나란히 렌더해 보니 실제로
    /// 그랬다(`palette.png`): 빛 모드에서 전부 같은 흰 종이였다. 색이 신원을
    /// 말하려면 **밝기를 먼저 맞추고** 섞어야 한다.
    ///
    /// 채도는 곱해서 올리되 상한을 둔다. 원래 채도가 낮은 무채는 낮은 채로
    /// 남아야 하고 — 무채가 색을 띠면 그건 무채가 아니다 — 진한 색은 상한에서
    /// 멈춰야 문구점 형광 메모지로 넘어가지 않는다.
    private func papered(_ color: Color) -> NSColor? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return NSColor(
            hue: hue,
            saturation: min(saturation * 1.5, colorScheme == .dark ? 0.40 : 0.46),
            brightness: colorScheme == .dark ? 0.46 : 0.95,
            alpha: 1
        ).usingColorSpace(.sRGB)
    }

    private var surface: Color {
        // 동적 색을 sRGB 로 바꾸는 순간 "지금 그리는 외관" 으로 굳는다.
        // SwiftUI 환경의 colorScheme 과 그것이 다를 수 있으므로(화면 밖 렌더가
        // 그렇다) 반드시 해당 외관 **안에서** 해석해야 한다.
        var base = NSColor.white
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)?
            .performAsCurrentDrawingAppearance {
                base = Paper.surfaceNSColor.usingColorSpace(.sRGB) ?? .white
            }

        guard let paperTint = papered(tint),
              let mixed = base.blended(withFraction: bleed, of: paperTint)
        else { return Color(nsColor: base) }
        return Color(nsColor: mixed)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(surface)
            .overlay {
                if dotted {
                    DotGrid(color: tint.opacity(colorScheme == .dark ? 0.30 : 0.28))
                }
            }
            .overlay {
                PaperGrain()
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
    }
}

/// 도트 그리드. `Canvas` 한 번으로 다 그린다.
struct DotGrid: View {
    var color: Color
    var pitch: CGFloat = Paper.dotPitch
    var inset: CGFloat = Theme.loose

    var body: some View {
        Canvas { context, size in
            let diameter: CGFloat = 1.4
            var y = inset + pitch
            while y < size.height - inset * 0.4 {
                var x = inset
                while x < size.width - inset * 0.4 {
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - diameter / 2, y: y - diameter / 2,
                            width: diameter, height: diameter
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

/// 종이 결. 타일로 이어 붙인다.
struct PaperGrain: View {
    private static let image: Image? = {
        guard let grain = Bundle.module.image(forResource: "PaperGrain") else { return nil }
        return Image(nsImage: grain)
    }()

    var body: some View {
        if let image = Self.image {
            image
                .resizable(resizingMode: .tile)
                // 알아채지 못할 만큼만. 눈에 띄면 잡티가 아니라 잡음이 된다.
                .opacity(0.16)
                .allowsHitTesting(false)
        }
    }
}

extension Theme {
    static func paper(
        _ color: Color, age: MemoAge = .fresh,
        radius: CGFloat = cardRadius, dotted: Bool = true
    ) -> some View {
        PaperSurface(tint: color, age: age, radius: radius, dotted: dotted)
    }

    /// 종이의 잘린 가장자리. 눈에 띄는 테두리가 아니라 형태를 잡아 주는 실선.
    static func edge(radius: CGFloat = cardRadius) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Paper.ink.opacity(0.10), lineWidth: 0.75)
    }
}

// MARK: - 조작

/// 포인터가 올라올 때만 나타나는 조작 버튼 (철학 4).
struct QuietButton: View {
    let symbol: String
    let help: String
    var isActive: Bool = false
    /// 되돌아오지 않는 쪽으로 가는 버튼. 색이 다른 것 자체가 안전장치다.
    ///
    /// 세기를 포인터에 맡기지 않는다 — 바탕화면 창은 키를 잡고 있지 않을 때가
    /// 많고, 그때 SwiftUI 의 `.onHover` 는 발화하지 않는다 (설계문서 §7.1).
    /// 눌러야 알 수 있는 경고는 경고가 아니다.
    var isDestructive: Bool = false
    let action: () -> Void

    private var tint: AnyShapeStyle {
        if isDestructive { return AnyShapeStyle(Theme.danger) }
        if isActive { return AnyShapeStyle(Theme.accent) }
        return AnyShapeStyle(.secondary)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .help(help)
    }
}
