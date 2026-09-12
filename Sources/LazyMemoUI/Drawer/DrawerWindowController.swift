import AppKit
import LazyMemoCore
import Observation
import SwiftUI

/// 「서랍」 창 — 바탕화면에 상주하고, 눌리면 자란다.
///
/// 달력 창(`CalendarWindowController`)과 같은 규칙을 쓰되 다른 점이 둘 있다.
///
/// 1. **창 크기가 곧 애니메이션이다.** 펼치고 접는 것이 뷰 안의 상태 변화가
///    아니라 창 프레임의 변화다. 그래서 SwiftUI 의 움직임과 `NSWindow` 의
///    움직임이 **같은 시간 같은 곡선**이어야 한다 (`duration`) — 어긋나면
///    내용이 먼저 나오고 창이 뒤따라 커지면서 한 프레임이 잘려 보인다.
/// 2. **바탕화면의 종이를 지켜본다.** 종이를 끌어다 놓는 것이 「넣기」의
///    주된 손짓인데, 끌리고 있는 것은 서랍이 아니라 남의 창이라 SwiftUI 는
///    아무것도 알지 못한다 (`noteMoved`).
@MainActor
final class DrawerWindowController: NSObject, NSWindowDelegate {
    private static let layoutKey = "drawer"

    /// 펼치고 접는 데 걸리는 시간. `DrawerView.opening` 과 짝이다.
    private static let duration: TimeInterval = 0.30

    /// 종이의 **포인터**가 서랍 안에 있어야 들어온다.
    ///
    /// 창끼리 겹치는 것으로 판정하지 않는다. 종이(260×200)는 닫힌 서랍(168×48)
    /// 보다 훨씬 커서, 겹침으로 재면 서랍 근처를 지나가기만 해도 걸린다.
    /// 사람이 겨누는 것은 언제나 **포인터**이므로 그것을 본다.
    ///
    /// 손을 놓은 것을 알아채는 데 쓰는 여유. 창이 멈춘 뒤 이만큼 기다렸다가
    /// **버튼이 실제로 떼어져 있는지** 본다 — 끌다가 잠깐 멈춘 것과 놓은 것을
    /// 시간으로 가르면 반드시 틀린다.
    private static let dropSettle: Duration = .milliseconds(90)

    let model: DrawerModel

    private let store: MemoStore
    private let layouts: LayoutStore
    private let windows: NoteWindowManager
    private let settings: SettingsStore
    private var window: DesktopLevelWindow?

    /// 닫혔을 때의 자리 — **정본이다.** 펼친 창은 여기서 자라고 여기로 돌아온다.
    ///
    /// 펼친 창에서 되짚어 셈하지 않는다. 자라는 방향이 화면 사정에 따라
    /// 달라지므로(`DrawerGeometry.openFrame`) 되짚으면 방향을 다시 맞혀야 하고,
    /// 한 번 어긋나면 접을 때마다 서랍이 조금씩 걸어간다.
    private var anchor: CGRect
    /// 마지막으로 본 창 자리. 사람이 창을 옮긴 만큼만 붙박이를 밀어 준다.
    private var lastFrame: CGRect = .zero
    private var dropWatch: Task<Void, Never>?
    /// 서랍이 펼쳐져 있는 동안 키를 지켜본다.
    ///
    /// SwiftUI 의 `onKeyPress` 대신 이것을 쓰는 이유는 이 저장소가 이미 같은
    /// 길을 쓰기 때문이다 (`QuickCaptureController.editingKeyMonitor`). 테두리
    /// 없는 패널에서 «어느 뷰가 키를 받는가» 는 화면에 안 보이는 일이고,
    /// 한 곳에 모아 두어야 시험이 물을 수 있다 (§14.9).
    private var keyMonitor: Any?
    /// 창 애니메이션 중에는 `windowDidMove` 가 매 프레임 온다. 그때 붙박이를
    /// 새로 적으면 **펼치는 동안 서랍이 제자리에서 조금씩 밀려난다.**
    private var isAnimating = false

    init(store: MemoStore, layouts: LayoutStore, windows: NoteWindowManager, settings: SettingsStore) {
        self.store = store
        self.layouts = layouts
        self.windows = windows
        self.settings = settings
        self.anchor = Self.restoredAnchor(layouts: layouts)
        self.model = DrawerModel(
            store: store,
            putAway: { [layouts] id in layouts.layout(for: id)?.hidden == true },
            folders: settings.current.folders ?? []
        )
        super.init()

        model.onToggle = { [weak self] open in self?.animate(open: open) }
        model.onTakeOut = { [weak self] id in self?.takeOut(id) }
        model.onDelete = { [weak self] id in self?.delete(id) }
        // 폴더의 차례와 빈 폴더는 설정이 든다 (`Settings.folders`). 어느 메모가
        // 어느 폴더인지는 파일이 안다.
        model.onFoldersChanged = { [settings] names in settings.update { $0.folders = names } }
        // 찾기로 목록이 줄거나 줄을 펼치면 창도 따라간다. **빠르게**
        // 따라가야 한다 — 글자 한 자에 0.3초씩 창이 출렁이면 그것은 「좁혀진다」가
        // 아니라 「창이 튄다」로 보인다.
        model.onLayoutChanged = { [weak self] in self?.resizeIfOpen(duration: 0.14) }

        observeStore()
        // 바탕화면에서 종이가 나가고 들어오는 것은 좌표 파일이 아는데, 그
        // 파일은 관찰되지 않는다 — 창 관리자가 바뀔 때마다 알려 준다.
        windows.onDeskChanged = { [weak self] in self?.model.refresh() }
        windows.onNoteDragged = { [weak self] id, frame in self?.noteMoved(id, frame: frame) }
    }

    private func observeStore() {
        withObservationTracking {
            _ = store.memos
        } onChange: {
            Task { @MainActor [weak self] in
                self?.model.refresh()
                self?.observeStore()
            }
        }
    }

    // MARK: 열고 닫기

    var isVisible: Bool { window != nil }

    func toggle() { isVisible ? close() : open() }

    /// 서랍을 바탕화면에 놓는다. **접힌 채로 나온다** — 상주하는 물건이
    /// 펼쳐진 채 나타나면 그것은 상주가 아니라 열린 창이다.
    func open() {
        guard window == nil else {
            window?.orderFront(nil)
            return
        }
        let frame = FrameClamping.restore(anchor, onto: screens, fallback: screen)
        anchor = frame

        let window = DesktopLevelWindow(contentRect: frame)
        // 서랍은 크기를 사람이 정하는 창이 아니다 — 크기가 곧 상태다.
        window.styleMask.remove(.resizable)
        window.minSize = DrawerGeometry.closedSize
        // 닫힌 서랍의 창은 폴더보다 크고 그 둘레는 비어 있다. 창 그림자를
        // 그대로 두면 **아무것도 없는 사각형에 그림자가 진다** — 뷰가 제
        // 모양대로 직접 드리운다 (`DrawerView`).
        window.hasShadow = false

        let hosting = FirstMouseHostingView(rootView: DrawerView(model: model))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setFrame(frame, display: false)
        window.delegate = self
        window.orderFront(nil)

        self.window = window
        lastFrame = frame
        record(frame, isVisible: true)
        model.setCeiling(DrawerGeometry.listCeiling(fitting: screen.height))
        watchKeys()
    }

    func close() {
        model.setOpen(false)
        record(anchor, isVisible: false)
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
        dropWatch?.cancel()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// 껐다 켜면 놓아 뒀던 대로 돌아온다. 치운 사람에게는 아무 일도 없다.
    func restoreIfWasVisible() {
        guard layouts.layout(forKey: Self.layoutKey)?.hidden == false else { return }
        open()
    }

    /// 창을 키우고 줄인다. **뷰의 상태는 이미 바뀐 뒤다** (`DrawerModel.setOpen`).
    private func animate(open: Bool) {
        guard let window else { return }
        isAnimating = true
        let target = open
            ? DrawerGeometry.openFrame(anchoredAt: anchor, size: model.geometry().size, on: screen)
            : anchor

        // 펼친 서랍은 앞에 선다 — 안의 종이를 누르고 끌 자리인데 브라우저
        // 뒤에 있으면 그 조작이 통째로 없는 것이 된다 (§7.1).
        if open { window.rise() } else { window.settle() }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.01 : Self.duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.9, 0.24, 1)
            window.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            // 완료 핸들러는 메인에서 온다 — 격리를 그대로 잇는다.
            MainActor.assumeIsolated { self?.isAnimating = false }
        }
        lastFrame = target
        record(anchor, isVisible: true)
    }

    /// 펼친 채로 장수가 바뀌면 창도 따라 자란다 — 안 그러면 새로 들어온 종이가
    /// 창 밖에서 잘린다.
    private func resizeIfOpen(duration: TimeInterval = DrawerWindowController.duration) {
        guard model.isOpen, let window else { return }
        let target = DrawerGeometry.openFrame(
            anchoredAt: anchor, size: model.geometry().size, on: screen
        )
        guard abs(target.width - window.frame.width) > 0.5
            || abs(target.height - window.frame.height) > 0.5
        else { return }
        isAnimating = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.01 : duration
            window.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.isAnimating = false }
        }
        lastFrame = target
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: 종이를 받아 든다

    /// 바탕화면의 종이가 움직였다 (`NoteWindowManager.onNoteDragged`).
    ///
    /// 포인터가 서랍 안에 있으면 **그 종이를 반투명하게** 만든다. 서랍은 종이
    /// 밑에 깔려 있어서(끌고 있는 창이 앞에 선다) 그대로 두면 사람은 자기가
    /// 무엇 위에 놓으려는지 볼 수 없다 — 비치게 하는 것이 유일한 길이다.
    private func noteMoved(_ id: ULID, frame: CGRect) {
        guard let window else { return }
        // **끌고 있는 중일 때만 본다.** 종이의 좌표는 창이 열릴 때도, 자리가
        // 복원될 때도 바뀐다 — 그때 포인터가 우연히 서랍 위에 있으면 사람이
        // 손도 안 댄 종이가 저 혼자 서랍으로 들어간다.
        guard NSEvent.pressedMouseButtons != 0 || model.landing == id else { return }
        let over = window.frame.contains(NSEvent.mouseLocation)

        if over {
            if model.landing != id {
                windows.dim(model.landing, on: false)
                model.landing = id
                windows.dim(id, on: true)
            }
            armDrop(id)
        } else if model.landing == id {
            windows.dim(id, on: false)
            model.landing = nil
            dropWatch?.cancel()
        }
    }

    /// 손을 놓았는지 지켜본다.
    ///
    /// 시간으로 가르지 않는다 — 끌다가 잠깐 멈춘 사람과 놓은 사람을 시간으로
    /// 구별하려 들면 반드시 한쪽이 틀리고, 그 틀림의 값은 **종이가 저 혼자
    /// 서랍에 들어가는 것**이다. 버튼이 실제로 떼어졌는지를 본다.
    private func armDrop(_ id: ULID) {
        dropWatch?.cancel()
        dropWatch = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.dropSettle)
            guard !Task.isCancelled, let self, model.landing == id else { return }
            guard NSEvent.pressedMouseButtons == 0 else {
                armDrop(id)
                return
            }
            file(id)
        }
    }

    /// 종이를 서랍에 넣는다 — **날아 들어가는 것까지가 이 동작이다.**
    ///
    /// 그냥 사라지게 하면 "닫혔다" 와 구별되지 않는다. 종이가 서랍 쪽으로
    /// 줄어들며 사라지는 그 짧은 동안이 «여기로 들어갔다» 를 말하는 유일한 말이다.
    private func file(_ id: ULID) {
        guard let window, let memo = store.memo(id) else { return }
        model.landing = nil
        windows.dim(id, on: false)
        windows.fileIntoDrawer(id, target: DrawerGeometry.landingSpot(in: window.frame))
        model.received(memo)
        window.riseBriefly()
    }

    /// 끌어다 놓은 것과 같은 길로 넣는다 — 소개 영상 주행(`DemoTour`)이 부른다.
    func fileForDemo(_ id: ULID) { file(id) }

    /// 닫힌 탭의 자리를 옮긴다 — 소개 영상 주행(`DemoTour`)이 무대 안으로 부른다.
    /// 자리는 이 창이 만들어질 때 좌표 파일에서 한 번 읽으므로, 그 뒤에 심은
    /// 무대는 여기로 알려야 한다.
    func placeForDemo(at origin: CGPoint) {
        anchor = CGRect(origin: origin, size: DrawerGeometry.closedSize)
        // 무대에는 탭이 보여야 한다 — 「보이던 대로 되돌린다」가 이 값을 읽는다.
        record(anchor, isVisible: true)
        if let window, !model.isOpen { window.setFrame(anchor, display: true) }
    }

    private func takeOut(_ id: ULID) {
        windows.unfile(id)
        model.refresh()
        resizeIfOpen()
    }

    private func delete(_ id: ULID) {
        Task { [store] in try? await store.delete(id) }
    }

    // MARK: 키보드

    /// 펼친 서랍에서 키를 맡는다. **문법은 `DrawerKeys` 가 정한다.**
    private func watchKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event -> NSEvent? in
            let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
            // 맡은 키는 삼킨다 — 흘려보내면 글 상자가 같은 키를 한 번 더 받는다.
            return handled ? nil : event
        }
    }

    /// 이 키를 서랍이 맡는가.
    ///
    /// 비공개가 아닌 이유는 `QuickCaptureController.handles` 와 같다 — **키가
    /// 어디로 가는지는 화면에 안 보인다.** 시험이 직접 부른다.
    func handle(_ event: NSEvent) -> Bool {
        guard let window, window.isKeyWindow, model.isOpen else { return false }

        // **조합 중에는 아무것도 맡지 않는다.** 한글을 치는 동안의 ↩ 는 «펼쳐라»
        // 가 아니라 «이 글자를 확정하라» 다. 그것을 삼키면 치던 글자가 사라진다.
        if (window.firstResponder as? NSTextView)?.hasMarkedText() == true { return false }

        let editing = isEditingSearch
        guard let intent = DrawerKeys.intent(
            characters: event.charactersIgnoringModifiers,
            modifiers: event.modifierFlags,
            isEditing: editing
        ) else { return false }

        switch intent {
        case .search:
            model.inviteSearch()
            return true
        case .back:
            // 글 상자에 커서가 있고 더 벗길 겹이 없으면 **커서를 무더기로
            // 돌려준다.** 여기서 서랍을 닫아 버리면 「상자에서 빠져나오려던
            // esc」 한 번이 서랍을 통째로 접는다.
            if editing, model.escapeWouldClose {
                model.releaseSearch()
                return true
            }
            return model.handle(intent)
        default:
            return model.handle(intent)
        }
    }

    /// 지금 찾기 상자에 커서가 있는가 — **글자 키를 삼키지 않기 위해** 본다.
    ///
    /// 뷰가 적어 준 값을 먼저 믿는다 (`DrawerModel.isEditingSearch`) — `@FocusState`
    /// 만이 커서의 자리를 확실히 안다. 응답 사슬은 그 다음이다: SwiftUI 가 글
    /// 상자를 무엇으로 만드는지는 판마다 다르고, 둘 중 하나만 맞아도 «찾는 중» 은
    /// 참이다. 틀렸을 때의 값이 비싸다 — 질의에 띄어쓰기를 넣는 스페이스가
    /// **종이를 고르는 키**가 된다.
    private var isEditingSearch: Bool {
        model.isEditingSearch || window?.firstResponder is NSTextView
    }

    // MARK: 눈으로 확인할 수 없는 것 (§14.9)

    /// 펼치고 접는 것이 **실제 창에서** 약속대로 되는가.
    ///
    /// 시험은 산수만 볼 수 있다 (`DrawerGeometryTests`). 창이 진짜로 그 크기가
    /// 되는지, 접었을 때 제자리로 돌아오는지는 `NSWindow` 를 세워 봐야 알고,
    /// 화면 기록 권한이 없는 이 저장소에서는 **숫자로 읽는 것이 유일한 눈**이다.
    /// 그림으로도 안 된다 — 왼쪽 위가 3pt 밀린 것은 렌더에 흔적을 남기지 않는다.
    func diagnostics() async -> String {
        open()
        let closed = window?.frame ?? .zero

        model.setOpen(true)
        try? await Task.sleep(for: .milliseconds(600))
        let opened = window?.frame ?? .zero

        model.setOpen(false)
        try? await Task.sleep(for: .milliseconds(600))
        let back = window?.frame ?? .zero

        let plan = model.geometry()
        // 자라는 방향은 화면 사정이 정한다 (`DrawerGeometry.openFrame`) — 지켜야
        // 하는 것은 «위를 붙박는다» 가 아니라 **모서리 하나가 그대로 남는다** 다.
        let sameSide = abs(opened.minX - closed.minX) < 1 || abs(opened.maxX - closed.maxX) < 1
        let sameEdge = abs(opened.maxY - closed.maxY) < 1 || abs(opened.minY - closed.minY) < 1
        let anchored = sameSide && sameEdge
        let restored = abs(back.minX - closed.minX) < 1 && abs(back.maxY - closed.maxY) < 1
        let sized = abs(opened.width - plan.size.width) < 1
            && abs(opened.height - plan.size.height) < 1

        // 한 줄로 이으면 타입 검사가 시간 안에 못 끝낸다. 조각으로 나눠 잇는다.
        let frames = "장수=\(model.count) 닫힘=\(Self.text(closed)) 펼침=\(Self.text(opened))"
        let returned = " 되돌아옴=\(Self.text(back))"
        let flags = " 모서리고정=\(anchored) 제자리복귀=\(restored) 계획크기=\(sized)"
        let planned = Self.text(CGRect(origin: .zero, size: plan.size))
        let shape = " (계획 \(planned), \(plan.rows)줄, 폴더=\(model.folders.count), 스크롤=\(plan.scrolls))"
        return frames + returned + flags + shape
    }

    private static func text(_ frame: CGRect) -> String {
        "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))×\(Int(frame.height))"
    }

    // MARK: 자리

    private var screens: [CGRect] { NSScreen.screens.map(\.visibleFrame) }

    private var screen: CGRect {
        NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private static func restoredAnchor(layouts: LayoutStore) -> CGRect {
        if let saved = layouts.layout(forKey: layoutKey) {
            return CGRect(origin: saved.frame.origin, size: DrawerGeometry.closedSize)
        }
        // 기본 자리는 **왼쪽 아래.** 메모는 오른쪽 위부터 쌓이고 달력은 왼쪽
        // 위에 서므로, 셋이 서로를 비켜간다.
        let visible = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGRect(
            x: visible.minX + 40,
            y: visible.minY + 40,
            width: DrawerGeometry.closedSize.width,
            height: DrawerGeometry.closedSize.height
        )
    }

    private func record(_ frame: CGRect, isVisible: Bool) {
        layouts.set(WindowLayout(frame: frame, hidden: !isVisible), forKey: Self.layoutKey)
    }

    // MARK: NSWindowDelegate

    /// 사람이 서랍을 옮겼다. **펼친 채로 옮겼어도 붙박이는 왼쪽 위다** —
    /// 접으면 그 자리에 그대로 앉는다.
    func windowDidMove(_ notification: Notification) {
        guard let window, !isAnimating else { return }
        // **옮긴 만큼만 붙박이를 민다.** 펼친 창에서 닫힌 자리를 되짚어 셈하면
        // 자라는 방향(위로/아래로)을 다시 맞혀야 하고, 한 번 틀리면 접을
        // 때마다 서랍이 조금씩 걸어간다.
        let moved = CGPoint(
            x: window.frame.minX - lastFrame.minX, y: window.frame.minY - lastFrame.minY
        )
        anchor.origin.x += moved.x
        anchor.origin.y += moved.y
        lastFrame = window.frame
        record(anchor, isVisible: true)
    }


}
