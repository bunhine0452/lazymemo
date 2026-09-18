import AppKit
import SwiftUI

/// 이 앱이 쓰는 **움직임의 낱말** — 셋뿐이다.
///
/// ## 왜 한자리에 모았나
///
/// 재질이 하나여야 화면이 한 물건으로 읽히듯(§14.5), 움직임도 하나여야 한다.
/// 모으기 전에는 같은 뜻의 움직임이 화면마다 다른 속도로 있었다 —
/// 서랍의 호버는 `easeOut(0.14)`, 달력의 호버는 `easeOut(0.18)`,
/// 자리 카드의 점은 `.snappy`, 빠른 입력의 칩은 또 `easeOut(0.18)`.
/// 우연히 비슷했을 뿐 같은 값이 아니어서, 한쪽을 고치는 사람은 다른 쪽이
/// 있는 줄 몰랐다 (`PaperEdge` 가 배운 것과 같은 이야기).
///
/// | 낱말 | 무엇에 | 왜 이 값 |
/// |---|---|---|
/// | `quick` | 값 하나가 바뀌는 것 — 손이 얹힘, 강조, 칩이 서고 물러남 | 손에 붙어야 한다. 0.18초보다 길면 늦고, 짧으면 깜빡임이 된다 |
/// | `settle` | 자리를 잡는 것 — 목록이 바뀜, 고른 날이 옮겨 앉음 | 눈이 따라갈 수 있어야 한다 |
/// | `fly` | 창·판이 통째로 움직이는 것 — 서랍이 펼쳐지고 접힘 | **`NSWindow` 의 프레임 변화와 같은 곡선·같은 시간**이어야 한다 |
///
/// 스프링을 쓰되 **튕기지 않는다** (`.smooth` = bounce 0). 종이는 고무가 아니고,
/// 튕기는 종이는 열 장이 겹친 바탕화면에서 어지럽다. 스프링인 이유는 곡선이
/// 아니라 **가로채기** 때문이다 — 끝나기 전에 값이 또 바뀌면 지금 속도를 이어
/// 받는다 ("Allow for constant redirection and interruption", WWDC18 803).
///
/// ## 움직임을 줄이라고 한 사람에게는
///
/// HIG Accessibility: *"Replacing transitions in x-, y-, and z-axes with fades"*.
/// 그래서 `reduced` 판은 **자리를 옮기는 것은 즉시**(`instant`), **드러나고
/// 물러나는 것은 짧은 교차 페이드**(`crossFade`)다. 끄지 않고 바꾼다 — 아예
/// 끄면 무엇이 새로 생겼는지 알 길이 사라진다.
enum Motion {

    // MARK: 시간과 곡선 — AppKit 도 같은 값을 본다

    static let quickDuration: TimeInterval = 0.18
    static let settleDuration: TimeInterval = 0.30
    /// 서랍이 펼쳐지는 시간. `DrawerWindowController.duration` 이 이 값이다.
    static let flyDuration: TimeInterval = 0.30
    /// 나가는 힘이 세고 들어와 앉을 때 잦아드는 곡선. `CAMediaTimingFunction` 과 같은 네 점.
    static let flyCurve: (x1: Double, y1: Double, x2: Double, y2: Double) = (0.22, 0.9, 0.24, 1)

    // MARK: 낱말 셋

    static let quick = Animation.smooth(duration: quickDuration)
    static let settle = Animation.smooth(duration: settleDuration)
    static let fly = Animation.timingCurve(
        flyCurve.x1, flyCurve.y1, flyCurve.x2, flyCurve.y2, duration: flyDuration
    )

    // MARK: 움직임을 줄인 사람 몫

    /// 자리를 옮기는 것은 옮기지 않는다 — 한 프레임에 끝낸다.
    static let instant = Animation.linear(duration: 0.01)
    /// 드러나고 물러나는 것은 남긴다. 축 이동 대신 페이드 (HIG Accessibility).
    static let crossFade = Animation.easeInOut(duration: 0.12)

    static func quick(_ reduced: Bool) -> Animation { reduced ? crossFade : quick }
    static func settle(_ reduced: Bool) -> Animation { reduced ? crossFade : settle }
    static func fly(_ reduced: Bool) -> Animation { reduced ? instant : fly }

    /// SwiftUI 밖(창 컨트롤러·`NSAnimationContext`)에서 묻는 자리.
    /// 뷰 안에서는 `@Environment(\.accessibilityReduceMotion)` 이 정본이다 —
    /// 그쪽은 미리보기와 화면 밖 렌더에서도 옳은 값을 준다.
    static var systemReducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 창의 프레임을 움직이는 `NSAnimationContext` 의 곡선. 뷰의 `fly` 와
    /// **같은 네 점**이라야 내용과 창이 한 몸으로 간다.
    static var flyTiming: CAMediaTimingFunction {
        CAMediaTimingFunction(
            controlPoints: Float(flyCurve.x1), Float(flyCurve.y1),
            Float(flyCurve.x2), Float(flyCurve.y2)
        )
    }
}
