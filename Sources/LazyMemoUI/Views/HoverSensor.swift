import AppKit
import SwiftUI

/// 앱이 활성이 아니어도 포인터가 올라온 것을 알려주는 감지기.
///
/// SwiftUI 의 `.onHover` 는 **키 윈도 안에서만** 반응한다. 보통 앱이라면
/// 문제가 없지만 lazymemo 의 메모는 바탕화면에 눕는다 — 사용자가 브라우저를
/// 쓰는 동안에도 종이는 거기 있고, 포인터가 지나가면 되살아나야 한다
/// (철학 3·4). `.onHover` 만 쓰면 그 두 규칙이 실사용에서 통째로 죽는다.
///
/// `.activeAlways` 추적 영역은 앱이 뒤에 있어도 도착한다. `hitTest` 로
/// 자기를 비워 두므로 클릭은 그대로 아래로 지나간다.
struct HoverSensor: View {
    var onChange: (Bool) -> Void
    /// 포인터가 **어디에** 있는지까지 알려준다. 필요할 때만 건다 — 움직임
    /// 이벤트는 `.activeAlways` 라 앱이 뒤에 있어도 계속 도착하므로, 쓰지
    /// 않는 화면에서까지 받을 이유가 없다.
    ///
    /// 좌표는 감지기 자신의 왼쪽 위를 원점으로 하는 값이다 (SwiftUI 와 같은
    /// 방향). 부르는 쪽이 제 좌표계로 옮겨 쓴다.
    var onMove: ((CGPoint) -> Void)? = nil

    /// `ImageRenderer` 는 `NSViewRepresentable` 을 그리지 못하고 뷰 전체를
    /// 금지 표시로 바꿔 버린다. 화면 밖 렌더(`LAZYMEMO_RENDER`)에서는 애초에
    /// 포인터가 없으므로 감지기를 통째로 뺀다.
    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        if !rendersStatically {
            Sensor(onChange: onChange, onMove: onMove)
        }
    }
}

private struct Sensor: NSViewRepresentable {
    var onChange: (Bool) -> Void
    var onMove: ((CGPoint) -> Void)?

    func makeNSView(context: Context) -> NSView {
        SensorView(onChange: onChange, onMove: onMove)
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let sensor = view as? SensorView else { return }
        sensor.onChange = onChange
        // 움직임을 받는지 여부가 바뀌면 추적 영역을 다시 짜야 한다.
        let changed = (sensor.onMove == nil) != (onMove == nil)
        sensor.onMove = onMove
        if changed { sensor.updateTrackingAreas() }
    }

    final class SensorView: NSView {
        var onChange: (Bool) -> Void
        var onMove: ((CGPoint) -> Void)?

        init(onChange: @escaping (Bool) -> Void, onMove: ((CGPoint) -> Void)? = nil) {
            self.onChange = onChange
            self.onMove = onMove
            super.init(frame: .zero)
        }

        /// SwiftUI 와 같은 방향으로 재도록 위를 원점으로 둔다.
        override var isFlipped: Bool { true }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) 는 쓰지 않는다")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            var options: NSTrackingArea.Options = [
                .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
            ]
            if onMove != nil { options.insert(.mouseMoved) }
            addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self))
        }

        override func mouseEntered(with event: NSEvent) {
            onChange(true)
            report(event)
        }

        override func mouseExited(with event: NSEvent) { onChange(false) }

        override func mouseMoved(with event: NSEvent) { report(event) }

        private func report(_ event: NSEvent) {
            guard let onMove else { return }
            onMove(convert(event.locationInWindow, from: nil))
        }

        /// 감지만 한다. 누르기는 아래 있는 것이 받는다.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        /// 창이 치워지면 올라와 있던 상태를 남기지 않는다.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { onChange(false) }
        }
    }
}
