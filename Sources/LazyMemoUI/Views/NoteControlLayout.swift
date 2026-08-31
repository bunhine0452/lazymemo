import CoreGraphics

/// 겹쳐 뜨는 조작이 종이의 어디를 차지하는가 (`{#controls-overlap}`).
///
/// 숫자를 뷰 안에 흩어 두면 "첫 줄을 덮지 않는다" 를 아무도 지킬 수 없다 —
/// 버튼 하나만 늘어도 캡슐이 다시 제목 위로 내려앉고, 그 사실은 렌더를 눈으로
/// 보기 전에는 드러나지 않는다. 그래서 한자리에 모으고 시험이 지킨다.
///
/// 왜 지켜야 하는가: 캡슐을 부르는 손짓(포인터 올리기)이 곧 **읽으려는**
/// 손짓이다. 읽으려고 다가가면 읽을 것이 가려지면, 그 조작은 스스로를 문다.
/// 게다가 첫 줄은 이 앱에서 가장 비싼 한 줄이다 — 메뉴 목록도, 빠른 입력도,
/// 달력도 그 줄을 제목으로 쓴다.
enum NoteControlLayout {
    /// 아이콘 버튼 하나 (`QuietButton`).
    static let button: CGFloat = 18
    /// 캡슐 안쪽 여백.
    static let capsulePadding: CGFloat = 3
    /// 버튼 사이.
    static let spacing: CGFloat = 1
    /// 구분선이 차지하는 폭 — 선 1pt 에 양옆 여백.
    static let divider: CGFloat = 1 + Theme.hairline * 2
    /// 치우기(×)가 종이 모서리에서 떨어지는 거리.
    static let closeInset: CGFloat = Theme.hairline
    /// 아래 캡슐이 종이 모서리에서 떨어지는 거리.
    static let paperInset: CGFloat = Theme.tight

    /// 버튼 몇 개짜리 캡슐의 폭.
    static func capsuleWidth(buttons: Int, dividers: Int = 0) -> CGFloat {
        let pieces = buttons + dividers
        let content = CGFloat(buttons) * button
            + CGFloat(dividers) * divider
            + CGFloat(max(pieces - 1, 0)) * spacing
        return content + capsulePadding * 2
    }

    /// 글이 놓이는 폭. 종이에서 좌우 여백(`Theme.loose`)을 뺀 만큼이다.
    static func textWidth(paperWidth: CGFloat, inset: CGFloat = Theme.loose) -> CGFloat {
        max(0, paperWidth - inset * 2)
    }

    /// 오른쪽 위 조작이 **첫 줄의 글에서** 덮는 폭.
    ///
    /// 0 이 되게 만들 수는 없다 — 그러려면 첫 줄에 영구히 홈을 파야 하고,
    /// 그것은 포인터가 올 때만 뜨는 조작이 늘 자리를 차지한다는 뜻이라
    /// 철학 4 를 정면으로 어긴다. 대신 **한 글자보다 좁게** 유지한다.
    static func firstLineCover(
        paperWidth: CGFloat, buttons: Int = 1, inset: CGFloat = Theme.loose
    ) -> CGFloat {
        let capsuleLeft = paperWidth - closeInset - capsuleWidth(buttons: buttons)
        let textRight = paperWidth - inset
        return max(0, textRight - capsuleLeft)
    }
}
