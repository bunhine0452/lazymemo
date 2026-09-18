import SwiftUI

/// 폰이 쓰는 **움직임의 낱말** — 맥과 같은 셋, 같은 시간 (`Sources/LazyMemoUI/QuickCapture/Motion.swift`).
///
/// 두 기기에서 같은 일이 다른 속도로 일어나면 사람은 그것을 두 앱으로 배운다
/// (§14.10 이 목록의 낱말을 놓고 한 이야기와 같다). 모으기 전에는 폰 쪽만
/// 넷이었다 — 달 넘김 `.smooth(0.3)`, 머리 `easeInOut(0.18)`, 목록 `.snappy`,
/// 밝히기 `easeOut(0.6)`.
///
/// | 낱말 | 무엇에 |
/// |---|---|
/// | `quick` | 값 하나 — 칩이 서고 물러남, 강조, 켜짐/꺼짐 |
/// | `settle` | 자리를 잡는 것 — 달 판이 미끄러져 앉음, 방금 생긴 줄이 밝아짐 |
/// | `fly` | 화면이 그리로 가는 것 — 목록이 새 줄로 스크롤 |
///
/// 스프링이되 튕기지 않는다 (`.smooth` = bounce 0). 가로채기 때문에 스프링이다 —
/// 미끄러지는 중에 다시 잡으면 지금 속도를 이어받는다
/// ("Allow for constant redirection and interruption", WWDC18 803).
///
/// 움직임을 줄인 사람에게는 축 이동 대신 페이드 (HIG Accessibility —
/// "Replacing transitions in x-, y-, and z-axes with fades").
enum Motion {
    static let quickDuration: TimeInterval = 0.18
    static let settleDuration: TimeInterval = 0.30
    static let flyDuration: TimeInterval = 0.32

    static let quick = Animation.smooth(duration: quickDuration)
    static let settle = Animation.smooth(duration: settleDuration)
    static let fly = Animation.snappy(duration: flyDuration, extraBounce: 0)

    /// 자리를 옮기는 것은 옮기지 않는다.
    static let instant = Animation.linear(duration: 0.01)
    /// 드러나고 물러나는 것은 남긴다 — 짧은 교차 페이드.
    static let crossFade = Animation.easeInOut(duration: 0.12)

    static func quick(_ reduced: Bool) -> Animation { reduced ? crossFade : quick }
    static func settle(_ reduced: Bool) -> Animation { reduced ? crossFade : settle }
    static func fly(_ reduced: Bool) -> Animation { reduced ? instant : fly }
}
