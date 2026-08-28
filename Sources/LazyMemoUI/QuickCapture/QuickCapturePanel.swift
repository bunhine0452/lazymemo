import AppKit

/// 빠른 입력이 뜨는 창.
///
/// `NSPopover` 를 버렸다. 메뉴바 아이콘에 매달면 위치가 아이콘이 어디 있느냐에
/// 따라 흔들리고, 메뉴바가 붐벼 아이콘이 숨겨지면 엉뚱한 자리에 뜬다.
/// 게다가 주 경로는 단축키(§8)이고, 그때 사용자의 시선은 메뉴바가 아니라
/// 화면 한가운데 있다.
///
/// 그래서 **위치를 우리가 정한다** — 마우스가 있는 화면의 위쪽 3분의 1.
/// Spotlight 가 나타나는 자리이고, 사람들이 이미 훈련된 곳이다.
final class QuickCapturePanel: NSPanel {
    /// 화면 높이의 이 지점에 창의 위쪽이 온다. 정중앙은 너무 낮게 느껴진다.
    private static let verticalAnchor: CGFloat = 0.72

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = true
        animationBehavior = .none

        isFloatingPanel = true

        // 모든 Space 에서 같은 단축키가 같은 자리에 떠야 한다.
        // `.transient` 는 넣지 않는다 — Space 를 옮기거나 Mission Control 을
        // 켤 때 창이 사라져 버린다.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// borderless 창은 기본적으로 키가 못 된다. 글을 받아야 하므로 연다.
    override var canBecomeKey: Bool { true }

    // 포커스를 잃을 때 곧바로 닫지 않는다.
    //
    // `resignKey` 에서 `orderOut` 하면 **메뉴바 아이콘 클릭으로는 창이 뜨지
    // 않는다.** 클릭이 끝나면서 상태바 창이 키를 되가져가고, 그 순간 우리 창이
    // 자기를 닫아 버리기 때문이다. 사용자가 "클릭해도 안 뜬다" 고 겪은 것이 이것이다.
    //
    // 대신 앱이 비활성화되면 숨는다 (`hidesOnDeactivate`). 다른 앱으로 넘어가면
    // 사라지고, 우리 앱 안에서 포커스가 옮겨 다니는 동안에는 살아 있다.

    /// 마우스가 있는 화면의 위쪽에 가로 중앙으로 놓는다.
    func moveToCaptureAnchor() {
        let screen = Self.activeScreen()
        let visible = screen.visibleFrame
        let size = frame.size

        setFrameOrigin(NSPoint(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.minY + visible.height * Self.verticalAnchor - size.height).rounded()
        ))
    }

    /// 디스플레이가 여럿이면 지금 보고 있는 화면에 떠야 한다.
    private static func activeScreen() -> NSScreen {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
