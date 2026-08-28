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
    private let menu = NSMenu()

    /// 단축키 등록에 실패했는지 — 다른 앱이 같은 조합을 선점한 경우다.
    private var hotkeyAvailable = false

    init(paths: AppPaths, store: MemoStore, windows: NoteWindowManager, layouts: LayoutStore) {
        self.paths = paths
        self.store = store
        self.windows = windows
        self.capture = QuickCaptureController(store: store, windows: windows)
        self.calendar = CalendarWindowController(
            store: store, layouts: layouts,
            onSelectMemo: { [weak windows] id in windows?.reveal(id) }
        )
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        menu.delegate = self

        // 메뉴를 statusItem.menu 에 걸면 좌클릭이 메뉴에 잡혀 빠른 입력이 막힌다.
        // 좌클릭 = 빠른 입력, 우클릭 = 메뉴로 나눈다.
        hotkeyAvailable = hotkey.register { [weak self] in
            self?.toggleCapture()
        }
    }

    func openSpike() { spike.open() }

    func openCalendar() { calendar.open() }

    /// 성능 예산 측정용 진입점 (`scripts/measure-capture.sh`).
    var captureLatency: Duration? { capture.lastLatency }

    func showCaptureForMeasurement() {
        guard let button = statusItem.button else { return }
        capture.show(from: button)
    }

    func closeCapture() { capture.close() }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "lazymemo")
        button.image?.isTemplate = true
        button.toolTip = "lazymemo — \(HotkeyManager.displayName) 로 빠른 입력"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
        } else {
            capture.toggle(from: button)
        }
    }

    private func toggleCapture() {
        guard let button = statusItem.button else { return }
        capture.toggle(from: button)
    }

    // MARK: 메뉴 — 열 때마다 다시 짓는다

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let quick = item(title: "빠른 입력", action: #selector(openCapture), key: "")
        quick.keyEquivalent = "n"
        quick.keyEquivalentModifierMask = [.option, .command]
        menu.addItem(quick)
        if !hotkeyAvailable {
            menu.addItem(disabled("⚠︎ \(HotkeyManager.displayName) 을 다른 앱이 쓰고 있습니다"))
        }
        menu.addItem(item(title: "빈 메모 만들기", action: #selector(newMemo), key: ""))
        menu.addItem(.separator())

        let calendarItem = item(title: "캘린더", action: #selector(toggleCalendar), key: "")
        calendarItem.state = calendar.isOpen ? .on : .off
        menu.addItem(calendarItem)
        menu.addItem(.separator())

        addMemoList(to: menu)
        addTrashSection(to: menu)

        menu.addItem(.separator())
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
            NSColor(color.appKit).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return image
    }

    // MARK: 동작

    @objc private func openCapture() { toggleCapture() }

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
