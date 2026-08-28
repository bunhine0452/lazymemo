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

    static let cardRadius: CGFloat = 16
    static let panelRadius: CGFloat = 20
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

/// 메모와 흐름이 놓이는 면.
///
/// 색은 **왼쪽 위에서 번져 나온다.** 단색으로 고르게 칠하면 인쇄물처럼 보이고,
/// 종이 전체를 물들이면 글이 읽히지 않는다. 잉크가 한쪽에서 번지는 모양이
/// 손으로 적은 물건의 감각에 가깝고, 읽는 면 대부분은 중립으로 남는다.
///
/// 도형 하나에 그라디언트 하나로 끝낸다 — 겹치면 창마다 레이어가 늘고,
/// 메모 열 장이면 그것만으로 메모리 예산(§11)의 1할을 먹는다.
struct PaperSurface: View {
    let tint: Color
    var age: MemoAge = .fresh
    var radius: CGFloat = Theme.cardRadius

    @Environment(\.colorScheme) private var colorScheme

    /// 어두운 면에는 색을 훨씬 옅게 깐다. 밝은 종이에 노랑을 섞으면 크림색이
    /// 되지만, 검은 면에 같은 값을 섞으면 진흙빛 올리브가 된다.
    private var inkStrength: Double {
        (colorScheme == .dark ? 0.16 : 0.30) * age.presence
    }

    /// 종이색과 잉크를 **미리 섞어** 그라디언트 양 끝 색을 만든다.
    ///
    /// 그라디언트를 종이 위에 겹쳐 칠하면 도형이 둘이 되고, 창마다 레이어가
    /// 하나씩 늘어 메모 열 장이면 예산(§11)에서 4MB 를 먹는다. 색을 먼저
    /// 섞으면 도형 하나로 같은 그림이 나온다.
    private var inkStops: (Color, Color) {
        var paper = NSColor.white
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)?
            .performAsCurrentDrawingAppearance {
                // 동적 색은 대입만으로 해석되지 않는다. 이 안에서 변환해야 한다.
                paper = NSColor.textBackgroundColor.usingColorSpace(.sRGB) ?? .white
            }

        guard let ink = NSColor(tint).usingColorSpace(.sRGB) else {
            let plain = Color(nsColor: paper)
            return (plain, plain)
        }

        let near = paper.blended(withFraction: inkStrength, of: ink) ?? paper
        let far = paper.blended(withFraction: inkStrength * 0.15, of: ink) ?? paper
        return (Color(nsColor: near), Color(nsColor: far))
    }

    var body: some View {
        let stops = inkStops
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [stops.0, stops.1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(0.95)
    }
}

extension Theme {
    static func paper(_ color: Color, age: MemoAge = .fresh, radius: CGFloat = cardRadius) -> some View {
        PaperSurface(tint: color, age: age, radius: radius)
    }

    /// 색이 드러나는 테두리. 창이 겹치면 보이는 것은 결국 가장자리다.
    static func edge(_ color: Color, age: MemoAge = .fresh, radius: CGFloat = cardRadius) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(color.opacity(0.45 * age.presence), lineWidth: borderWidth)
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
