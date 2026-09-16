import AppKit
import Foundation
import LazyMemoCore
import SwiftUI
import Testing
@testable import LazyMemoUI

/// 종이 머리의 손잡이 (설계문서 §7.1 여섯째 규칙).
///
/// 자리 카드가 서면 종이 머리는 스크롤 뷰라 배경 끌기가 닿지 않는다 —
/// 머리 한 줄이 `mouseDownCanMoveWindow` 뷰여야 잡을 곳이 남는다. 실제 끌기는
/// 화면이 있어야 하지만, **창이 그 자리에서 누구를 맞히는지**는 여기서 잰다.
@MainActor
@Suite("종이 머리의 손잡이")
struct PaperGripTests {
    @Test("머리 한 줄을 누르면 창을 끄는 뷰가 맞는다 — 그 바로 아래는 본문이다")
    func gripRowMovesWindow() throws {
        let hosting = try makeHosting()
        let width = hosting.bounds.width, height = hosting.bounds.height

        // 색띠 한가운데와 손잡이 줄 끝자락 — AppKit 좌표라 위가 큰 y 다.
        for y in [height - 4, height - PaperGrip.height + 1] {
            let hit = hosting.hitTest(CGPoint(x: width / 2, y: y))
            #expect(hit?.mouseDownCanMoveWindow == true, Comment(rawValue: "y=\(y) 에서 \(String(describing: hit))"))
        }
        // 손잡이 줄 바로 아래는 본문 텍스트 뷰 — 끌기는 그쪽이 스스로 넘긴다.
        let below = hosting.hitTest(CGPoint(x: width / 2, y: height - PaperGrip.height - 2))
        #expect(below is MemoNSTextView, Comment(rawValue: String(describing: below)))
    }

    @Test("손잡이는 첫 클릭부터 받는다 — 다른 앱을 쓰다 바로 잡아도 끌린다")
    func gripAcceptsFirstMouse() throws {
        let hosting = try makeHosting()
        let hit = hosting.hitTest(CGPoint(x: hosting.bounds.midX, y: hosting.bounds.height - 4))
        #expect(hit?.acceptsFirstMouse(for: nil) == true)
    }

    private func makeHosting() throws -> NSView {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-grip-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let previews = LinkPreviewStore(
            cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
            settings: settings
        )
        let model = NoteModel(memo: Memo(body: "치과 예약"), store: store, previews: previews)
        let hosting = FirstMouseHostingView(rootView: NoteView(model: model, onClose: {}))
        hosting.sizingOptions = []
        // 창에 붙여야 `NSViewRepresentable` 이 실제 뷰를 만든다.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 200),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = hosting
        hosting.frame = NSRect(x: 0, y: 0, width: 260, height: 200)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }
}
