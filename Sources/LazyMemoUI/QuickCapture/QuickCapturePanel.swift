import AppKit

/// 빠른 입력이 뜨는 창.
///
/// `NSPopover` 는 쓰지 않는다 — 시스템 팝오버의 흰 배경과 화살표는 종이 위에
/// 얹히면 두 겹으로 보인다. 대신 우리가 그린 종이 말풍선을 **직접 아이콘 밑에
/// 붙인다.** 단축키로 열든 아이콘을 누르든 같은 자리에서 열려야, 사람이
/// "이 앱이 어디 있는지" 를 한 번만 배운다.
///
/// 아이콘이 가려져 자리를 알 수 없을 때(메뉴바가 붐빌 때)만 화면 위쪽으로
/// 물러난다 — 그때도 열리기는 해야 하기 때문이다.
final class QuickCapturePanel: NSPanel {
    /// 매달 곳이 없을 때 쓰는 자리. 화면 높이의 이 지점에 창의 위쪽이 온다.
    private static let verticalAnchor: CGFloat = 0.72
    /// 아이콘과 말풍선 사이의 숨.
    private static let anchorGap: CGFloat = 2
    /// 화면 가장자리에 붙지 않게 남기는 여백.
    private static let screenMargin: CGFloat = 8

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // `.nonactivatingPanel` — 앱을 앞으로 끌어내지 않고도 키 입력을
            // 받는다. 상주 앱이 다른 앱 위에 상자를 띄우는 유일하게 확실한 길이다.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        isFloatingPanel = true

        // **끄는 것이 핵심이고, 순서까지 중요하다.**
        //
        // 켜 두면 앱이 활성이 아닌 동안 AppKit 이 이 창을 화면에서 내린다.
        // 그런데 `NSApp.activate()` 는 비동기라, 단축키를 누른 순간 앱은 아직
        // 비활성이고 우리가 올린 창이 그대로 숨겨진다 — **"다른 프로그램 창이
        // 떠 있으면 눌러도 안 보인다" 가 이것이었다.**
        //
        // 그리고 `isFloatingPanel` 의 설정자가 `hidesOnDeactivate` 를 도로
        // 켠다. 그래서 반드시 **그 뒤에** 꺼야 한다. 처음 고칠 때 앞에 두었다가
        // 한 줄 뒤에서 되돌려지는 것을 검증 스크립트로 잡았다.
        hidesOnDeactivate = false

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
    // 치우는 일은 컨트롤러가 맡는다 — 앱이 비활성화될 때, 그리고 상자 바깥을
    // 눌렀을 때. 앱이 끝내 활성화되지 못하는 경우까지 덮으려면 둘 다 필요하다.

    /// 메뉴바 아이콘 밑에 매단다. **크기와 자리를 한 번에 정한다.**
    ///
    /// 크기를 먼저 바꾸고 자리를 옮기면 안 된다 — `setContentSize` 는 창의
    /// 왼쪽 **아래** 모서리를 붙잡으므로, 상자가 커지는 순간 위쪽으로 자라
    /// 메뉴바를 파고들었다가 되돌아온다. 사람 눈에는 상자가 위로 튀어 오르며
    /// 윗줄이 잘리는 것으로 보인다. 한 번의 `setFrame` 이면 그 중간 상태가
    /// 아예 존재하지 않는다.
    ///
    /// - Parameters:
    ///   - anchor: 아이콘의 화면 좌표. `nil` 이면 매달 곳이 없다.
    ///   - contentHeight: 내용이 요구하는 높이. `nil` 이면 지금 크기를 지킨다.
    /// - Returns: 말풍선 왼쪽 끝에서 꼬리까지의 거리. 매달지 못했으면 `nil`.
    @discardableResult
    func moveToCaptureAnchor(below anchor: NSRect?, contentHeight: CGFloat? = nil) -> CGFloat? {
        let size = frameSize(forContentHeight: contentHeight)

        guard let anchor, anchor.width > 0 else {
            moveToFallbackAnchor(size: size)
            return nil
        }

        let screen = Self.screen(containing: anchor) ?? Self.activeScreen()
        let visible = screen.visibleFrame

        // 아이콘 한가운데에 맞추되 화면 밖으로 나가지 않게 민다. 가장자리
        // 아이콘에서도 상자 전체가 보여야 하므로 꼬리만 아이콘을 따라간다.
        let ideal = anchor.midX - size.width / 2
        let x = min(
            max(ideal, visible.minX + Self.screenMargin),
            visible.maxX - size.width - Self.screenMargin
        ).rounded()
        // 아이콘 자리가 이상하게 잡혀도(메뉴바가 숨은 전체화면 등) 상자는
        // 화면 안에 남아야 한다. 안 보이는 것보다 어긋난 자리가 낫다.
        let y = min(
            max(anchor.minY - size.height - Self.anchorGap, visible.minY + Self.screenMargin),
            visible.maxY - size.height
        ).rounded()

        setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
        return (anchor.midX - x).rounded()
    }

    /// 아이콘을 못 찾았을 때 — 마우스가 있는 화면의 위쪽에 가로 중앙으로.
    private func moveToFallbackAnchor(size: NSSize) {
        let screen = Self.activeScreen()
        let visible = screen.visibleFrame

        let origin = NSPoint(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.minY + visible.height * Self.verticalAnchor - size.height).rounded()
        )
        setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// 내용 높이를 창 테두리까지 포함한 크기로 바꾼다.
    private func frameSize(forContentHeight contentHeight: CGFloat?) -> NSSize {
        guard let contentHeight else { return frame.size }
        let content = NSRect(
            origin: .zero, size: NSSize(width: contentWidth, height: contentHeight)
        )
        return frameRect(forContentRect: content).size
    }

    /// 지금 내용이 차지하는 가로. borderless 라 창 가로와 같지만, 창틀이
    /// 생기는 날에도 계산이 어긋나지 않도록 창에 물어본다.
    private var contentWidth: CGFloat {
        contentRect(forFrameRect: frame).width
    }

    private static func screen(containing rect: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) }
    }

    /// 디스플레이가 여럿이면 지금 보고 있는 화면에 떠야 한다.
    private static func activeScreen() -> NSScreen {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
