import AppKit
import LazyMemoCore
import SwiftUI

/// 앱 아이콘의 두 글줄. 작은 크기에서도 같은 브랜드를 사용한다.
struct MemoBrandMark: View {
    var body: some View {
        Canvas { context, size in
            var first = Path()
            first.move(to: CGPoint(x: size.width * 0.23, y: size.height * 0.36))
            first.addLine(to: CGPoint(x: size.width * 0.77, y: size.height * 0.36))
            context.stroke(first, with: .color(Theme.onAccent), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            var second = Path()
            second.move(to: CGPoint(x: size.width * 0.23, y: size.height * 0.58))
            second.addCurve(to: CGPoint(x: size.width * 0.73, y: size.height * 0.73),
                            control1: CGPoint(x: size.width * 0.62, y: size.height * 0.58),
                            control2: CGPoint(x: size.width * 0.66, y: size.height * 0.70))
            context.stroke(second, with: .color(Color(red: 0.70, green: 0.84, blue: 0.60)),
                           style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
        }
        .frame(width: 27, height: 27)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

/// 크림과 포레스트: 편안한 바탕 위에 행동을 또렷하게 드러낸다.
/// 메모의 색과 자동 저장은 유지하며, 패널에는 명확한 제목과 조작을 둔다.
/// 2026-09 전면 개편의 시각 규칙은 docs/VISUAL_DESIGN.md를 따른다.
enum Theme {
    // MARK: 형태

    /// 본문 카드와 패널, 작은 조각의 모서리를 크기에 맞춰 구분한다.
    static let cardRadius: CGFloat = 14
    static let chipRadius: CGFloat = 8
    static let panelRadius: CGFloat = 20
    static let controlRadius: CGFloat = 10
    static let borderWidth: CGFloat = 1.5

    // MARK: 여백 — 다섯 단계

    static let hairline: CGFloat = 2
    static let tight: CGFloat = 6
    static let snug: CGFloat = 10
    static let normal: CGFloat = 14
    static let loose: CGFloat = 20

    // MARK: 손이 닿는 크기

    /// 누르는 자리의 최소 한 변.
    ///
    /// 이 앱의 조작은 대부분 그림 한 개이고, 그 그림은 작아도 된다 (철학 4).
    /// **닿는 자리까지 작을 이유는 없다.** 앞선 판은 그린 만큼만 누를 수 있어서
    /// 16·18pt 짜리 과녁이 줄줄이 서 있었다 — 조용한 것이 아니라 그냥 안
    /// 눌리는 것이었고, 게으른 사람을 전제로 만든 앱이 손끝의 정확도를
    /// 요구하고 있었다.
    ///
    /// 그림과 과녁을 갈라 놓는다. 색과 세기는 여전히 옅고 작지만, 누르는
    /// 자리는 언제나 이만큼이다 (`hitTarget`).
    static let touch: CGFloat = 24
    /// 낱말이 적힌 조각(「미루기」·「오늘」)의 최소 높이. 아이콘과 달리 가로로는
    /// 글자가 정하므로 높이만 잡아 준다.
    static let touchRow: CGFloat = 22

    // MARK: 글자 — 넷

    /// 메모 본문. 읽는 글.
    static var body: Font { .system(size: scaled(14)) }
    /// 빠른 입력. 한 줄 적고 마는 자리라 크다.
    static var capture: Font { .system(size: scaled(19), weight: .light) }
    static var title: Font { .system(size: scaled(13), weight: .semibold) }

    /// 꼬리에 적히는 글 — **숫자가 열을 이루는 자리다.**
    ///
    /// 이 두 층에 오는 것은 대개 날짜와 시각이다(「8월 31일 오후 2:30」·「오늘
    /// 9:30」). 비례 숫자는 `1` 이 좁고 `0` 이 넓어서, 한 자리가 바뀔 때마다
    /// 줄 전체가 좌우로 흔들린다 — 메뉴 목록처럼 여러 줄이 세로로 서는 곳에서는
    /// 그 흔들림이 줄마다 어긋난 오른쪽 끝으로 보인다.
    ///
    /// **글꼴을 바꾸지 않고 숫자 폭만 고정한다.** 고정폭 글꼴(`design: .monospaced`)
    /// 로 통째로 갈아 끼우면 한글이 그 글꼴에 없어 다른 얼굴로 떨어져 나가,
    /// 한 줄 안에서 두 글꼴이 섞인다. `monospacedDigit()` 은 같은 얼굴의 숫자만
    /// 등폭으로 바꾼다.
    static var label: Font { .system(size: scaled(11)).monospacedDigit() }
    static var micro: Font { .system(size: scaled(10)).monospacedDigit() }
    static var microMono: Font { .system(size: scaled(10), design: .monospaced) }

    static var bodyLineSpacing: CGFloat { scaled(3) }

    /// 글자 한 칸(`ThemeOverrides.textStep`)만큼 키운 pt.
    ///
    /// **층의 비율은 건드리지 않는다.** 넷(본문·빠른 입력·제목·꼬리)이 같은
    /// 비율로 함께 자란다 — 제목만 키우면 그건 큰 글자가 아니라 다른 디자인이다.
    /// 반 칸으로 끊는 것은 글꼴이 그보다 잘게는 다르게 앉지 않기 때문이다.
    static func scaled(_ points: CGFloat) -> CGFloat {
        track()
        return (points * CGFloat(ThemeRuntime.shared.resolved.textScale) * 2).rounded() / 2
    }

    // MARK: 색 — 테마가 정한다

    /// 그 외관에서 쓰는 색 한 벌 (`ThemeCatalog`). 그리는 닫힘 안에서도 부를 수
    /// 있도록 메인에 매이지 않는다.
    nonisolated static func variant(dark: Bool, highContrast: Bool = false) -> ThemeVariant {
        ThemeRuntime.shared.variant(dark: dark, highContrast: highContrast)
    }

    /// 지금 그리는 화면의 한 벌 — SwiftUI 본문에서.
    static func variant(_ scheme: ColorScheme) -> ThemeVariant {
        track()
        return ThemeRuntime.shared.variant(dark: scheme == .dark)
    }

    /// **이 종이가 어두운가** — 외관이 아니다.
    ///
    /// 「미드나잇」·「숲속 어둠」은 빛 모드에서도 어두운 종이다. 가장자리의 두께·
    /// 그림자·주말 색을 `colorScheme` 으로 고르면 그 테마에서만 전부 뒤집힌다
    /// (`ThemeVariant.darkPaper`).
    static func papersDark(_ scheme: ColorScheme) -> Bool { variant(scheme).darkPaper }

    /// **본문이 색을 읽었다고 알린다.**
    ///
    /// 색을 읽는 자리가 칠백 곳이라 그 전부를 관찰 대상으로 바꿀 수는 없었다.
    /// 대신 색을 돌려주는 계산 속성이 여기를 스치고 간다 — SwiftUI 가 본문을
    /// 부르는 동안이면 `ThemeStore.generation` 을 읽은 것이 되어, 테마를 바꾸면
    /// 그 본문들이 다시 그려진다. 메인 밖에서 불리면(그리는 닫힘 안) 아무 일도
    /// 하지 않는다: 그쪽은 `ThemeRuntime` 에서 값을 바로 읽으므로 알릴 것이 없다.
    nonisolated static func track() {
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated { _ = ThemeStore.shared.generation }
    }

    /// 앱 마크와 주요 행동 버튼이 공유하는 강조색.
    /// **면을 칠하는 색이다** — 글자에 쓰면 안 된다 (아래 `accentInk`).
    static let accentNSColor = themedColor { $0.accent }
    static var accent: Color { track(); return Color(nsColor: accentNSColor) }
    static let onAccentNSColor = themedColor { $0.onAccent }
    static var onAccent: Color { track(); return Color(nsColor: onAccentNSColor) }
    static var softAccent: Color { accentInk.opacity(0.09) }

    /// 둘째 줄·시각·안내. 잉크를 묽게 쓴다 (테마마다 묽기가 다르다).
    static let secondaryInkNSColor = themedColor { $0.secondaryInk }
    static var secondaryInk: Color { track(); return Color(nsColor: secondaryInkNSColor) }

    /// 같은 강조색을 **작은 글자와 아이콘으로 쓸 때** — 어두운 종이에서는
    /// 밝은 쪽으로 간다. 값은 테마가 정하고, 사용자가 색을 고른 경우에는
    /// 앱이 종이 위에서 4.5:1 까지 끌어올려 만든다 (`ThemeVariant.applying`).
    static let accentInkNSColor = themedColor { $0.accentInk }
    static var accentInk: Color { track(); return Color(nsColor: accentInkNSColor) }

    /// 오늘·지금을 가리키는 **면**. 글자에 쓰면 안 된다 (아래 `highlightInk`).
    static let highlightNSColor = themedColor { $0.highlight }
    static var highlight: Color { track(); return Color(nsColor: highlightNSColor) }

    /// 같은 색을 **글자로 쓸 때.**
    ///
    /// 밝은 호박색은 미색 종이 위에서 읽히지 않는다 — 대비 1.5:1 로, 날짜
    /// 칩의 글씨가 "있는 줄은 알겠는데 안 읽히는" 상태였다. 앱이 대신 읽어
    /// 준 날짜는 **확인하라고 보여주는 것**이라 안 읽히면 아무 일도 안 한
    /// 것과 같다. 그래서 밝은 종이에서는 잉크 쪽으로 가라앉힌다(5.2:1).
    /// 여덟 테마가 전부 이 바닥 위에 있는지는 `ThemeContrastTests` 가 잰다.
    static let highlightInkNSColor = themedColor { $0.highlightInk }
    static var highlightInk: Color { track(); return Color(nsColor: highlightInkNSColor) }

    /// 호박색 칩의 바탕. 글자가 가라앉은 만큼 바탕도 또렷해져야 칩이
    /// "붙은 딱지" 로 읽힌다.
    static let highlightWashNSColor = themedColor { $0.highlightWash }
    static var highlightWash: Color { track(); return Color(nsColor: highlightWashNSColor) }

    /// 지우기. 종이 위에서 튀지 않을 만큼 죽인 붉은색 — 경고등이 아니라
    /// "다른 종류의 버튼" 이라는 표시다.
    ///
    /// **테마가 건드리지 않는다.** 되돌아오지 않는 쪽으로 가는 버튼의 색은
    /// 종이의 취향이 아니라 약속이다 — 테마를 바꿨더니 지우기가 다른 색이면
    /// 그 약속을 매번 다시 배워야 한다. 원판 위에는 흰 글리프가 올라가므로
    /// 어느 종이에서나 같은 값이다.
    static let danger = Color(red: 0.76, green: 0.36, blue: 0.34)

    /// 같은 붉은색을 **종이 위의 글자·그림으로 쓸 때.** 어두운 종이에서 밝힌다.
    static let dangerInkNSColor = paperAwareColor(
        onLight: NSColor(srgbRed: 0.76, green: 0.36, blue: 0.34, alpha: 1),
        onDark: NSColor(srgbRed: 0.94, green: 0.58, blue: 0.54, alpha: 1)
    )
    static var dangerInk: Color { track(); return Color(nsColor: dangerInkNSColor) }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑. 이것도 테마 밖이다(관행이다).
    ///
    /// 어두운 종이 위에서는 둘 다 밝은 쪽으로 올린다. 밝은 종이의 값을 그대로
    /// 쓰면 주말 숫자만 평일보다 흐려서, 관행을 지키려던 색이 도리어 그 이틀을
    /// 가장 안 읽히는 칸으로 만든다.
    static let sundayNSColor = paperAwareColor(
        onLight: NSColor(srgbRed: 0.85, green: 0.35, blue: 0.35, alpha: 1),
        onDark: NSColor(srgbRed: 0.94, green: 0.52, blue: 0.50, alpha: 1)
    )
    static let saturdayNSColor = paperAwareColor(
        onLight: NSColor(srgbRed: 0.35, green: 0.50, blue: 0.82, alpha: 1),
        onDark: NSColor(srgbRed: 0.52, green: 0.68, blue: 0.96, alpha: 1)
    )
    static var sunday: Color { track(); return Color(nsColor: sundayNSColor) }
    static var saturday: Color { track(); return Color(nsColor: saturdayNSColor) }

    // MARK: 움직임

    /// 되살아나고 물러나는 속도 — 낱말은 `Motion` 하나다. 종이가 또렷해지는 것과
    /// 서랍의 줄이 밝아지는 것이 다른 속도면 같은 앱으로 안 읽힌다 (2026-09-18 모션 감사).
    static var reveal: Animation { Motion.quick }
    static var settle: Animation { Motion.settle }
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

    /// 외관이 아니라 **이 테마의 종이가** 어두운가 (`Theme.papersDark`).
    private var isDark: Bool { Theme.papersDark(colorScheme) }

    /// 종이 한 장의 색. 잉크를 종이로 눕히고 스미는 몫까지 `PaperTint` 가 잰다 —
    /// 그 값들은 여섯 장을 나란히 놓고 재야 옳은지 알 수 있어서 뷰 밖에 있다.
    private var surface: Color {
        Color(nsColor: PaperTint.surface(ink: tint, dark: isDark, presence: age.presence))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(surface)
            .overlay {
                if dotted {
                    // 점은 종이의 격자이지 무늬가 아니다. 가장자리에 두께가
                    // 생기면서 종이가 물건으로 읽히기 시작했으므로, 점은 그만큼
                    // 물러나도 된다 — 눈에 띄면 격자가 아니라 무늬가 된다.
                    //
                    // 숯색 종이에서 조금 더 진한 것은 앞선 판과 같은 이유다:
                    // 어두운 바탕에서 옅은 점은 점이 아니라 잡티로 보인다.
                    // 세기는 테마가 정한다. 무채로 가는 테마는 색까지 고정한다
                    // (`ThemeVariant.ruleInk`) — 그 종이에서는 점도 색을 띠지 않는다.
                    DotGrid(color: (Theme.variant(colorScheme).ruleInk?.color ?? tint)
                        .opacity(Theme.variant(colorScheme).ruleOpacity))
                }
            }
            .overlay {
                // 결은 꺼 둘 수 있다 (`ThemeOverrides.paperTexture`) — 아주 옅지만
                // 매끈한 면을 좋아하는 사람이 있다.
                if ThemeRuntime.shared.resolved.paperTexture {
                    PaperGrain()
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
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
                // 점을 물린 만큼(`PaperSurface`) 결이 그 몫을 조금 받는다 —
                // 종이를 물건으로 만드는 것은 격자가 아니라 표면이다.
                .opacity(0.045)
                .allowsHitTesting(false)
        }
    }
}

/// 종이 위에 떠 있는 조각 — 겹쳐 뜨는 조작 캡슐의 면 (`PaperTint.raised`).
///
/// 그림자도 외관을 따른다. 어두운 종이 위의 검은 그림자는 보이지 않으므로
/// 더 짙게 깔아야 조각이 실제로 떠 보인다.
struct RaisedSurface: View {
    let ink: Color
    /// `nil` 이면 캡슐, 값이 있으면 그 모서리의 사각형.
    var radius: CGFloat?
    var shadow: CGFloat = 3
    var lift: CGFloat = 1

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = Theme.papersDark(colorScheme)
        let fill = Color(nsColor: PaperTint.raised(ink: ink, dark: dark))
        Group {
            if let radius {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            } else {
                Capsule().fill(fill)
            }
        }
        // **그림자는 두 겹이다.** 한 겹으로는 «닿아 있음» 과 «떠 있음» 을 같은
        // 흐림으로 말해야 해서, 반경을 키우면 조각이 공중에 뜨고 줄이면 바닥에
        // 붙는다. 실제 물건은 둘을 동시에 한다 — 닿는 자리에 좁고 진한 그림자가
        // 있고, 그 둘레로 넓고 옅은 그림자가 퍼진다.
        .shadow(
            color: .black.opacity(dark ? 0.20 : 0.06),
            radius: 1, y: 0.5
        )
        .shadow(
            color: .black.opacity(dark ? 0.16 : 0.06),
            radius: shadow * 1.6, y: lift + 1
        )
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
        PaperEdge(radius: radius)
    }
}

/// 종이의 잘린 가장자리 — **두께가 있다.**
///
/// 앞선 판은 사방을 같은 세기(잉크 10%)로 둘렀다. 형태는 잡아 주지만 종이가
/// 얼마나 두꺼운지는 말하지 않아서, 가까이서 보면 여전히 **색칠한 사각형**이었다.
/// 떠 있다는 느낌을 그림자 하나에 전부 맡기고 있었던 셈이다 (철학 「재질은 하나」).
///
/// 빛은 위에서 온다. 그러면 종이의 윗변은 빛을 받아 밝고 아랫변은 자기 두께에
/// 가려 어둡다 — 그 한 줄 차이가 두께다. 선을 굵히지 않고 **위아래의 세기만
/// 갈라** 놓는다: 굵은 테두리는 종이가 아니라 카드가 된다.
///
/// 세기를 외관마다 따로 잡는 이유는 `Theme.accentInk` 와 같다. 어두운 종이
/// 위에서 흰 실선을 빛 모드만큼 밝히면 그건 두께가 아니라 **광택**이 되고,
/// 검은 실선은 아예 보이지 않는다.
struct PaperEdge: View {
    var radius: CGFloat = Theme.cardRadius

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = Theme.papersDark(colorScheme)
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(dark ? 0.10 : 0.85), location: 0),
                        // 옆면은 앞선 판이 두르던 그 값 그대로다 — 좌우는
                        // 빛을 스치듯 받으므로 밝지도 어둡지도 않다.
                        .init(color: Paper.ink.opacity(0.10), location: 0.42),
                        .init(color: dark ? .black.opacity(0.42) : Paper.ink.opacity(0.20), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.75
            )
    }
}

// MARK: - 소리 내어 읽기

/// 그림 하나뿐인 버튼이 **이름을 갖게 한다.**
///
/// 이 앱의 조작은 대부분 그림 한 개다 (철학 4 — 앱은 자기를 드러내지 않는다).
/// 눈으로 보는 사람에게는 그것이 조용함이지만, VoiceOver 를 쓰는 사람에게는
/// 「trash」·「xmark」·「pin」이라는 **영어 기호 이름**이 읽힌다. 조용한 화면이
/// 거기서는 알아들을 수 없는 화면이 된다.
///
/// 새 낱말을 만들지 않는다. 이미 붙여 둔 도움말이 곧 이름이다 — 「지우기 —
/// 메뉴의 되돌리기로 살릴 수 있습니다」에서 앞이 이름, 「—」 뒤가 힌트다.
/// 그래야 눈으로 읽는 말과 귀로 듣는 말이 어긋나지 않는다.
enum SpokenHelp {
    static func split(_ help: String) -> (name: String, hint: String) {
        let parts = help.components(separatedBy: " — ")
        guard let name = parts.first, parts.count > 1 else { return (help, "") }
        return (name, parts.dropFirst().joined(separator: " — "))
    }
}

extension View {
    /// 보이는 것은 그대로 두고 **누르는 자리만** 넓힌다 (`Theme.touch`).
    ///
    /// 그림을 키우는 것과 다르다. 옅은 핀 하나, 9pt 짜리 낱말은 그대로 두고
    /// 그 둘레의 빈자리까지 판정에 넣는다 — 화면은 조용한 채로 손만 편해진다.
    func hitTarget(_ side: CGFloat = Theme.touch) -> some View {
        frame(minWidth: side, minHeight: side)
            .contentShape(.rect)
    }

    /// 도움말을 그대로 VoiceOver 의 이름과 힌트로 쓴다.
    func spoken(_ help: String) -> some View {
        let said = SpokenHelp.split(help)
        return self
            .help(help)
            .accessibilityLabel(Text(said.name))
            .accessibilityHint(Text(said.hint))
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
        if isDestructive { return AnyShapeStyle(Theme.dangerInk) }
        if isActive { return AnyShapeStyle(Theme.accentInk) }
        return AnyShapeStyle(.secondary)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                // 조작이 첫 줄을 덮지 않는다는 약속은 이 숫자 위에 서 있다
                // (`NoteControlLayout`) — 여기서 키우면 그쪽 시험이 잡는다.
                .frame(width: NoteControlLayout.button, height: NoteControlLayout.button)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        // 그림 하나뿐인 버튼이라 이름을 따로 준다 — 안 그러면 VoiceOver 가
        // 「trash」라고 읽는다 (`SpokenHelp`).
        .spoken(help)
    }
}
