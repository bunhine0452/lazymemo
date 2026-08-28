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
/// "언제"뿐이다. 그래서 캘린더는 격자가 아니라 **흐름**이고, 빠른 입력은
/// 한국어 날짜 표현을 스스로 읽는다. 사용자가 형식을 배우게 하지 않는다.
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
/// 유리(`glassEffect`)를 쓰지 않는다. 메모에서, 흐름에서, 빠른 입력에서
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
    static let cardRadius: CGFloat = 3
    static let panelRadius: CGFloat = 4
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
    static let highlight = Color(red: 0.99, green: 0.76, blue: 0.31)

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    static let sunday = Color(red: 0.85, green: 0.35, blue: 0.35)
    static let saturday = Color(red: 0.35, green: 0.50, blue: 0.82)

    // MARK: 움직임

    /// 되살아나고 물러나는 속도. 튀거나 튕기지 않는다.
    static let reveal = Animation.easeOut(duration: 0.18)
    static let settle = Animation.easeInOut(duration: 0.28)
}

// MARK: - 종이

/// 메모가 놓이는 면 — **화면 위의 사각형이 아니라 종이 한 장.**
///
/// 매끈한 단색 면은 색을 아무리 잘 골라도 UI 로 보인다. 실제 종이가 물건으로
/// 보이는 이유는 네 가지다. 여기서 그 넷을 다 흉내 낸다.
///
/// 1. **온 면이 색이다.** 접착 메모지는 가장자리만 노란 것이 아니다.
/// 2. **표면이 고르지 않다.** 잡티와 섬유가 빛을 불규칙하게 되받아친다 (`PaperGrain.png`).
/// 3. **위쪽이 다르다.** 접착제가 붙은 띠가 미묘하게 짙게 비친다.
/// 4. **아래가 들린다.** 바닥에 닿는 쪽에 그늘이 진다.
///
/// 그리고 **시간이 지나면 누레진다** (`MemoAge`) — 투명도를 낮추는 것보다
/// 종이다운 늙음이다.
struct PaperSurface: View {
    let tint: Color
    var age: MemoAge = .fresh
    var radius: CGFloat = Theme.cardRadius

    @Environment(\.colorScheme) private var colorScheme

    /// 어두운 방의 종이는 덜 밝다. 색을 바꾸지 않고 밝기만 낮춘다 —
    /// 다크 모드라고 종이가 검어지지는 않는다.
    private var dimming: Double {
        colorScheme == .dark ? 0.88 : 1.0
    }

    private var surface: Color {
        guard let base = NSColor(tint).usingColorSpace(.sRGB),
              let aged = NSColor(Paper.aged).usingColorSpace(.sRGB)
        else { return tint }

        // 나이가 들수록 마닐라색 쪽으로 간다.
        let yellowing = (1 - age.presence) * 0.75
        let mixed = base.blended(withFraction: yellowing, of: aged) ?? base

        guard dimming < 1,
              let dimmed = mixed.blended(withFraction: 1 - dimming, of: .black)
        else { return Color(nsColor: mixed) }
        return Color(nsColor: dimmed)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(surface)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                // 접착 띠 — 위쪽이 살짝 짙다.
                                .init(color: .black.opacity(0.055), location: 0),
                                .init(color: .black.opacity(0.012), location: 0.06),
                                .init(color: .clear, location: 0.16),
                                .init(color: .clear, location: 0.86),
                                // 바닥에 닿는 그늘.
                                .init(color: .black.opacity(0.06), location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .overlay {
                PaperGrain()
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
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
                // 결은 알아채지 못할 만큼만. 눈에 띄면 잡티가 아니라 잡음이 된다.
                .opacity(0.30)
                .allowsHitTesting(false)
        }
    }
}

/// 괘선. 글줄이 그 위에 앉는다.
///
/// `Canvas` 로 한 번에 그린다. `Rectangle` 을 줄 수만큼 쌓으면 창마다 레이어가
/// 그만큼 늘어 예산(§11)을 먹는다.
struct RuledLines: View {
    var topInset: CGFloat
    var pitch: CGFloat = Paper.linePitch
    var color: Color = Paper.rule

    var body: some View {
        Canvas { context, size in
            // 글줄의 밑선이 괘선 위에 앉도록 맞춘다.
            var y = topInset + pitch - 9
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 0.7)),
                    with: .color(color)
                )
                y += pitch
            }
        }
        .allowsHitTesting(false)
    }
}

extension Theme {
    static func paper(_ color: Color, age: MemoAge = .fresh, radius: CGFloat = cardRadius) -> some View {
        PaperSurface(tint: color, age: age, radius: radius)
    }

    /// 종이의 잘린 가장자리. 색 테두리가 아니라 **종이 두께**를 흉내 낸다.
    static func edge(radius: CGFloat = cardRadius) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(.black.opacity(0.10), lineWidth: 0.75)
    }
}

// MARK: - 조작

/// 포인터가 올라올 때만 나타나는 조작 버튼 (철학 4).
struct QuietButton: View {
    let symbol: String
    let help: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
        .help(help)
    }
}
