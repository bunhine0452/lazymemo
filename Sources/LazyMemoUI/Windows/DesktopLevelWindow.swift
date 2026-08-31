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
/// **왜 `NSWindow` 가 아니라 `NSPanel` 인가 — 알트탭에 뜨지 않기 위해서다.**
///
/// `LSUIElement` 와 `.accessory` 는 앱을 **⌘Tab(앱 전환기)** 에서 지우고,
/// `.ignoresCycle` 은 ⌘` 창 순환에서 지운다. 그 셋은 이미 걸려 있었다.
/// 그런데 AltTab 같은 **창 단위 전환기**는 앱 목록이 아니라 접근성 API 로
/// 창을 훑고, `NSWindow` 는 역할이 `AXStandardWindow` 다 — 메모가 열 장이면
/// 전환기에 열 칸이 생긴다. 바탕화면에 눕혀 둔 쪽지가 브라우저·에디터와
/// 나란히 서는 것은 이 앱이 하려는 말과 정반대다.
///
/// `NSPanel` 은 역할이 `AXFloatingWindow` 라 그 목록에서 빠진다. 대신
/// **`hidesOnDeactivate` 를 반드시 꺼야 한다** — 패널의 기본값은 켜짐이고,
/// 그대로 두면 다른 앱을 쓰는 순간 메모가 통째로 화면에서 사라진다. 이 앱에서
/// 그것은 곧 앱이 없어지는 것이다 (`QuickCapturePanel` 이 같은 함정을 겪었다).
final class DesktopLevelWindow: NSPanel {
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

        // **패널의 기본값은 켜짐이다.** 끄지 않으면 다른 앱을 쓰는 순간 메모가
        // 통째로 사라진다 — 바탕화면 메모는 앱이 비활성인 동안이 삶의 대부분이다.
        hidesOnDeactivate = false
        // 이 앱에는 「창」 메뉴가 없지만, 종이는 목록에 오를 물건이 아니다.
        isExcludedFromWindowsMenu = true

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

    /// 이 창이 **바깥에 자기를 뭐라고 소개하는지** (`verify-notes.sh`).
    ///
    /// 화면으로는 확인할 수 없다. 표준 창이든 떠 있는 창이든 그림은 똑같고,
    /// 다른 점은 **다른 앱이 이 창을 목록에 넣느냐**뿐이라 렌더에도 캡처에도
    /// 안 잡힌다. 누군가 `NSPanel` 을 `NSWindow` 로 되돌리면 알트탭에 메모가
    /// 도로 줄줄이 서는데, 그것을 알아채는 데 며칠이 걸린다 (§14.9).
    static var roleDiagnostics: String {
        let probe = DesktopLevelWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: 200, height: 140)
        )
        defer { probe.orderOut(nil) }
        let subrole = probe.accessibilitySubrole()?.rawValue ?? "없음"
        return "subrole=\(subrole) 표준창=\(subrole == "AXStandardWindow") "
            + "순환제외=\(probe.collectionBehavior.contains(.ignoresCycle)) "
            + "비활성숨김=\(probe.hidesOnDeactivate)"
    }

    /// 이 창이 무엇인지 **바깥에 정확히 밝힌다.**
    ///
    /// 테두리 없는 패널의 기본값은 `AXDialog` 인데, 그것은 사실이 아니다 —
    /// 대화상자는 사람이 답해야 넘어가는 물건이고 이 종이는 바탕화면에 눕혀 둔
    /// 쪽지다. 그리고 창 단위 전환기(AltTab 류)는 표준 창과 **대화상자를 함께**
    /// 목록에 넣으므로, 잘못 소개하는 것만으로 메모 열 장이 알트탭에 줄줄이 선다.
    ///
    /// `AXFloatingWindow` 가 이 창의 실제 성격이고, 보조 기술에도 그 편이 옳다.
    override func accessibilitySubrole() -> NSAccessibility.Subrole? {
        .floatingWindow
    }

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

    /// **놓을 때까지** 앞에 서 있는다.
    ///
    /// `riseBriefly` 와 다른 점은 스스로 내려앉지 않는다는 것이다. 달력이 놓을
    /// 날을 기다리는 동안(설계문서 §7.2) 창이 시간이 지났다고 브라우저 뒤로
    /// 내려가면 조준하던 자리가 그대로 사라진다 — 겨누는 시간은 사람마다 다르다.
    func rise() {
        settleTask?.cancel()
        settleTask = nil
        level = Self.focusedLevel
        orderFront(nil)
    }

    /// 일이 끝났다 — 다시 바탕으로 내려앉는다.
    /// 손이 아직 창 안에 있으면(키를 잡고 있으면) 건드리지 않는다.
    func settle() {
        settleTask?.cancel()
        settleTask = nil
        guard !isKeyWindow else { return }
        level = Self.desktopLevel
    }

    /// 창을 치우기 전에 타이머를 끊는다.
    func cancelSettling() {
        settleTask?.cancel()
        settleTask = nil
    }
}
