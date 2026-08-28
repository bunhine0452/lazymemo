import AppKit
import LazyMemoCore
import SwiftUI

/// 메모 한 장에 대응하는 창 (D2).
@MainActor
final class NoteWindowController: NSObject, NSWindowDelegate {
    let id: ULID
    let model: NoteModel

    private let window: DesktopLevelWindow
    private let onFrameChange: (ULID, CGRect) -> Void
    private let onCloseRequest: (ULID) -> Void

    init(
        memo: Memo,
        store: MemoStore,
        frame: CGRect,
        onFrameChange: @escaping (ULID, CGRect) -> Void,
        onCloseRequest: @escaping (ULID) -> Void
    ) {
        self.id = memo.id
        self.model = NoteModel(memo: memo, store: store)
        self.window = DesktopLevelWindow(contentRect: frame)
        self.onFrameChange = onFrameChange
        self.onCloseRequest = onCloseRequest
        super.init()

        let hosting = NSHostingView(rootView: NoteView(model: model, onClose: { [id] in
            onCloseRequest(id)
        }))
        // 창 크기는 layout.json 이 정본이다. 뷰가 끌고 가게 두지 않는다.
        hosting.sizingOptions = []

        window.contentView = hosting
        window.setFrame(frame, display: false)
        window.delegate = self
    }

    var frame: CGRect { window.frame }

    func show(activating: Bool = false) {
        window.orderFront(nil)
        if activating {
            NSApp.activate()
            window.makeKey()
        }
    }

    func hide() {
        window.orderOut(nil)
    }

    /// 파일이 밖에서 바뀌었을 때 창 내용을 맞춘다.
    func adopt(_ memo: Memo) {
        model.adopt(memo)
    }

    /// 창을 없애기 전에 반드시 부른다 — 저장 버튼이 없으므로 여기가 마지막 기회다.
    func teardown() async {
        await model.flush()
        window.delegate = nil
        window.orderOut(nil)
    }

    func focusEditor() {
        show(activating: true)
        // 텍스트 뷰가 호스팅 뷰 아래 어딘가에 있다. 첫 responder 로 만들어
        // 단축키 한 번으로 바로 타자가 시작되게 한다 (§8).
        if let textView = window.contentView?.firstTextView {
            window.makeFirstResponder(textView)
        }
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        onFrameChange(id, window.frame)
    }

    func windowDidResize(_ notification: Notification) {
        onFrameChange(id, window.frame)
    }
}
