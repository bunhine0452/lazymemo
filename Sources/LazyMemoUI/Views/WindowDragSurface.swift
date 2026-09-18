import AppKit
import SwiftUI

/// 잡으면 창이 끌리고, 안 끌고 놓으면 누른 것이 되는 자리.
///
/// 호스팅 뷰 안에서는 창의 `isMovableByWindowBackground` 가 **실제로 끌리지 않는다**
/// (2026-09-17, 종이의 손잡이에서 확인 — `PaperGrip`). SwiftUI 의 `Button` 이 판 전체를
/// 덮은 서랍 탭은 그래서 잡을 데가 한 군데도 없었다. 종이의 본문과 같은 길로 간다 —
/// `performDrag` 로 창 서버에 끌기를 맡긴다.
///
/// **끌기였나 누르기였나는 손이 움직인 거리로 가른다 — 창이 움직인 거리가 아니라.**
/// `performDrag` 는 **곧바로 돌아온다**(창 서버가 비동기로 끈다). 앞선 판은 돌아온 뒤
/// 창이 움직였는지를 봤는데, 그 시점의 창은 늘 0pt 움직였으니 **잡기만 해도 누른 것**이
/// 되었다 — 서랍이 펼쳐지고, 펼치는 애니메이션이 창 서버의 끌기를 잘랐다 (2026-09-18,
/// 합성 마우스로 재현: 120pt 끌었는데 24pt 가고 펼쳐졌다). 지금은 `mouseDown` 에서 잡은
/// 자리를 적고, `mouseDragged` 가 문턱을 넘으면 그때 창 서버에 넘기며, 넘기지 않은 채
/// `mouseUp` 이 오면 누른 것이다.
///
/// 오른쪽 버튼은 받지 않는다 — `menu` 를 주면 그 메뉴가 열리고, 없으면 응답자 사슬을 탄다.
struct WindowDragSurface: NSViewRepresentable {
    /// 안 끌고 놓았을 때. 없으면 잡는 것만 한다.
    var onClick: (() -> Void)? = nil
    /// 오른쪽 버튼의 메뉴. 매번 새로 짓는다 — 항목의 낱말이 상태를 따른다.
    var menu: (() -> NSMenu?)? = nil

    /// 이만큼 못 움직였으면 누른 것이다. 손이 떨린 만큼은 끌기가 아니다.
    static let dragThreshold: CGFloat = 3

    /// 끌기였나 누르기였나 — 손이 움직인 거리로 가른다. 시험이 직접 묻는다 (§14.9).
    static func isClick(moved: CGFloat) -> Bool { moved < dragThreshold }

    /// 한 번의 누름이 끌기가 되는지 누르기가 되는지 — 이벤트 없이 셈만 (§14.9, `WindowDragSurfaceTests`).
    struct Press: Equatable {
        let origin: CGPoint
        private(set) var dragging = false

        init(at origin: CGPoint) { self.origin = origin }

        /// 손이 여기까지 왔다. **처음** 문턱을 넘는 순간에만 `true` — 그때 창 서버에 넘긴다.
        mutating func moved(to point: CGPoint) -> Bool {
            guard !dragging else { return false }
            let distance = hypot(point.x - origin.x, point.y - origin.y)
            guard !WindowDragSurface.isClick(moved: distance) else { return false }
            dragging = true
            return true
        }

        /// 손을 뗐다. 끌기로 넘어가지 않았으면 누른 것이다.
        var isClick: Bool { !dragging }
    }

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

        /// 잡은 순간의 이벤트. 없으면 잡고 있지 않다. 창 서버에는 **이것**을 넘긴다 —
        /// 문턱을 넘긴 `mouseDragged` 를 넘기면 창이 그 자리부터 따라와 첫 걸음(문턱만큼)이
        /// 빠진다 (합성 마우스 120pt 에 108pt).
        private var pressed: NSEvent?
        /// 이번 누름의 셈. 창 서버에 넘긴 뒤의 `mouseUp` 은 누른 것이 아니다 —
        /// 창 서버가 끄는 동안은 오지 않을 수도 있다.
        private var press: Press?

        /// 배경 끌기(`isMovableByWindowBackground`)에 맡기지 않는다 — 언제 끌기가 되는지를
        /// 이 뷰가 정해야 누르기와 가를 수 있다.
        override var mouseDownCanMoveWindow: Bool { false }
        /// 다른 앱을 쓰다 바로 잡아도 첫 클릭부터 (`FirstMouseHostingView` 와 같은 이유).
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            pressed = event
            press = Press(at: event.locationInWindow)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let pressed, let window, press?.moved(to: event.locationInWindow) == true else { return }
            window.performDrag(with: pressed)
        }

        override func mouseUp(with event: NSEvent) {
            defer { pressed = nil; press = nil }
            guard press?.isClick == true else { return }
            onClick?()
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            menuProvider?() ?? super.menu(for: event)
        }
    }
}
