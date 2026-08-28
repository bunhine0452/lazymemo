import AppKit

/// 바탕화면 위·일반 창 아래에 머무는 창 (설계문서 §7).
///
/// 메모 하나당 하나씩 생기므로(D2) 여기서 정한 창 속성이 곧 프로젝트 전체의
/// 창 동작이 된다. 이 클래스가 설계문서 §7 의 유일한 구현 지점이다.
final class DesktopLevelWindow: NSWindow {
    /// 바탕화면 아이콘 바로 위. Finder 아이콘을 가리지만 일반 앱 창에는 덮인다.
    static let desktopLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
    )

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // .resizable 은 테두리가 없어도 가장자리 끌기를 살려 준다.
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = Self.desktopLevel

        // Space 를 옮겨도 따라오고, Mission Control 에서 흔들리지 않는다.
        // .ignoresCycle 은 ⌘Tab 창 순환에서 빼기 위한 것 — 메모가 수십 개일 때
        // 앱 전환을 오염시키지 않아야 한다.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // 저장 버튼이 없는 앱이므로 창을 닫는 것 = 메모를 숨기는 것이다.
        // 시스템이 임의로 해제하지 않도록 직접 소유한다.
        isReleasedWhenClosed = false

        // 배경 어디를 잡아도 끌린다. 테두리가 없으니 이것 말고 잡을 곳이 없다.
        isMovableByWindowBackground = true

        // 전체화면 앱으로 전환될 여지를 주지 않는다.
        animationBehavior = .none

        minSize = NSSize(width: 180, height: 120)
    }

    // 주의: `contentView` 로 NSHostingView 를 붙일 때는 `sizingOptions = []` 로
    // 끄고 **붙인 뒤에** setFrame 을 불러야 한다. 기본값이면 SwiftUI 뷰의
    // 이상적 크기가 창 크기를 덮어써 layout.json 복원이 조용히 깨진다.

    /// borderless 창은 기본적으로 키 윈도가 되지 못한다.
    /// 메모 안에서 글을 써야 하므로(§8) 명시적으로 연다.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
