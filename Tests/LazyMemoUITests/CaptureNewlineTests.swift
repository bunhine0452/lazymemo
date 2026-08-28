import AppKit
import LazyMemoCore
import SwiftUI
import Testing
@testable import LazyMemoUI

/// Return 으로 넣은 줄바꿈이 살아남는지 — **진짜 뷰 계층을 세워** 확인한다.
///
/// 사용자가 겪은 결함: 엔터를 치면 줄이 바뀌었다가 되돌아온다. 모델 → 텍스트
/// 뷰 되밀기가 방금 친 글자를 덮는 종류의 버그이고, 순수 함수 테스트로는
/// 안 잡힌다. 그래서 `NSHostingView` 로 실제 상자를 짓고 실제로 타자를 친다.
@MainActor
@Suite("빠른 입력 — 여러 줄 입력")
struct CaptureNewlineTests {
    private func makeModel() throws -> QuickCaptureModel {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-capture-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return QuickCaptureModel(store: try MemoStore(paths: paths))
    }

    private func makeBox(_ model: QuickCaptureModel) -> (NSHostingView<QuickCaptureView>, NSTextView) {
        let hosting = NSHostingView(rootView: QuickCaptureView(
            model: model, onCommit: {}, onCancel: {}
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: QuickCaptureController.width, height: 200)
        hosting.layoutSubtreeIfNeeded()
        return (hosting, hosting.firstTextView!)
    }

    /// SwiftUI 갱신은 다음 런루프에서 온다. 그때까지 돌려 준다.
    private func settle(_ hosting: NSView) {
        for _ in 0..<3 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            hosting.layoutSubtreeIfNeeded()
        }
    }

    @Test("엔터를 치면 줄이 바뀌고, 되돌아오지 않는다")
    func newlineSurvives() throws {
        let model = try makeModel()
        let (hosting, textView) = makeBox(model)

        textView.insertText("치과", replacementRange: NSRange(location: 0, length: 0))
        textView.insertNewline(nil)
        textView.insertText("강남역", replacementRange: textView.selectedRange())
        settle(hosting)

        #expect(textView.string == "치과\n강남역")
        #expect(model.query == "치과\n강남역")
    }

    @Test("줄을 여러 번 바꿔도 그대로 쌓인다")
    func manyNewlinesSurvive() throws {
        let model = try makeModel()
        let (hosting, textView) = makeBox(model)

        for word in ["하나", "둘", "셋"] {
            textView.insertText(word, replacementRange: textView.selectedRange())
            textView.insertNewline(nil)
            settle(hosting)
        }

        #expect(textView.string == "하나\n둘\n셋\n")
        #expect(model.query == "하나\n둘\n셋\n")
    }

    @Test("한 줄만 쳤을 때도 글자가 그대로 남는다")
    func plainTypingSurvives() throws {
        let model = try makeModel()
        let (hosting, textView) = makeBox(model)

        textView.insertText("치과 예약", replacementRange: NSRange(location: 0, length: 0))
        settle(hosting)

        #expect(textView.string == "치과 예약")
        #expect(model.query == "치과 예약")
    }
}
