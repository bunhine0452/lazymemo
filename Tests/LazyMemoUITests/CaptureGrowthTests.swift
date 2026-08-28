import AppKit
import SwiftUI
import Testing
@testable import LazyMemoUI

/// 빠른 입력 상자가 줄 수에 맞춰 자라는지.
///
/// Return 이 다음 줄로 가게 바꾼 순간부터, 상자가 안 자라면 친 글이 한 줄
/// 창 안으로 숨는다 — 적고 있는 글이 안 보이는 것은 가장 나쁜 종류의 불편이다.
/// 화면 밖 렌더는 SwiftUI 대체 경로라 이 높이를 보여주지 못하므로 여기서 막는다.
@MainActor
@Suite("빠른 입력 — 줄 수에 따라 자란다")
struct CaptureGrowthTests {
    private func makeCoordinator(_ text: String) -> (MemoTextEditor.Coordinator, NSTextView) {
        let font = NSFont.systemFont(ofSize: 19, weight: .light)
        let textView = MemoTextEditor.makeTextView(
            font: font, insets: NSSize(width: 0, height: 4), linePitch: nil
        )
        textView.isVerticallyResizable = false
        textView.frame = NSRect(x: 0, y: 0, width: 380, height: 200)
        textView.textContainer?.containerSize = NSSize(width: 380, height: 400)
        textView.string = text

        let editor = MemoTextEditor(text: .constant(text))
        let coordinator = editor.makeCoordinator()
        coordinator.textView = textView
        return (coordinator, textView)
    }

    private func height(of text: String) -> CGFloat {
        let (coordinator, _) = makeCoordinator(text)
        var reported: CGFloat = 0
        coordinator.onHeightChange = { reported = $0 }
        coordinator.reportHeight()
        return reported
    }

    @Test("한 줄일 때는 한 줄만큼만 차지한다")
    func oneLineStaysSmall() {
        #expect(height(of: "치과") > 0)
        #expect(height(of: "치과") < QuickCaptureView.minimumEditorHeight * 2)
    }

    @Test("줄이 늘면 높이도 늘어난다 — 친 글이 숨지 않는다")
    func growsWithLines() {
        let one = height(of: "치과")
        let three = height(of: "치과\n강남역 3번 출구\n오후 3시")
        #expect(three > one)
        // 두 줄이 늘었으면 대략 두 줄만큼. 자잘한 오차는 허용한다.
        #expect(three - one > one * 1.2)
    }

    @Test("같은 높이면 다시 알리지 않는다 — 갱신이 끝없이 돌면 안 된다")
    func doesNotRepeatTheSameHeight() {
        let (coordinator, _) = makeCoordinator("치과")
        var calls = 0
        coordinator.onHeightChange = { _ in calls += 1 }
        coordinator.reportHeight()
        coordinator.reportHeight()
        coordinator.reportHeight()
        #expect(calls == 1)
    }
}
