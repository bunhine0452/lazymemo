import Foundation

/// 위젯 셋의 이름표 — 확장이 등록하는 `kind` 와 앱이 다시 그리라고 부를 때의 `kind` 가
/// 같은 문자열이어야 한다. 한 곳에 둔다.
public enum WidgetKind: String, CaseIterable, Sendable {
    /// 「지금」 — 앱의 띠 그대로 (`Recall.nowCards`).
    case now
    /// 다음 약속 — 시각과, 길이 적혀 있으면 출발 시각.
    case next
    /// 적기 — 누르면 펜이 올라온다.
    case write
    /// 달력 — 이번 달 격자. 일정이 있는 날은 점.
    case calendar

    /// WidgetKit 에 넘기는 식별자. 번들 id 를 앞에 붙여 다른 앱의 위젯과 겹치지 않게.
    public var identifier: String { "io.github.bunhine0452.lazymemo.widgets." + rawValue }

    public static var identifiers: [String] { allCases.map(\.identifier) }
}
