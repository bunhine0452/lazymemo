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

    @Test("캡슐 폭은 버튼 수에 따라 자란다 — 숫자가 실제 배치와 어긋나지 않게")
    func capsuleWidthAddsUp() {
        let one = NoteControlLayout.capsuleWidth(buttons: 1)
        let two = NoteControlLayout.capsuleWidth(buttons: 2)

        #expect(one == NoteControlLayout.button + NoteControlLayout.capsulePadding * 2)
        #expect(two == one + NoteControlLayout.button + NoteControlLayout.spacing)
    }
}
