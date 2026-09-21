import AppKit
import Testing
@testable import LazyMemoUI

/// 상자를 언제 치우는가.
///
/// 바탕화면 메모를 고치던 중에 단축키로 상자를 열고 도로 바탕화면을 누르면
/// 상자가 그대로 남았다. 전역 클릭 감시는 **다른 앱으로 가는** 클릭만 보는데,
/// 바탕화면 메모 창은 우리 앱의 것이라 그 감시에 걸리지 않기 때문이다.
@MainActor
@Suite("빠른 입력 바깥 클릭")
struct CaptureDismissTests {
    /// 메뉴바 아이콘 흉내.
    private let icon = NSRect(x: 900, y: 1000, width: 24, height: 22)

    @Test("우리 앱의 다른 창을 눌러도 치운다 — 바탕화면 메모가 그렇다")
    func dismissesOnOurOwnWindow() {
        #expect(QuickCaptureController.dismissesCapture(
            insidePanel: false, at: NSPoint(x: 420, y: 300), anchor: icon
        ))
    }

    @Test("아이콘이 숨겨져 매달 곳이 없어도 바깥 클릭은 치운다")
    func dismissesWithoutAnchor() {
        #expect(QuickCaptureController.dismissesCapture(
            insidePanel: false, at: NSPoint(x: 420, y: 300), anchor: nil
        ))
    }

    @Test("상자 안을 누른 것은 바깥이 아니다")
    func keepsOnInsideClick() {
        #expect(!QuickCaptureController.dismissesCapture(
            insidePanel: true, at: NSPoint(x: 420, y: 300), anchor: icon
        ))
    }

    @Test("메뉴바 아이콘은 스스로 토글한다 — 여기서 먼저 닫으면 깜빡인다")
    func leavesTheIconToItsOwnToggle() {
        #expect(!QuickCaptureController.dismissesCapture(
            insidePanel: false, at: NSPoint(x: icon.midX, y: icon.midY), anchor: icon
        ))
    }

    @Test("답을 기다리거나 들고 있으면 바깥을 눌러도 치우지 않는다 — 다른 앱이든 우리 창이든")
    func keepsWhileHoldingWork() {
        #expect(!QuickCaptureController.dismissesCapture(
            insidePanel: false, at: NSPoint(x: 420, y: 300), anchor: icon, holding: true
        ))
        #expect(!QuickCaptureController.dismissesCapture(
            insidePanel: false, at: NSPoint(x: 420, y: 300), anchor: nil, holding: true
        ))
    }
}
