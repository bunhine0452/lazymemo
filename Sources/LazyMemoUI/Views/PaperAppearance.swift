import LazyMemoCore
import Observation

/// 바탕화면 종이가 얼마나 진한가 — 창 전체가 함께 쓰는 값 하나.
///
/// **설계문서 §14.5 와 정면으로 부딪히는 유일한 설정이다.** 유리를 쓰지 않기로
/// 한 이유는 "반투명한 면 위의 글은 씻겨 나간다" 였고 그 판단은 지금도 옳다.
/// 다만 종이가 바탕화면을 덮는다는 불편은 그것과 다른 종류의 불편이라,
/// 어느 쪽을 견딜지는 화면을 쓰는 사람이 고르는 편이 맞다.
///
/// 그래서 세 가지로 타협했다 — ① 기본은 불투명한 종이 그대로, ② 글이 안
/// 읽히는 값까지는 내려가지 않고, ③ **포인터가 오면 원래대로 진해진다**
/// (철학 3 의 "읽으려는 뜻이 곧 되살리는 신호" 를 그대로 쓴다).
@MainActor
@Observable
final class PaperAppearance {
    struct Step: Sendable, Equatable {
        let label: String
        let opacity: Double
    }

    /// 고를 수 있는 단계.
    ///
    /// 슬라이더를 두지 않는다. 메뉴 안의 슬라이더는 조준해서 끌어야 하는
    /// 물건이고, 이 앱이 가장 피하는 종류의 조작이다. 네 칸이면 "조금 더"
    /// 와 "많이" 사이에서 헤맬 일이 없다.
    static let steps: [Step] = [
        Step(label: L("선명하게"), opacity: 1.0),
        Step(label: L("살짝 비치게"), opacity: 0.85),
        Step(label: L("반쯤 비치게"), opacity: 0.68),
        Step(label: L("많이 비치게"), opacity: 0.5),
    ]

    static let standard: Double = 1.0
    /// 여기까지만 내려간다. 더 내리면 종이가 아니라 얼룩이 된다.
    static let floor: Double = 0.35

    private(set) var opacity: Double
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        self.opacity = Self.clamped(settings.current.paperOpacity)
    }

    /// 지금 고른 단계. 파일을 손으로 고쳐 어중간한 값이 들어와 있으면 `nil`.
    var selected: Step? {
        Self.steps.first { abs($0.opacity - opacity) < 0.001 }
    }

    func set(_ value: Double) {
        let clamped = Self.clamped(value)
        guard clamped != opacity else { return }
        opacity = clamped
        settings.update { $0.paperOpacity = clamped }
    }

    /// 설정 파일은 사용자가 직접 열어 고칠 수 있다 (§5.1). 0 이 들어와도
    /// 메모가 통째로 사라지지는 않아야 한다.
    static func clamped(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return standard }
        return min(max(value, floor), 1.0)
    }
}
