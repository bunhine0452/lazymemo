import SwiftUI

/// 목록 한 줄의 휴지통 — **빠른 입력과 달력이 같은 것을 쓴다.**
///
/// 지우는 길이 셋인데(종이·목록·달력) 생김새가 셋이면 사람은 그것을 세 개의
/// 조작으로 배운다 (§14.10 — 두 곳에서 같은 일을 다르게 그리면 두 개의
/// 목록이 된다). 그래서 한 벌만 두고 양쪽이 가져다 쓴다.
///
/// **평상시에는 붉지 않다.** 다섯 줄 전부에 붉은 휴지통을 그렸더니 목록
/// 오른쪽에 붉은 기둥이 하나 섰다 — 그러면 이 상자에서 가장 눈에 띄는 것이
/// 가장 위험한 조작이 되고, 적으러 연 사람에게 화면이 "지워라" 라고 다섯 번
/// 말한다. 붉은색은 **그 휴지통 하나에 손이 닿았을 때**만 나온다. 그때는
/// 정말로 그 말이 필요하다 — 누르기 전에 "이건 다른 종류의 버튼" 이라고
/// 한 번은 말해 줘야 한다.
///
/// **아주 숨기지도 않는다.** 포인터가 온 줄에서만 나타나게 하면 화면은
/// 깨끗해지지만, 있는 줄을 모르는 조작은 없는 것과 같다.
struct RowTrash: View {
    /// 이 줄이 골라져 있는가. 손과 키보드가 같은 밝기를 본다.
    var isLit = false
    /// 화면 밖 렌더에서 포인터를 흉내 낸다 (설계문서 §14.9).
    var staged = false
    var help = L("지우기 — 바로 아래 줄에서 되돌릴 수 있습니다")
    let action: () -> Void

    @State private var isOver = false

    /// 평상시 세기. 있는 줄을 알 만큼만 (메뉴 목록의 24% 와 같은 뜻).
    static let resting: Double = 0.28
    /// 골라진 줄에서. 붉지 않은 만큼 조금 더 또렷해야 눈에 든다.
    static let lit: Double = 0.62

    private var over: Bool { staged || isOver }

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 11.5, weight: .semibold))
                // 손이 닿기 전까지는 종이의 잉크색이다.
                .foregroundStyle(over ? AnyShapeStyle(.white) : AnyShapeStyle(Paper.ink))
                .opacity(over ? 1 : (isLit ? Self.lit : Self.resting))
                // 원판은 그림에 맞춰 작게, 누르는 자리는 `Theme.touch` 까지.
                // 붉은 원이 과녁만큼 커지면 목록에서 가장 큰 것이 지우기가 된다.
                .frame(width: 21, height: 21)
                .background {
                    if over { Circle().fill(Theme.danger) }
                }
                .hitTarget()
        }
        .buttonStyle(.plain)
        .onHover { isOver = $0 }
        .animation(Theme.reveal, value: over)
        .spoken(help)
    }
}
