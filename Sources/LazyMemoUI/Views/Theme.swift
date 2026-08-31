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

    /// 앱 마크의 판 색. 아이콘과 UI 가 같은 딥 슬레이트 네이비를 쓴다.
    /// **면을 칠하는 색이다** — 글자에 쓰면 안 된다 (아래 `accentInk`).
    static let accent = Color(red: 0.18, green: 0.26, blue: 0.38)

    /// 같은 네이비를 **글자로 쓸 때.**
    ///
    /// 호박색에서 한 번 겪은 일이다 (아래 `highlightInk`) — 면에 맞게 고른 색을
    /// 글자에 그대로 쓰면 한쪽 외관에서 읽히지 않는다. 딥 네이비는 미색 종이
    /// 위에서 또렷하지만(11:1) 숯색 종이 위에서는 **바탕에 잠긴다**(1.6:1).
    /// 「되돌리기」가 안 읽히면 그 줄은 있으나 마나다.
    static let accentInkNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.60, green: 0.72, blue: 0.90, alpha: 1)
            : NSColor(srgbRed: 0.18, green: 0.26, blue: 0.38, alpha: 1)
    }
    static var accentInk: Color { Color(nsColor: accentInkNSColor) }
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
    ///
    /// **원판을 칠하는 색이다.** 그 위에는 흰 글리프가 올라가므로 두 외관에서
    /// 같은 값을 쓴다 — 밝히면 흰 글리프가 도리어 안 보인다.
    static let danger = Color(red: 0.76, green: 0.36, blue: 0.34)

    /// 같은 붉은색을 **종이 위의 글자·그림으로 쓸 때.**
    static let dangerInkNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.94, green: 0.58, blue: 0.54, alpha: 1)
            : NSColor(srgbRed: 0.76, green: 0.36, blue: 0.34, alpha: 1)
    }
    static var dangerInk: Color { Color(nsColor: dangerInkNSColor) }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    ///
    /// 숯색 종이 위에서는 둘 다 밝은 쪽으로 올린다. 빛 모드의 값을 그대로 쓰면
    /// 주말 숫자만 평일보다 흐려서, 관행을 지키려던 색이 도리어 그 이틀을
    /// 가장 안 읽히는 칸으로 만든다.
    static let sundayNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.94, green: 0.52, blue: 0.50, alpha: 1)
            : NSColor(srgbRed: 0.85, green: 0.35, blue: 0.35, alpha: 1)
    }
    static let saturdayNSColor = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.52, green: 0.68, blue: 0.96, alpha: 1)
            : NSColor(srgbRed: 0.35, green: 0.50, blue: 0.82, alpha: 1)
    }
    static var sunday: Color { Color(nsColor: sundayNSColor) }
    static var saturday: Color { Color(nsColor: saturdayNSColor) }

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

    private var isDark: Bool { colorScheme == .dark }

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
                    DotGrid(color: tint.opacity(isDark ? 0.30 : 0.28))
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
        let fill = Color(nsColor: PaperTint.raised(ink: ink, dark: colorScheme == .dark))
        Group {
            if let radius {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            } else {
                Capsule().fill(fill)
            }
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.36 : 0.14),
            radius: shadow, y: lift
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
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Paper.ink.opacity(0.10), lineWidth: 0.75)
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
                .font(.system(size: 10, weight: .semibold))
                // 조작이 첫 줄을 덮지 않는다는 약속은 이 숫자 위에 서 있다
                // (`NoteControlLayout`) — 여기서 키우면 그쪽 시험이 잡는다.
                .frame(width: NoteControlLayout.button, height: NoteControlLayout.button)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        // 그림 하나뿐인 버튼이라 이름을 따로 준다 — 안 그러면 VoiceOver 가
        // 「trash」라고 읽는다 (`SpokenHelp`).
        .spoken(help)
    }
}
