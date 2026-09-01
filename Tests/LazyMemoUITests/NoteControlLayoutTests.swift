import CoreGraphics
import Testing
@testable import LazyMemoUI

/// 겹쳐 뜨는 조작이 첫 줄을 덮지 않는가 (`{#controls-overlap}`).
///
/// 사용자가 겪은 결함: 종이에 포인터를 올리면 조작 캡슐이 **제목 위에** 떴다.
/// 기본 종이는 260pt 이고 글이 놓이는 폭은 220pt 인데 캡슐이 106pt 라,
/// 첫 줄의 절반이 그 밑으로 들어갔다. 읽으려고 다가가면 읽을 것이 가려지는
/// 조작이었다 — 캡슐을 부르는 손짓이 곧 읽으려는 손짓이므로.
///
/// 이 종류는 **렌더를 눈으로 보기 전에는 드러나지 않는다.** 버튼을 하나
/// 더하는 것만으로 조용히 되돌아오므로 숫자를 여기서 지킨다.
@Suite("종이 — 조작이 첫 줄을 덮지 않는다")
struct NoteControlLayoutTests {
    /// 기본 창 크기 (§7 의 260×200). 사람이 새 메모를 만들면 이 크기다.
    private let paper: CGFloat = 260

    @Test("오른쪽 위 조작이 첫 줄에서 덮는 폭은 한 글자보다 좁다")
    func closeButtonBarelyTouchesTheFirstLine() {
        let cover = NoteControlLayout.firstLineCover(paperWidth: paper)

        // 본문 글자는 14pt (`Paper.bodySize`). 그보다 좁으면 마지막 글자 하나가
        // 통째로 가려지는 일은 없다.
        #expect(cover < Paper.bodySize)
        #expect(cover > 0)   // 0 이면 첫 줄에 영구히 홈을 판 것이다 — 그쪽이 아니다.
    }

    @Test("다섯을 한 줄에 담으면 첫 줄의 절반이 덮인다 — 나눠 놓은 까닭")
    func fiveInOneRowWouldSwallowTheTitle() {
        // 옛 배치: 휴지통·구분선·색·고정·달력·× 가 한 캡슐에 있었다.
        let old = NoteControlLayout.capsuleWidth(buttons: 5, dividers: 1)
        let text = NoteControlLayout.textWidth(paperWidth: paper)

        #expect(old > text * 0.4)
        // 지금은 하나만 남아 그 넷보다 훨씬 좁다.
        #expect(NoteControlLayout.capsuleWidth(buttons: 1) < old / 3)
    }

    @Test("작은 종이일수록 덮는 비율이 커지므로, 가장 작은 창에서도 한 글자를 넘지 않는다")
    func holdsOnTheSmallestPaper() {
        // 사용자가 줄일 수 있는 만큼 줄인 종이. 여기서 무너지면 규칙이 아니다.
        for width in [160.0, 200.0, 260.0, 400.0] {
            #expect(NoteControlLayout.firstLineCover(paperWidth: width) < Paper.bodySize)
        }
    }

    /// 첫 줄을 비우려고 조작을 아래로 내렸더니 이번에는 **마지막 줄이 덮였다.**
    /// 거기 있는 것은 날짜와 태그이고, 날짜는 누르면 달력으로 가는 버튼이기도 하다.
    @Test("아래 조작이 꼬리의 날짜와 태그를 덮지 않는다")
    func bottomControlsClearTheFooter() {
        // **같은 버튼 수로 재야 한다.** 캡슐은 4개로, 비우는 폭은 기본값으로
        // 재고 있었는데 그 둘이 어긋나면서 이 시험이 재던 것이 «덮이는가» 가
        // 아니라 «두 숫자가 우연히 맞는가» 가 되어 있었다.
        for hasTidy in [false, true] {
            let buttons = NoteControlLayout.paperButtons(hasTidy: hasTidy)
            for width in [160.0, 200.0, 260.0, 400.0] {
                let capsuleLeft = width - NoteControlLayout.paperInset
                    - NoteControlLayout.capsuleWidth(buttons: buttons, dividers: 1)
                let footerRight = width - NoteControlLayout.footerInset
                    - NoteControlLayout.footerReserve(buttons: buttons)

                #expect(footerRight <= capsuleLeft)
            }
        }
    }

    @Test("비워 두고도 날짜 한 줄은 들어간다 — 비우기가 꼬리를 없애면 안 된다")
    func footerStillHasRoomForADate() {
        // **실제로 서는 경우만 잰다.** 예전에는 기본값 4를 쟀는데 그 숫자는
        // 화면 어디에도 없었고, 그래서 다듬기까지 다섯이 섰을 때 예산이
        // 깨진 것을 아무도 몰랐다 (그때 남는 자리가 87pt 였다).
        for hasTidy in [false, true] {
            let room = paper - NoteControlLayout.footerInset * 2
                - NoteControlLayout.footerReserve(
                    buttons: NoteControlLayout.paperButtons(hasTidy: hasTidy)
                )
            // 「8월 31일 오후 2:30」 은 10pt 로 100pt 남짓이다.
            #expect(room > 110)
        }
    }

    /// 과녁을 키우는 것만으로는 모자란다 — **사이에 죽은 자리가 있어야** 한다.
    ///
    /// 24pt 짜리 둘이 0pt 로 붙어 있으면 경계에서 어느 쪽이 눌릴지 손이 알 수
    /// 없고, 이 캡슐의 둘레는 글을 적는 면이라 빗나감의 값도 비싸다.
    @Test("버튼 사이에 죽은 자리가 있다")
    func buttonsAreNotFlush() {
        #expect(NoteControlLayout.spacing >= 4)
        #expect(NoteControlLayout.button >= Theme.touch)
    }

    @Test("캡슐에 서는 것은 값이 비싸거나 자주 쓰는 것뿐이다")
    func capsuleStaysSmall() {
        // 색·고정은 우클릭으로 갔다. 다섯이 서면 예산이 깨진다.
        #expect(NoteControlLayout.paperButtons(hasTidy: false) == 2)
        #expect(NoteControlLayout.paperButtons(hasTidy: true) == 3)
    }

    /// 캡슐이 높아지면 **덮는 것이 아랫줄에서 윗줄로 번진다.** 아랫줄은
    /// 자리를 비워 두므로 안전한데(`footerReserve`), 윗줄에는 날짜가 살아서
    /// 비울 수가 없다 — 비우면 「8월 31일…」로 잘린다. 그래서 꼬리 전체를
    /// 캡슐 위로 올렸고, 그 높이가 맞는지는 그림이 아니라 여기서 지킨다.
    @Test("꼬리가 두 줄이면 윗줄이 캡슐 위로 올라선다")
    func twoLineFooterClearsTheCapsule() {
        let capsuleTop = NoteControlLayout.paperInset + NoteControlLayout.capsuleHeight
        // 윗줄의 아래쪽 = 바닥 여백 + 아랫줄 한 줄 + 줄 사이(2pt).
        let upperLineBottom = NoteControlLayout.footerTwoLineInset
            + NoteControlLayout.footerLine + 2

        #expect(upperLineBottom >= capsuleTop)
        // 한 줄짜리 꼬리보다 위로 올라가되, 종이를 통째로 먹지는 않는다.
        #expect(NoteControlLayout.footerTwoLineInset >= Theme.normal)
        #expect(NoteControlLayout.footerTwoLineInset < Theme.normal * 2)
    }

    @Test("버튼이 늘면 비워 두는 폭도 따라 는다")
    func reserveFollowsTheCapsule() {
        #expect(NoteControlLayout.footerReserve(buttons: 5, dividers: 1)
            > NoteControlLayout.footerReserve(buttons: 4, dividers: 1))
    }

    @Test("캡슐 폭은 버튼 수에 따라 자란다 — 숫자가 실제 배치와 어긋나지 않게")
    func capsuleWidthAddsUp() {
        let one = NoteControlLayout.capsuleWidth(buttons: 1)
        let two = NoteControlLayout.capsuleWidth(buttons: 2)

        #expect(one == NoteControlLayout.button + NoteControlLayout.capsulePadding * 2)
        #expect(two == one + NoteControlLayout.button + NoteControlLayout.spacing)
    }
}

/// 「다듬기」가 붙으면 버튼이 다섯이 된다 (`{#claude-tidy-action}`).
///
/// 이 파일이 처음부터 경고하던 그 어긋남이다 — 버튼 하나만 늘어도 캡슐이
/// 넓어지고, 꼬리가 비워 둔 폭이 그대로면 날짜와 태그가 캡슐 밑으로 들어간다.
@Suite("다듬기가 붙은 조작 줄")
struct TidyControlLayoutTests {
    @Test("버튼이 늘면 캡슐도 넓어진다")
    func capsuleGrows() {
        let four = NoteControlLayout.capsuleWidth(buttons: 4, dividers: 1)
        let five = NoteControlLayout.capsuleWidth(buttons: 5, dividers: 1)
        #expect(five > four)
        #expect(five - four == NoteControlLayout.button + NoteControlLayout.spacing)
    }

    @Test("꼬리가 비우는 폭도 그만큼 넓어진다 — 이것이 어긋나면 날짜가 캡슐 밑으로 들어간다")
    func footerReserveFollows() {
        let four = NoteControlLayout.footerReserve(buttons: 4, dividers: 1)
        let five = NoteControlLayout.footerReserve(buttons: 5, dividers: 1)
        #expect(five - four == NoteControlLayout.button + NoteControlLayout.spacing)
        #expect(four > 0)
    }
}
