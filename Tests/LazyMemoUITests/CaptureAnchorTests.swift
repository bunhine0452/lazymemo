import AppKit
import Testing
@testable import LazyMemoUI

/// 말풍선이 메뉴바 아이콘 밑에 제대로 매달리는지.
///
/// 아이콘이 화면 오른쪽 끝에 있을 때가 함정이다 — 아이콘 한가운데에 상자를
/// 맞추면 상자의 오른쪽 절반이 화면 밖으로 나간다. 그때는 상자를 밀어 넣고
/// **꼬리만** 아이콘을 따라가야 한다.
@MainActor
@Suite("빠른 입력 말풍선 자리")
struct CaptureAnchorTests {
    private func makePanel() -> QuickCapturePanel {
        let panel = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: QuickCaptureController.width, height: 140)
        )
        panel.setContentSize(NSSize(width: QuickCaptureController.width, height: 140))
        return panel
    }

    private var screen: NSRect {
        (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    }

    /// 메뉴바 아이콘 흉내 — 화면 위쪽 끝의 작은 사각형.
    private func icon(atX x: CGFloat) -> NSRect {
        NSRect(x: x, y: screen.maxY, width: 24, height: 22)
    }

    @Test("아이콘 밑에 매달리고 꼬리가 아이콘 한가운데를 가리킨다")
    func hangsUnderTheIcon() {
        let panel = makePanel()
        let anchor = icon(atX: screen.midX)
        let offset = panel.moveToCaptureAnchor(below: anchor)

        #expect(offset != nil)
        #expect(panel.frame.maxY <= anchor.minY)
        // 꼬리는 상자 왼쪽 끝에서 이만큼 떨어진 곳 = 아이콘 한가운데.
        #expect(abs(panel.frame.minX + (offset ?? 0) - anchor.midX) < 1)
    }

    @Test("화면 오른쪽 끝 아이콘에서도 상자가 화면 안에 남는다")
    func staysOnScreenAtTheRightEdge() {
        let panel = makePanel()
        let anchor = icon(atX: screen.maxX - 30)
        let offset = panel.moveToCaptureAnchor(below: anchor)

        #expect(panel.frame.maxX <= screen.maxX)
        #expect(panel.frame.minX >= screen.minX)
        // 상자는 밀렸어도 꼬리는 여전히 아이콘을 가리킨다.
        #expect(abs(panel.frame.minX + (offset ?? 0) - anchor.midX) < 1)
    }

    @Test("화면 왼쪽 끝에서도 마찬가지다")
    func staysOnScreenAtTheLeftEdge() {
        let panel = makePanel()
        let anchor = icon(atX: screen.minX + 10)
        let offset = panel.moveToCaptureAnchor(below: anchor)

        #expect(panel.frame.minX >= screen.minX)
        #expect(abs(panel.frame.minX + (offset ?? 0) - anchor.midX) < 1)
    }

    @Test("매달 곳이 없으면 화면 위쪽으로 물러난다 — 그래도 열리기는 한다")
    func fallsBackWhenTheIconIsHidden() {
        let panel = makePanel()
        let offset = panel.moveToCaptureAnchor(below: nil)

        #expect(offset == nil)   // 꼬리를 그리지 않는다
        #expect(panel.frame.minX >= screen.minX)
        #expect(panel.frame.maxX <= screen.maxX)
    }
}
