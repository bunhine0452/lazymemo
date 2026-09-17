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
/// 끌기는 **본문과 같은 길**로 넘긴다 — `mouseDown` 에서 `performDrag`.
/// 앞선 판은 `mouseDownCanMoveWindow` 만 열고 창의 `isMovableByWindowBackground`
/// 에 맡겼는데, 호스팅 뷰 안에서는 그것이 실제로 끌리지 않았다(2026-09-17,
/// 사용자 확인). 우클릭은 그대로다: `mouseDown` 은 왼쪽 버튼만 받고 오른쪽
/// 버튼은 응답자 사슬을 타고 올라 종이의 메뉴가 열린다.
struct PaperGrip: View {
    let tint: Color

    /// 손잡이 한 줄의 키.
    ///
    /// 본문의 위 여백(`Theme.loose`=20)보다 6pt 크다. 그 6pt 는 첫 줄의 **윗머리**다 —
    /// 글줄은 23pt(`Paper.linePitch`)인데 14pt 글자의 제 키는 17pt 라, 남는 6pt 가
    /// 글자 위에 얹힌다. 손잡이가 거기까지 내려와도 글자는 덮지 않고 글도 밀리지
    /// 않는다 (`PaperGripTests` 가 그 경계를 잰다).
    static let height: CGFloat = 26
    /// 색띠의 크기. 손잡이가 커진 만큼 띠도 커야 "여기를 잡는다" 가 보인다.
    static let barSize = CGSize(width: 64, height: 5)

    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        ZStack {
            // `ImageRenderer` 는 `NSViewRepresentable` 을 금지 표시로 그린다 —
            // 화면 밖 렌더에서는 끌 손도 없으니 그림만 남긴다.
            if !rendersStatically { GripSurface() }
            Capsule().fill(tint)
                .frame(width: Self.barSize.width, height: Self.barSize.height)
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
        /// 여기를 잡으면 창이 끌린다 — 배경 끌기가 닿는 창에서는 이것만으로도.
        override var mouseDownCanMoveWindow: Bool { true }
        /// 다른 앱을 쓰다 바로 잡아도 첫 클릭부터 끌린다 (`FirstMouseHostingView` 와 같은 이유).
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// 왼쪽 버튼으로 잡으면 창을 끈다. 본문(`MemoNSTextView.dragPaper`)과 같은 길이다.
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            window.performDrag(with: event)
        }
    }
}
