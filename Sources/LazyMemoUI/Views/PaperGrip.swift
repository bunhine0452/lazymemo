import AppKit
import SwiftUI

/// 종이 머리의 손잡이 — 색띠가 앉는 자리이자, 종이를 **집어 옮기는** 자리.
///
/// 본문 위에서의 끌기는 텍스트 뷰가 창으로 넘겨주지만(`MemoNSTextView`), 종이
/// 머리에 자리 카드가 서면 그 위는 스크롤 뷰라 배경 끌기가 닿지 않는다 —
/// 남는 것은 색띠 둘레 14pt 였고, 그것은 손잡이가 아니라 틈이다. 그래서
/// 머리 한 줄을 통째로 손잡이로 삼는다. 색띠도 그만큼 키워 "여기를 잡는다"
/// 는 뜻이 보이게 한다.
///
/// 끌기는 AppKit 에 맡긴다: `mouseDownCanMoveWindow` 만 열면 창의
/// `isMovableByWindowBackground` 가 나머지를 한다. 직접 `performDrag` 를
/// 부르지 않는 이유는 우클릭이다 — 창 배경 끌기는 왼쪽 버튼에만 걸리고
/// 오른쪽 버튼은 그대로 응답자 사슬을 타고 올라 종이의 메뉴가 열린다.
struct PaperGrip: View {
    let tint: Color

    /// 손잡이 한 줄의 키. 본문의 위 여백(`Theme.loose`)과 같아 글을 밀지 않는다.
    static let height: CGFloat = Theme.loose

    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        ZStack {
            // `ImageRenderer` 는 `NSViewRepresentable` 을 금지 표시로 그린다 —
            // 화면 밖 렌더에서는 끌 손도 없으니 그림만 남긴다.
            if !rendersStatically { GripSurface() }
            Capsule().fill(tint)
                .frame(width: 52, height: 4)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }
}

private struct GripSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { GripView() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class GripView: NSView {
        /// 여기를 잡으면 창이 끌린다.
        override var mouseDownCanMoveWindow: Bool { true }
        /// 다른 앱을 쓰다 바로 잡아도 첫 클릭부터 끌린다 (`FirstMouseHostingView` 와 같은 이유).
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
