import AppKit
import LazyMemoCore

/// 메뉴바 상주 아이콘과 그 메뉴.
///
/// 앱에 창이 하나도 없어도 이 컨트롤러가 살아 있는 한 앱은 살아 있다.
/// 메모 목록과 "최근 삭제" 되돌리기 동선(D6)이 여기에 있다.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// 메뉴에 직접 나열하는 메모 수. 그 이상은 빠른 입력의 검색으로 찾는다.
    private static let listedMemoLimit = 12
    private static let listedTrashLimit = 10

    private let statusItem: NSStatusItem
    private let paths: AppPaths
    private let store: MemoStore
    private let windows: NoteWindowManager
    private let spike = DesktopWindowSpike()
    private let capture: QuickCaptureController
    private let calendar: CalendarWindowController
    private let hotkey = HotkeyManager()
    private let recorder = HotkeyRecorder()
    private let settings: SettingsStore
    private let menu = NSMenu()

    /// 단축키 등록에 실패했는지 — 다른 앱이 같은 조합을 선점한 경우다.
    private var hotkeyAvailable = false

    init(
        paths: AppPaths,
        store: MemoStore,
        windows: NoteWindowManager,
        layouts: LayoutStore,
        settings: SettingsStore
    ) {
        self.paths = paths
        self.store = store
        self.windows = windows
        self.settings = settings
        self.capture = QuickCaptureController(store: store, windows: windows)
        self.calendar = CalendarWindowController(
            store: store, layouts: layouts,
            onSelectMemo: { [weak windows] id in windows?.reveal(id) }
        )
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        menu.delegate = self

        // 말풍선은 아이콘 밑에 매달린다. 아이콘 자리는 여기만 알고 있고,
        // 메뉴바가 붐비면 숨겨져 자리가 없을 수도 있다.
        capture.anchorProvider = { [weak self] in self?.statusItemFrame() }

        // 메뉴를 statusItem.menu 에 걸면 좌클릭이 메뉴에 잡혀 빠른 입력이 막힌다.
        // 좌클릭 = 빠른 입력, 우클릭 = 메뉴로 나눈다.
        hotkeyAvailable = hotkey.register(storedHotkey()) { [weak self] in
            self?.capture.toggle()
        }
    }

    /// 설정에 남은 조합. 없으면 기본값.
    private func storedHotkey() -> Hotkey {
        let saved = settings.current
        guard let keyCode = saved.hotkeyKeyCode, let modifiers = saved.hotkeyModifiers
        else { return .standard }
        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }

    /// 메뉴바 아이콘의 화면 좌표. 아이콘이 숨겨져 있으면 `nil`.
    private func statusItemFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    func openSpike() { spike.open() }

    func openCalendar() { calendar.open() }

    /// 성능 예산 측정용 진입점 (`scripts/measure-capture.sh`).
    var captureLatency: Duration? { capture.lastLatency }

    func showCaptureForMeasurement() {
        capture.show()
    }

    func closeCapture() { capture.close(returningFocus: false) }

    /// `verify-capture.sh` 가 읽는 진단 문자열.
    var captureDiagnostics: String { capture.diagnostics }

    /// 표준 편집 단축키(⌘A)가 글 쓰는 곳까지 닿는지.
    var selectAllReach: String { capture.selectAllReach() }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.menuBarIcon()
        button.toolTip = "lazymemo — \(hotkey.current.displayName) 로 빠른 입력"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// 앱 마크. 3배 해상도 한 장을 18pt 로 줄여 쓴다 — 표현을 여러 개
    /// 관리하지 않아도 되고, template 로 두면 시스템이 색과 강조를 처리한다.
    private static func menuBarIcon() -> NSImage? {
        guard let image = Bundle.module.image(forResource: "MenuBarIcon") else {
            // 리소스를 못 찾아도 메뉴바가 비지 않게 한다.
            return NSImage(systemSymbolName: "note.text", accessibilityDescription: "lazymemo")
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        image.accessibilityDescription = "lazymemo"
        return image
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
        } else {
            // 누르면 뜨고 다시 누르면 꺼진다. 처음엔 "토글이면 안 떴나 싶어
            // 한 번 더 눌렀을 때 도로 닫힌다" 는 걱정으로 열기만 했는데,
            // 실제로 써 보니 **닫을 길이 없는 쪽이 훨씬 답답했다.**
            capture.toggle()
        }
    }

    // MARK: 메뉴 — 열 때마다 다시 짓는다

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let quick = item(title: "빠른 입력", action: #selector(openCapture), key: "")
        menu.addItem(quick)
        if !hotkeyAvailable {
            menu.addItem(disabled("⚠︎ \(hotkey.current.displayName) 을 다른 앱이 쓰고 있습니다"))
        }
        menu.addItem(item(title: "빈 메모 만들기", action: #selector(newMemo), key: ""))
        menu.addItem(.separator())

        let calendarItem = item(title: "달력", action: #selector(toggleCalendar), key: "")
        calendarItem.state = calendar.isOpen ? .on : .off
        menu.addItem(calendarItem)
        menu.addItem(.separator())

        addMemoList(to: menu)
        addTrashSection(to: menu)

        menu.addItem(.separator())
        menu.addItem(settingsItem())
        menu.addItem(item(title: "메모 폴더 열기", action: #selector(openVault), key: ""))
        menu.addItem(spikeItem())
        menu.addItem(.separator())
        menu.addItem(item(title: "lazymemo 종료", action: #selector(quit), key: "q"))
    }

    private func addMemoList(to menu: NSMenu) {
        let memos = store.memos
        guard !memos.isEmpty else {
            menu.addItem(disabled("메모 없음"))
            return
        }

        menu.addItem(header("메모 \(memos.count)장"))
        for memo in memos.prefix(Self.listedMemoLimit) {
            let entry = item(title: memo.title, action: #selector(revealMemo(_:)), key: "")
            entry.representedObject = memo.id.stringValue
            entry.image = swatch(memo.color)
            // 바탕화면에 떠 있는 메모에 체크를 달아 "닫힘 = 숨김"이 보이게 한다.
            entry.state = windows.isVisible(memo.id) ? .on : .off
            menu.addItem(entry)
        }
        if memos.count > Self.listedMemoLimit {
            menu.addItem(disabled("… 외 \(memos.count - Self.listedMemoLimit)장"))
        }
    }

    /// D6 의 되돌리기 동선. 하드 삭제 버튼은 여기에도 없다.
    private func addTrashSection(to menu: NSMenu) {
        let trash = store.trash
        guard !trash.isEmpty else { return }

        menu.addItem(.separator())
        let parent = NSMenuItem(title: "최근 삭제 (\(trash.count))", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for memo in trash.prefix(Self.listedTrashLimit) {
            let entry = item(title: memo.title, action: #selector(restoreMemo(_:)), key: "")
            entry.representedObject = memo.id.stringValue
            entry.toolTip = "되돌리기"
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        submenu.addItem(disabled("30일 뒤 자동으로 지워집니다"))
        parent.submenu = submenu
        menu.addItem(parent)
    }

    /// 설정. 항목이 몇 개뿐이라 창을 따로 짓지 않는다 — 창을 여는 것 자체가
    /// 조작 한 번이고, 이 앱은 그 한 번을 아끼는 앱이다.
    private func settingsItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "설정", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let shortcut = item(title: "단축키 바꾸기…", action: #selector(changeHotkey), key: "")
        shortcut.subtitle = "지금은 \(hotkey.current.displayName)"
        submenu.addItem(shortcut)

        submenu.addItem(.separator())
        let embed = item(title: "링크를 카드로 펼치기", action: #selector(toggleLinkEmbedding), key: "")
        embed.state = settings.current.embedsLinks ?? true ? .on : .off
        // 네트워크를 쓰는 유일한 기능이다. 켜져 있다는 사실이 보여야 한다 (§9.3).
        embed.subtitle = "제목과 그림을 가져오려고 그 주소에 접속합니다"
        submenu.addItem(embed)

        parent.submenu = submenu
        return parent
    }

    private func spikeItem() -> NSMenuItem {
        let entry = item(title: "바탕화면 창 스파이크", action: #selector(toggleSpike), key: "")
        entry.state = spike.isOpen ? .on : .off
        return entry
    }

    // MARK: 메뉴 항목 만들기

    private func item(title: String, action: Selector, key: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    private func header(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        menuItem.isEnabled = false
        return menuItem
    }

    private func swatch(_ color: MemoColor) -> NSImage {
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(color.tint).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return image
    }

    // MARK: 동작

    @objc private func openCapture() { capture.toggle() }

    @objc private func changeHotkey() {
        recorder.begin(current: hotkey.current) { [weak self] candidate in
            guard let self else { return false }
            let registered = self.hotkey.register(candidate) { [weak self] in
                self?.capture.toggle()
            }
            guard registered else {
                // 실패했으면 쓰던 것을 도로 걸어 둔다. 바꾸려다 아예 못 쓰게
                // 되는 것이 가장 나쁘다.
                self.hotkeyAvailable = self.hotkey.register(self.storedHotkey()) { [weak self] in
                    self?.capture.toggle()
                }
                return false
            }
            self.hotkeyAvailable = true
            self.settings.update {
                $0.hotkeyKeyCode = candidate.keyCode
                $0.hotkeyModifiers = candidate.modifiers
            }
            self.configureButton()
            return true
        }
    }

    @objc private func toggleLinkEmbedding() {
        settings.update { $0.embedsLinks = !($0.embedsLinks ?? true) }
    }

    @objc private func newMemo() {
        Task {
            guard let memo = try? await store.create() else { return }
            windows.open(memo, activating: true).focusEditor()
        }
    }

    @objc private func revealMemo(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = ULID(raw) else { return }
        windows.reveal(id)
    }

    @objc private func restoreMemo(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = ULID(raw) else { return }
        Task {
            try? await store.restore(id)
            windows.reveal(id)
        }
    }

    @objc private func toggleCalendar() { calendar.toggle() }

    @objc private func toggleSpike() { spike.toggle() }

    @objc private func openVault() { NSWorkspace.shared.open(paths.vault) }

    @objc private func quit() { NSApp.terminate(nil) }
}
