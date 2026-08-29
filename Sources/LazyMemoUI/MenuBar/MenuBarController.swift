import AppKit
import LazyMemoCore

/// 메뉴바 상주 아이콘과 그 메뉴.
///
/// 앱에 창이 하나도 없어도 이 컨트롤러가 살아 있는 한 앱은 살아 있다.
/// 메모 목록과 "최근 삭제" 되돌리기 동선(D6)이 여기에 있다.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// 메뉴에 직접 나열하는 메모 수. 그 이상은 빠른 입력의 검색으로 찾는다.
    ///
    /// 12장에서 8장으로 줄였다. 목록이 화면 높이를 채우면 그건 목록이 아니라
    /// 또 하나의 치울 거리다 — 게으른 사람이 훑어보는 길이는 그보다 짧다.
    private static let listedMemoLimit = 8
    private static let listedTrashLimit = 10
    /// "방금 지웠다" 로 치는 시간. 이 안에 지운 것은 메뉴 첫 자리에서 되돌린다.
    private static let recentDeletionWindow: TimeInterval = 5 * 60

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
    private let appearance: PaperAppearance
    private let menu = NSMenu()

    /// 단축키 등록에 실패했는지 — 다른 앱이 같은 조합을 선점한 경우다.
    private var hotkeyAvailable = false

    init(
        paths: AppPaths,
        store: MemoStore,
        windows: NoteWindowManager,
        layouts: LayoutStore,
        settings: SettingsStore,
        appearance: PaperAppearance
    ) {
        self.paths = paths
        self.store = store
        self.windows = windows
        self.settings = settings
        self.appearance = appearance
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

        // 날짜를 적었으면 그것은 일정이다 — 종이가 아니라 달력이 받는다 (§7.2).
        capture.onScheduled = { [weak self] day in self?.calendar.announce(day) }

        // 종이에서 달력으로 건너가는 길 (§7.2). 두 창이 서로를 모르므로
        // 여기서 잇는다 — 날짜가 없으면 놓을 날을 고르러 가고, 있으면 그
        // 일정이 달력의 어디에 있는지 보러 간다.
        windows.onCalendarRequest = { [weak self] id in
            guard let self, let memo = store.memo(id) else { return }
            if let day = Schedule(memo).day() {
                calendar.reveal(day)
            } else {
                calendar.aim(at: memo)
            }
        }

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

    /// 껐다 켰을 때 달력을 열려 있던 대로 되돌린다 (§7.2).
    func restoreCalendar() { calendar.restoreIfWasOpen() }

    /// 성능 예산 측정용 진입점 (`scripts/measure-capture.sh`).
    var captureLatency: Duration? { capture.lastLatency }

    func showCaptureForMeasurement() {
        capture.show()
    }

    func closeCapture() { capture.close(returningFocus: false) }

    /// `verify-capture.sh` 가 읽는 진단 문자열.
    var captureDiagnostics: String { capture.diagnostics }

    /// `verify-capture-dismiss.sh` 가 읽는 진단 — 가짜 클릭으로 바깥과 안쪽을
    /// 눌러 보고 상자가 치워지는지 본다.
    func captureDismissReach() async -> String { await capture.dismissReach() }

    /// `verify-capture-delete.sh` 가 읽는 진단 — 빠른 입력의 고른 줄에
    /// ⌘⌫ 를 눌러 보고 메모가 휴지통으로 가는지 본다.
    func captureDeleteReach() async -> String { await capture.deleteReach() }

    /// 표준 편집 단축키(⌘A)가 글 쓰는 곳까지 닿는지.
    var selectAllReach: String { capture.selectAllReach() }

    /// `LAZYMEMO_MENU=1` 이 읽는 진단 — 메뉴를 실제로 한 번 지어 항목을 적는다.
    ///
    /// 메뉴는 시스템이 띄우는 창이라 렌더로도 캡처로도 잡히지 않는다. 줄이
    /// 뷰(`MemoRow`)로 바뀐 뒤로는 "메뉴가 아예 안 지어진다" 는 종류의 고장이
    /// 가능해졌으므로, 짓는 것까지만이라도 눈으로 확인할 통로를 둔다.
    var menuDiagnostics: String {
        menuNeedsUpdate(menu)
        return menu.items.map { entry in
            if entry.isSeparatorItem { return "  ──────" }
            let mark = entry.view is MemoRow ? "▪︎" : (entry.isAlternate ? "⌥" : "·")
            let key = entry.keyEquivalent.isEmpty ? "" : "  [\(entry.keyEquivalent)]"
            let submenu = entry.submenu.map { "  ▸\($0.items.count)" } ?? ""
            return "  \(mark) \(entry.title)\(key)\(submenu)"
        }.joined(separator: "\n")
    }

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
        CaptureTrace.log("아이콘 클릭 event=\(NSApp.currentEvent?.type.rawValue.description ?? "없음")")
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

        menu.addItem(captureItem())
        if !hotkeyAvailable {
            menu.addItem(disabled("⚠︎ \(hotkey.current.displayName) 을 다른 앱이 쓰고 있습니다"))
        }
        menu.addItem(item(title: "빈 종이 꺼내기", action: #selector(newMemo), key: ""))
        menu.addItem(.separator())

        let calendarItem = item(title: "달력", action: #selector(toggleCalendar), key: "")
        calendarItem.state = calendar.isOpen ? .on : .off
        menu.addItem(calendarItem)
        menu.addItem(.separator())

        addMemoList(to: menu)
        addTrashSection(to: menu)

        menu.addItem(.separator())
        menu.addItem(settingsItem())
        addVaultItem(to: menu)
        menu.addItem(.separator())
        menu.addItem(item(title: "lazymemo 종료", action: #selector(quit), key: "q"))
    }

    /// 이 앱의 머리 동작. 단축키를 **오른쪽에 적어 둔다** — 메뉴를 여는 사람은
    /// 대개 단축키를 모르는 사람이고, 알고 나면 다시는 메뉴를 열지 않는다.
    private func captureItem() -> NSMenuItem {
        let entry = item(title: "빠른 입력", action: #selector(openCapture), key: "")
        if let (key, modifiers) = hotkey.current.menuKeyEquivalent {
            entry.keyEquivalent = key
            entry.keyEquivalentModifierMask = modifiers
        }
        return entry
    }

    /// 종이가 얼마나 비치는가 (§14.5 의 예외).
    ///
    /// 단계를 네 칸으로 끊는다 — 슬라이더는 조준해서 끌어야 하는 물건이고,
    /// 메뉴 안에서는 더 그렇다.
    private func paperOpacityItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "종이 투명도", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for step in PaperAppearance.steps {
            let entry = item(title: step.label, action: #selector(setPaperOpacity(_:)), key: "")
            entry.representedObject = step.opacity as NSNumber
            entry.state = appearance.selected == step ? .on : .off
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        submenu.addItem(disabled("포인터를 올리면 원래대로 진해집니다"))
        parent.submenu = submenu
        return parent
    }

    private func addMemoList(to menu: NSMenu) {
        let memos = store.memos
        guard !memos.isEmpty else {
            menu.addItem(disabled("아직 적은 것이 없습니다"))
            return
        }

        menu.addItem(header("메모 \(memos.count)장"))
        let now = Date()
        for memo in memos.prefix(Self.listedMemoLimit) {
            menu.addItem(row(for: memo, now: now))
        }
        if memos.count > Self.listedMemoLimit {
            // 넘어간 것을 **거기서 지울 수도 있다고** 적는다. 예전에는 "찾기"
            // 라고만 해서, 아홉 번째 메모부터는 치울 길이 없는 것처럼 보였다.
            menu.addItem(disabled("… 외 \(memos.count - Self.listedMemoLimit)장 — 빠른 입력에서 찾기·지우기"))
        }
    }

    /// 목록의 한 줄. 누르면 열리고, 오른쪽 휴지통을 누르면 지워진다 (D6).
    ///
    /// 지우기를 여기 둔 것이 이 메뉴의 요점이다. 이전에는 목록에서 지울 길이
    /// 아예 없어서, 필요 없어진 메모를 치우려면 바탕화면에서 그 종이를 찾아
    /// 오른쪽 버튼을 누르고 시스템 편집 메뉴 맨 아래까지 내려가야 했다.
    private func row(for memo: Memo, now: Date) -> NSMenuItem {
        let entry = NSMenuItem(title: memo.title, action: nil, keyEquivalent: "")
        entry.view = MemoRow(
            title: memo.title,
            time: MemoTimeLabel.text(for: memo, now: now),
            color: memo.color,
            onDesktop: windows.isVisible(memo.id),
            onOpen: { [weak self] in self?.windows.reveal(memo.id) },
            onDelete: { [weak self] in self?.deleteMemo(memo.id) }
        )
        return entry
    }

    /// D6 의 되돌리기 동선. 하드 삭제 버튼은 여기에도 없다.
    ///
    /// 방금 지운 것은 **접어 두지 않는다.** 잘못 눌렀다는 것을 아는 순간은
    /// 지운 직후이고, 그때 되돌리는 길이 하위 메뉴 안에 있으면 조작이 둘로
    /// 늘어난다. 시간이 지난 것만 하위 메뉴로 내려간다.
    private func addTrashSection(to menu: NSMenu) {
        let trash = store.trash
        guard !trash.isEmpty else { return }
        menu.addItem(.separator())

        let justDeleted = trash.first.flatMap { memo -> Memo? in
            guard let deleted = memo.deleted,
                  Date().timeIntervalSince(deleted) < Self.recentDeletionWindow
            else { return nil }
            return memo
        }

        if let justDeleted {
            let undo = item(title: "「\(justDeleted.title)」 되돌리기", action: #selector(restoreMemo(_:)), key: "")
            undo.representedObject = justDeleted.id.stringValue
            undo.image = NSImage(
                systemSymbolName: "arrow.uturn.backward",
                accessibilityDescription: "되돌리기"
            )
            menu.addItem(undo)
        }

        let remaining = trash.filter { $0.id != justDeleted?.id }
        guard !remaining.isEmpty else { return }

        let parent = NSMenuItem(title: "지운 메모 \(remaining.count)장", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for memo in remaining.prefix(Self.listedTrashLimit) {
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

    /// 폴더 열기. ⌥ 를 누르면 창 레벨 스파이크로 바뀐다.
    ///
    /// 스파이크는 Stage Manager·Mission Control 에서 창이 제자리에 있는지
    /// 확인하는 개발용 통로다. 늘 보이면 "이건 뭐지" 를 남기므로 접어 둔다.
    private func addVaultItem(to menu: NSMenu) {
        menu.addItem(item(title: "메모 폴더 열기", action: #selector(openVault), key: ""))

        let spike = item(title: "바탕화면 창 스파이크", action: #selector(toggleSpike), key: "")
        spike.state = self.spike.isOpen ? .on : .off
        spike.keyEquivalentModifierMask = .option
        spike.isAlternate = true
        menu.addItem(spike)
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
        submenu.addItem(paperOpacityItem())

        submenu.addItem(.separator())
        let embed = item(title: "링크를 카드로 펼치기", action: #selector(toggleLinkEmbedding), key: "")
        embed.state = settings.current.embedsLinks ?? true ? .on : .off
        // 네트워크를 쓰는 유일한 기능이다. 켜져 있다는 사실이 보여야 한다 (§9.3).
        embed.subtitle = "제목과 그림을 가져오려고 그 주소에 접속합니다"
        submenu.addItem(embed)

        parent.submenu = submenu
        return parent
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

    @objc private func setPaperOpacity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? NSNumber else { return }
        appearance.set(value.doubleValue)
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

    /// 목록에서 지운다. 휴지통 이동뿐이고(D6), 되돌리는 길은 바로 아래 줄에 생긴다.
    private func deleteMemo(_ id: ULID) {
        Task { try? await store.delete(id) }
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
