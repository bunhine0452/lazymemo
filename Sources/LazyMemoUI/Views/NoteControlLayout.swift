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
    ///
    /// 그림은 12pt 인데 누르는 자리는 이만큼이다 (`Theme.touch`). 18pt 였을
    /// 때는 넷이 나란히 선 캡슐에서 옆 버튼을 누르는 일이 잦았다 — 지우기
    /// 옆이 색 바꾸기라 그 빗나감의 값이 싸지 않다.
    static let button: CGFloat = Theme.touch
    /// 캡슐 안쪽 여백.
    static let capsulePadding: CGFloat = 3
    /// 버튼 사이.
    ///
    /// **1 이었다.** 과녁을 24pt 로 키워 놓고 그것들을 1pt 로 붙여 두면 키운
    /// 값이 절반이 된다 — 사이에 죽은 자리가 없으니 손이 조금만 흘러도 옆 것이
    /// 눌린다. 게다가 이 캡슐의 둘레는 **글을 적는 면**이라, 빗나간 클릭은
    /// 아무 일도 없는 것이 아니라 **커서가 옮겨 가는 일**이다.
    ///
    /// 예전에는 넓힐 수가 없었다 — 버튼 넷에 간격 1이면 꼬리에 남는 자리가
    /// 112pt 로 날짜 한 줄(약 100pt)에 딱 붙어 있었기 때문이다. 캡슐에서 둘을
    /// 덜어 내면서(`paperButtons`) 그 예산이 열렸다.
    static let spacing: CGFloat = 6

    /// 종이의 캡슐에 서는 버튼 수.
    ///
    /// **다섯이었고, 그때 이미 예산이 깨져 있었다** — 남는 자리가 87pt 라
    /// 날짜 한 줄이 안 들어갔다. 시험은 넷까지만 보고 있어서 조용히 지나갔다.
    ///
    /// 그래서 **색과 고정을 캡슐에서 덜어 냈다.** 둘 다 자주 하는 일이 아니고,
    /// 우클릭이면 macOS 사람이 이미 아는 자리다. 캡슐에는 되돌리기 값이 비싼
    /// 것(지우기)과 자주 쓰는 것(달력·다듬기)만 남는다.
    public static func paperButtons(hasTidy: Bool) -> Int { hasTidy ? 3 : 2 }
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

    /// 꼬리(날짜·태그)가 종이 가장자리에서 떨어지는 거리.
    static let footerInset: CGFloat = Theme.loose + 5

    /// 아래 캡슐이 **꼬리에서** 비워 둬야 하는 폭.
    ///
    /// 첫 줄을 비우려고 조작을 아래로 내렸더니 이번에는 **마지막 줄이 덮였다.**
    /// 거기 있는 것은 날짜와 태그다 — 첫 줄 다음으로 비싼 줄이고, 날짜는
    /// 누르면 달력으로 가는 버튼이기도 하다. 「#병원」의 오른쪽이 캡슐 밑으로
    /// 들어가 있었다.
    ///
    /// 첫 줄과 달리 여기서는 **자리를 미리 비운다.** 본문에 홈을 파는 것은
    /// 적는 면을 좁히는 일이지만, 꼬리의 오른쪽은 원래 거의 비어 있다 —
    /// 비워 두면 태그가 길 때만 잘리고, 잘린 것은 잘린 줄 안다. 가려진 것은
    /// 가려진 줄도 모른다.
    /// 기본값은 **가장 넓은 실제 경우**다 — 다듬기까지 선 셋. 넷을 기본으로
    /// 두었을 때는 그 숫자가 화면 어디에도 없는 값이라, 시험이 재는 예산과
    /// 사람이 보는 캡슐이 서로 다른 것을 말하고 있었다.
    static func footerReserve(
        buttons: Int = paperButtons(hasTidy: true),
        dividers: Int = 1,
        inset: CGFloat = footerInset
    ) -> CGFloat {
        let capsule = capsuleWidth(buttons: buttons, dividers: dividers) + paperInset
        // 캡슐에 딱 붙이지 않는다 — 글자와 캡슐 사이에 한 칸은 있어야 한다.
        return max(0, capsule - inset + Theme.tight)
    }

    /// 캡슐 한 벌의 높이. 버튼 한 변에 위아래 여백.
    static let capsuleHeight: CGFloat = button + capsulePadding * 2
    /// 꼬리 한 줄이 먹는 높이.
    ///
    /// 10pt 글자 한 줄이면 13pt 로 충분하지만, 이 줄에는 **버튼이 둘 있다** —
    /// 날짜(누르면 달력)와 장소(누르면 지도). 글자 높이가 곧 과녁이면 13pt
    /// 짜리 띠를 겨냥해야 하므로 누르는 자리만 위아래로 벌린다
    /// (`NoteView.scheduleMark`).
    static let footerLine: CGFloat = 19

    /// 꼬리가 **두 줄일 때** 종이 바닥에서 떨어지는 거리.
    ///
    /// 캡슐은 오른쪽 아래에 앉아 아랫줄만 덮는데, 아랫줄은 자리를 미리 비워
    /// 두므로(`footerReserve`) 덮일 것이 없다. 문제는 버튼이 `Theme.touch` 로
    /// 커지면서 캡슐도 함께 높아졌다는 것이다 — **덮는 높이가 윗줄까지
    /// 닿았다.** 「#병원」의 아랫동강이 캡슐 밑으로 들어가 있었다.
    ///
    /// 윗줄에도 자리를 비우면 될 것 같지만 그쪽이 더 나쁘다: 윗줄은 날짜가
    /// 사는 줄이라 「8월 31일 오후 2:30 · 30분 전」이 「8월 31일…」로 잘린다.
    /// 잘린 것은 잘린 줄 알지만, 그 잘림은 **자리가 모자라서가 아니라 캡슐이
    /// 아랫줄에 있어서** 생긴 것이라 사람이 이유를 알 수 없다. 그래서 꼬리를
    /// 통째로 캡슐 위로 올린다. 종이가 9pt 좁아지는 값을 치른다.
    static var footerTwoLineInset: CGFloat {
        max(Theme.normal, paperInset + capsuleHeight - footerLine - 2)
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
