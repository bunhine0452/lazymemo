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

    /// `ImageRenderer` 는 `NSViewRepresentable` 을 그리지 못하고 뷰 전체를
    /// 금지 표시로 바꿔 버린다. 화면 밖 렌더(`LAZYMEMO_RENDER`)에서는 애초에
    /// 포인터가 없으므로 감지기를 통째로 뺀다.
    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        if !rendersStatically {
            Sensor(onChange: onChange)
        }
    }
}

private struct Sensor: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        SensorView(onChange: onChange)
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? SensorView)?.onChange = onChange
    }

    final class SensorView: NSView {
        var onChange: (Bool) -> Void

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) 는 쓰지 않는다")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            ))
        }

        override func mouseEntered(with event: NSEvent) { onChange(true) }
        override func mouseExited(with event: NSEvent) { onChange(false) }

        /// 감지만 한다. 누르기는 아래 있는 것이 받는다.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        /// 창이 치워지면 올라와 있던 상태를 남기지 않는다.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { onChange(false) }
        }
    }
}
