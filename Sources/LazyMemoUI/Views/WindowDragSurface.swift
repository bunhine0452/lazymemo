import AppKit
import SwiftUI

/// 잡으면 창이 끌리고, 안 끌고 놓으면 누른 것이 되는 자리.
///
/// 호스팅 뷰 안에서는 창의 `isMovableByWindowBackground` 가 **실제로 끌리지 않는다**
/// (2026-09-17, 종이의 손잡이에서 확인 — `PaperGrip`). SwiftUI 의 `Button` 이 판 전체를
/// 덮은 서랍 탭은 그래서 잡을 데가 한 군데도 없었다. 종이의 본문과 같은 길로 간다 —
/// `mouseDown` 에서 `performDrag`, 끝난 뒤 창이 움직였는지로 «끌기였나 누르기였나» 를
/// 가른다 (`MemoNSTextView.dragPaper`).
///
/// 오른쪽 버튼은 받지 않는다 — `menu` 를 주면 그 메뉴가 열리고, 없으면 응답자 사슬을 탄다.
struct WindowDragSurface: NSViewRepresentable {
    /// 안 끌고 놓았을 때. 없으면 잡는 것만 한다.
    var onClick: (() -> Void)? = nil
    /// 오른쪽 버튼의 메뉴. 매번 새로 짓는다 — 항목의 낱말이 상태를 따른다.
    var menu: (() -> NSMenu?)? = nil

    /// 이만큼 못 움직였으면 누른 것이다. 손이 떨린 만큼은 되돌린다.
    static let dragThreshold: CGFloat = 3

    /// 끌기였나 누르기였나 — 창이 움직인 거리로 가른다. 시험이 직접 묻는다 (§14.9).
    static func isClick(moved: CGFloat) -> Bool { moved < dragThreshold }

    func makeNSView(context: Context) -> NSView {
        let view = Surface()
        view.onClick = onClick
        view.menuProvider = menu
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let view = view as? Surface else { return }
        view.onClick = onClick
        view.menuProvider = menu
    }

    final class Surface: NSView {
        var onClick: (() -> Void)?
        var menuProvider: (() -> NSMenu?)?

        override var mouseDownCanMoveWindow: Bool { true }
        /// 다른 앱을 쓰다 바로 잡아도 첫 클릭부터 (`FirstMouseHostingView` 와 같은 이유).
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let before = window.frame.origin
            window.performDrag(with: event)
            let after = window.frame.origin
            let moved = hypot(after.x - before.x, after.y - before.y)
            guard WindowDragSurface.isClick(moved: moved) else { return }
            if moved > 0 { window.setFrameOrigin(before) }
            onClick?()
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            menuProvider?() ?? super.menu(for: event)
        }
    }
}
