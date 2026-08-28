import AppKit

/// 바탕화면 위·일반 창 아래에 머무는 창 (설계문서 §7).
///
/// 메모 하나당 하나씩 생기므로(D2) 여기서 정한 창 속성이 곧 프로젝트 전체의
/// 창 동작이 된다. 이 클래스가 설계문서 §7 의 유일한 구현 지점이다.
///
/// **자리는 둘이다.** 평소에는 바탕화면 높이에 눕고, 손이 닿는 동안에만
/// 앞으로 올라선다. 이것이 없으면 "메모 열기" 가 거짓말이 된다 — 바탕화면
/// 레벨의 창은 브라우저 뒤에 있어서, 열어도 사용자 눈에는 아무 일도 일어나지
/// 않고 키보드 포커스만 보이지 않는 곳으로 넘어간다.
final class DesktopLevelWindow: NSWindow {
    /// 바탕화면 아이콘 바로 위. Finder 아이콘을 가리지만 일반 앱 창에는 덮인다.
    static let desktopLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
    )

    /// 손이 닿은 동안 올라서는 자리.
    ///
    /// 빠른 입력(`.floating`)보다 **한 칸 아래**다. 메모를 고치는 중에 ⌥⌘N 을
    /// 눌러도 입력 상자가 메모에 가리면 안 된다.
    static let focusedLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)

    /// 방금 적힌 메모를 잠깐 보였다가 내려앉히는 타이머.
    private var settleTask: Task<Void, Never>?

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
        // 다만 본문은 텍스트 뷰가 덮고 있어서 이 설정만으로는 끌리지 않는다 —
        // 글 위에서의 끌기는 `MemoNSTextView` 가 창으로 넘겨준다.
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

    // MARK: 앞으로 나왔다 내려앉기

    /// 손이 닿았다 — 앞으로 올라선다.
    override func becomeKey() {
        super.becomeKey()
        settleTask?.cancel()
        settleTask = nil
        level = Self.focusedLevel
    }

    /// 손을 뗐다 — 다시 바탕으로 내려앉는다.
    override func resignKey() {
        super.resignKey()
        settleTask?.cancel()
        settleTask = nil
        level = Self.desktopLevel
    }

    /// 방금 적힌 메모를 **포커스를 뺏지 않고** 잠깐 보여준다.
    ///
    /// 빠른 입력에서 Return 을 눌렀을 때 쓴다. 창을 키로 만들면 사용자가
    /// 하던 앱에서 손이 뜯겨 나가고, 아무것도 안 하면 "적히긴 한 건가" 가
    /// 남는다. 잠깐 보였다 내려앉는 것이 둘 다 피하는 유일한 길이다.
    func riseBriefly(for duration: Duration = .milliseconds(1600)) {
        settleTask?.cancel()
        level = Self.focusedLevel
        orderFront(nil)

        settleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self, !isKeyWindow else { return }
            level = Self.desktopLevel
        }
    }

    /// 창을 치우기 전에 타이머를 끊는다.
    func cancelSettling() {
        settleTask?.cancel()
        settleTask = nil
    }
}
