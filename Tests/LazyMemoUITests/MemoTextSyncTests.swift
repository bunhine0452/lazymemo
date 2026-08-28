import AppKit
import Testing
@testable import LazyMemoUI

/// 한글 IME 조합 회귀 테스트 (`{#ime-check}` `{#ime-regression}`).
///
/// 조합 중인 글자는 아직 `string` 에 확정되지 않은 임시 상태다. 그 상태에서
/// 상위 뷰가 문자열을 되밀면 자모가 흩어진다 — 사람이 타자를 쳐야만 드러나는
/// 버그라서, `setMarkedText` 로 조합 상태를 만들어 자동으로 지킨다.
@MainActor
@Suite("MemoTextSync — 한글 IME")
struct MemoTextSyncTests {
    private func makeTextView(_ initial: String = "") -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        textView.string = initial
        return textView
    }

    /// "한" 을 치는 도중 — ㅎ 다음 ㅏ 를 누른 조합 중간 상태.
    private func startComposing(_ textView: NSTextView, marked: String) {
        textView.setMarkedText(
            marked,
            selectedRange: NSRange(location: marked.count, length: 0),
            replacementRange: NSRange(location: (textView.string as NSString).length, length: 0)
        )
    }

    @Test("조합 중에는 텍스트를 되밀지 않는다")
    func doesNotClobberComposition() {
        let textView = makeTextView("치과 ")
        startComposing(textView, marked: "예")

        #expect(textView.hasMarkedText(), "setMarkedText 후 조합 상태여야 한다")

        let applied = MemoTextSync.apply("전혀 다른 내용", to: textView)

        #expect(applied == false)
        #expect(textView.hasMarkedText(), "조합이 유지되어야 한다")
        #expect(textView.string.hasPrefix("치과 "))
    }

    @Test("조합이 끝나면 되민다")
    func appliesAfterCompositionEnds() {
        let textView = makeTextView("치과 ")
        startComposing(textView, marked: "예")
        textView.unmarkText()

        #expect(!textView.hasMarkedText())
        #expect(MemoTextSync.apply("치과 예약", to: textView))
        #expect(textView.string == "치과 예약")
    }

    @Test("내용이 같으면 건드리지 않는다 — 대입만으로 선택이 초기화된다")
    func skipsIdenticalText() {
        let textView = makeTextView("같은 내용")
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        #expect(MemoTextSync.apply("같은 내용", to: textView) == false)
        #expect(textView.selectedRange().location == 2)
    }

    @Test("되밀 때 커서가 문서 끝으로 튀지 않는다")
    func keepsCaretPosition() {
        let textView = makeTextView("안녕하세요")
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        MemoTextSync.apply("안녕하십니까", to: textView)

        #expect(textView.selectedRange().location == 2)
    }

    @Test("새 텍스트가 짧아지면 커서를 끝으로 당긴다")
    func clampsCaretToShorterText() {
        let textView = makeTextView("긴 문장을 적었다")
        textView.setSelectedRange(NSRange(location: 8, length: 0))

        MemoTextSync.apply("짧다", to: textView)

        #expect(textView.selectedRange().location == 2)
    }

    @Test("한글 자모 조합이 여러 번 이어져도 깨지지 않는다")
    func survivesRepeatedComposition() {
        let textView = makeTextView("")

        for (marked, committed) in [("ㅊ", "치"), ("ㄱ", "과")] {
            startComposing(textView, marked: marked)
            // 조합 중 외부 변경(파일 감시 등)이 들어와도 무시되어야 한다
            #expect(MemoTextSync.apply("외부에서 바뀐 내용", to: textView) == false)
            textView.insertText(committed, replacementRange: textView.markedRange())
        }

        #expect(textView.string == "치과")
    }
}
