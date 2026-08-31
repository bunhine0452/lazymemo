import CoreGraphics
import Foundation
import LazyMemoCore

/// 「달력」이 쓰는 값들 — **자와 눈금이 아니라 잉크와 손의 계산.**
///
/// 여기 있는 것은 전부 뷰 밖의 순수 값이다. 이유는 `MonthGridGeometry` 와
/// 같다: 번진 정도가 한 단계 어긋난 것, 손으로 그린 획이 렌더마다 달라지는
/// 것은 그림만 봐서는 판별되지 않는다. 화면에서 확인할 수 없는 것은
/// 테스트로 못 박는다.

// MARK: - 손

/// 한 획을 긋는 손. 같은 씨앗이면 **언제나 같은 획**이 나온다.
///
/// 손으로 그린 것처럼 보이려면 흔들려야 하는데, 매 프레임 새로 흔들리면
/// 그것은 손이 아니라 잡음이다. 날짜에서 씨앗을 뽑아 두면 오늘의 동그라미는
/// 하루 종일 같은 모양이고, 내일은 새로 그은 것이 된다.
struct PenHand {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0xD1B5_4A32_D192_ED03
    }

    /// 0 이상 1 미만. SplitMix64 — 짧고, 이식 가능하고, 씨앗 하나로 재현된다.
    mutating func next() -> CGFloat {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed = mixed ^ (mixed >> 31)
        return CGFloat(Double(mixed >> 11) / Double(1 << 53))
    }

    /// ±amount 안에서 흔들리는 값.
    mutating func jitter(_ amount: CGFloat) -> CGFloat {
        (next() * 2 - 1) * amount
    }
}

extension CalendarDate {
    /// 이 날을 긋는 손. 날이 바뀌면 획도 새로 그어진다.
    var penSeed: UInt64 {
        UInt64(bitPattern: Int64(year) &* 10_000 &+ Int64(month) &* 100 &+ Int64(day))
    }
}

// MARK: - 번짐

/// 그 날에 일이 얼마나 있는가 — **세지 않고 번진 정도로 말한다.**
///
/// 앞선 판은 날짜 아래에 캡슐 점을 최대 셋 찍고 넷을 넘으면 셋째를 막대로
/// 늘였다. 읽히긴 했지만 그것은 **여전히 세는 표시**였고, 칸마다 뷰가 넷씩
/// 생겼다. 지금은 뒷면에서 배어 나온 잉크 얼룩 하나로 바꿨다 — 색은 그대로
/// 따라오고, 붐비는 날은 한눈에 짙다. 달을 통째로 보면 **이 달에 내가 얼마나
/// 바빴는지가 얼룩의 지도**로 보인다.
enum InkBleed {
    /// 한 칸에 겹쳐 찍는 색의 최대 수. 넷째부터는 색이 아니라 진흙이 된다.
    static let maxInks = 3

    /// 건수를 번진 정도(0…1)로 옮긴다.
    ///
    /// 계속 자라되 곧 멎어야 한다. 다섯과 여덟의 차이는 게으른 사람에게
    /// 아무 뜻도 없고, 선형으로 두면 붐비는 달에서 얼룩이 칸을 삼킨다.
    static func spread(count: Int) -> Double {
        guard count > 0 else { return 0 }
        return 1 - pow(0.62, Double(count))
    }

    /// 얼룩이 앉는 자리 — 칸 한가운데에서 아래로 내린 만큼 (칸 높이의 비).
    /// 숫자 뒤에 두면 숫자가 원판 위에 올라앉아 "고른 칸" 으로 읽힌다.
    static let drop: CGFloat = 0.30
    /// 세로로 눌린 정도. 종이결을 따라 옆으로 번지는 것이 잉크의 성질이다.
    /// 너무 납작하면 얼룩이 아니라 **긁힌 자국**으로 보인다.
    static let squash: CGFloat = 0.74

    /// 얼룩의 반지름. 칸의 짧은 변을 기준으로 잡아 5주 달과 6주 달에서
    /// 같은 비율로 보이게 한다.
    ///
    /// **폭이 좁았다.** 한 건과 네 건의 지름 차이가 30% 뿐이라 나란히 놓아도
    /// 같은 크기로 보였고, 그러면 얼룩은 "이 날은 붐빈다" 를 말하지 못한 채
    /// 그냥 종이에 묻은 자국 — 인쇄 얼룩 — 이 된다. 한 건은 더 작게, 붐비는
    /// 날은 더 크게 벌린다 (`legibleSpan`).
    static func radius(cell: CGSize, spread: Double) -> CGFloat {
        min(cell.width, cell.height) * CGFloat(0.11 + 0.22 * spread)
    }

    /// 얼룩 한복판의 세기. 가장자리로 가며 사라지므로 눈에 닿는 색은 이보다
    /// 한참 옅다 — 여기서 아끼면 얼룩이 잿빛 그림자가 된다.
    ///
    /// 뒤에 겹치는 색일수록 조금씩 옅다. 종이를 더 먹으면 그것은 얼룩이
    /// 아니라 칠이다.
    ///
    /// **대비도 폭과 같은 이유로 벌린다.** 한 건은 슬쩍 밴 자국, 네 건은
    /// 종이가 젖을 만큼 — 한눈에 갈리는 것이 이 표시의 전부다.
    static func alpha(spread: Double, order: Int) -> Double {
        (0.30 + 0.58 * spread) * pow(0.86, Double(order))
    }

    /// 한 건과 네 건이 이만큼은 갈려야 한다. 폭과 대비 양쪽에 같은 잣대를
    /// 대고 시험이 못 박는다 (`CalendarInkTests`) — 화면에서는 "좀 진한가"
    /// 까지밖에 말할 수 없는 종류의 값이다.
    static let legibleSpan = 1.4
}

// MARK: - 마름

/// 지난 날은 스스로 물러난다 (철학 3) — 그런데 **한꺼번에 물러나지 않는다.**
///
/// 앞선 판은 지난 날을 전부 55% 로 눕혔다. 그러면 어제와 3주 전이 같은
/// 세기가 되고, 그것은 "물러남" 이 아니라 그냥 회색이다. 잉크는 하루씩
/// 마른다.
enum InkDrying {
    /// 어제. 막 지난 것은 아직 축축하다.
    static let freshest = 0.70
    /// 더는 마르지 않는 바닥. 여기서 더 빼면 물러남이 아니라 사라짐이다.
    static let driest = 0.34
    private static let perDay = 0.011

    static func presence(daysAgo: Int) -> Double {
        guard daysAgo > 0 else { return 1 }
        return max(driest, freshest - Double(daysAgo - 1) * perDay)
    }
}

// MARK: - 달 띠

/// 머리의 달 이름 띠 — `7월  8월  9월`.
///
/// 화살표 두 개를 버렸다. `‹ ›` 는 어느 앱에나 있는 부품이라 이 창이 무엇으로
/// 만들어졌는지 말해 주지 않고, 무엇보다 **어디로 가는지 이름을 대지 않는다.**
/// 이웃 달의 이름을 옅게 적어 두면 시간이 양옆으로 뻗어 있는 것이 그대로
/// 보이고, 누르는 자리가 곧 도착지의 이름이 된다 (철학 2 — 시간이 유일한 구조).
enum MonthStrip {
    /// 이웃 달의 번호. 12월 다음은 1월이고 1월 앞은 12월이다.
    static func neighbor(of month: Int, by delta: Int) -> Int {
        (((month - 1 + delta) % 12) + 12) % 12 + 1
    }
}

// MARK: - 방금 한 일

/// 되돌리기 줄에 적히는 말.
///
/// 낱말이 셋인 이유는 **일어난 일이 셋**이기 때문이다. 달력 안에서 날을 바꾼
/// 것과, 종이에서 달력으로 건너온 것과, 달력에서 종이로 내려간 것은 되돌렸을
/// 때 돌아가는 자리가 서로 다르다 (설계문서 §7.2). "옮겼습니다" 하나로 뭉뚱그리면
/// 방금 무엇이 어디로 갔는지를 사용자가 화면에서 다시 찾아야 한다.
enum MoveNote {
    static func text(from: Schedule, to: CalendarDate?) -> String {
        guard let to else { return "종이로 보냈습니다" }
        let day = "\(to.month)월 \(to.day)일"
        // 원래 자리가 없던 것은 "옮긴" 것이 아니라 처음 "놓은" 것이다.
        return from.isEmpty ? "\(day)에 놓았습니다" : "\(day)로 옮겼습니다"
    }
}
