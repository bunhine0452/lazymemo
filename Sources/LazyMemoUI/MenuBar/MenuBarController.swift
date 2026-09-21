import AppKit
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoReminders
import LazyMemoSpotlight
import LazyMemoWidgetsCore

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
    private let clipboardCapture: ClipboardCapture
    /// URL 스킴과 서비스 메뉴가 들어오는 문. `AppDelegate` 가 붙인다.
    let door: InboundDoor
    /// 아침에 종이를 놓는 시계. **기본은 꺼져 있다.**
    let brief: MorningBrief
    /// 「메모에게 묻기…」 — 비서 창을 여는 길. AppDelegate 가 모델을 만든 뒤 넣는다.
    /// `⌥⌘L` — 지금 여기.
    private let here: HereCapture
    /// 「가면 떠오른다」. **기본은 꺼져 있다.**
    let watcher: PlaceWatcher
    private let calendar: CalendarWindowController
    private let drawer: DrawerWindowController
    private let hotkey = HotkeyManager()
    private let recorder = HotkeyRecorder()
    private let settings: SettingsStore
    private let appearance: PaperAppearance
    private let mover: VaultMover
    let updater: Updater
    /// 설정에 적혀 있었지만 찾지 못한 메모 폴더 (`AppPaths.resolve`).
    /// 값이 있으면 지금 화면은 **기본 폴더**를 보고 있다는 뜻이다.
    private let missingVault: URL?
    /// 뜰 때 찾아 둔 iCloud 컨테이너 (App Store 판). 「iCloud 로 동기화 중」의 근거.
    private let cloudContainer: URL?
    private let menu = NSMenu()
    private let welcome = WelcomeWindow()

    /// 단축키 등록에 실패했는지 — 다른 앱이 같은 조합을 선점한 경우다.
    private var hotkeyAvailable = false
    /// 클립보드 즉시 메모의 조합과 그 등록 여부. 빠른 입력처럼 설정에서 바꿀 수 있다 (2026-09-17).
    private var pasteHotkey: Hotkey = .paste
    private var pasteHotkeyAvailable = false
    /// 종이 보기의 조합과 그 등록 여부 (기본 ⌥⌘P) — 바탕화면의 종이를 전부 잠깐 앞에 세운다.
    private var peekHotkey: Hotkey = .peek
    private var peekHotkeyAvailable = false

    init(
        paths: AppPaths,
        store: MemoStore,
        windows: NoteWindowManager,
        layouts: LayoutStore,
        settings: SettingsStore,
        appearance: PaperAppearance,
        missingVault: URL? = nil,
        cloudContainer: URL? = nil
    ) {
        self.paths = paths
        self.store = store
        self.windows = windows
        self.settings = settings
        self.appearance = appearance
        self.missingVault = missingVault
        self.cloudContainer = cloudContainer
        self.mover = VaultMover(
            paths: paths, settings: settings, cloudContainer: cloudContainer,
            // 옮기기 전에 적던 글을 전부 내린다 — 옮기고 나면 옛 자리는 없다.
            flush: { [weak windows] in await windows?.flushAll() }
        )
        self.updater = Updater(settings: settings)
        self.brief = MorningBrief(store: store, settings: settings, windows: windows)
        self.capture = QuickCaptureController(
            store: store, windows: windows,
            // 적던 글은 앱이 죽어도 남는다 — 판을 갈 때 앱이 스스로 닫혔다 뜨므로
            // 여기 없으면 「새 판으로 바꾸기」가 초안을 지우는 버튼이 된다.
            draft: CaptureDraftStore(location: paths.captureDraft),
            settings: settings
        )
        let door = InboundDoor(store: store, windows: windows)
        self.door = door
        self.clipboardCapture = ClipboardCapture(store: store, windows: windows, door: door)
        self.here = HereCapture(door: door)
        self.watcher = PlaceWatcher(store: store, settings: settings)
        self.calendar = CalendarWindowController(
            store: store, layouts: layouts, settings: settings,
            // 달력에서 줄을 누르는 것은 **보는 일**이다. 자리는 그대로 달력에
            // 둔다 — 안 그러면 읽으려는 클릭 한 번이 그 일정을 영영 바탕화면의
            // 종이로 만든다 (§7.2 의 예외에 걸린다).
            onSelectMemo: { [weak windows] id in windows?.reveal(id, keepingPlace: true) }
        )
        // 서랍은 밀어 둔 종이가 가는 자리다 (`DrawerContents`). 창 관리자를
        // 그대로 받는다 — 넣고 꺼내는 것이 전부 종이 창을 여닫는 일이라,
        // 서랍이 좌표 파일을 따로 만지면 규칙이 두 곳에 살게 된다.
        self.drawer = DrawerWindowController(
            store: store, layouts: layouts, windows: windows, settings: settings
        )
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // 종이의 우클릭 메뉴가 「폴더에 넣기」를 적을 때 폴더 이름은 서랍이 안다.
        windows.folderNames = { [weak self] in self?.drawer.model.folders ?? [] }

        configureButton()
        menu.delegate = self

        // 켜져 있으면 뜨자마자 한 번 물어본다. **결과는 창이 아니라 메뉴에 있다** —
        // 사용자가 메뉴를 열었을 때 거기 있으면 된다 (철학 4).
        Task { [updater] in await updater.check() }

        // 도착하면 그 종이가 나온다 — `DueClock` 과 같은 길이다 (시스템 알림 아님).
        watcher.onArrival = { [weak windows] id in windows?.surface(id) }
        watcher.start()

        // 말풍선은 아이콘 밑에 매달린다. 아이콘 자리는 여기만 알고 있고,
        // 메뉴바가 붐비면 숨겨져 자리가 없을 수도 있다.
        capture.anchorProvider = { [weak self] in self?.statusItemFrame() }

        // 날짜를 적었으면 그것은 일정이다 — 종이가 아니라 달력이 받는다 (§7.2).
        capture.onScheduled = { [weak self] day in self?.calendar.announce(day) }
        clipboardCapture.onScheduled = { [weak self] day in self?.calendar.announce(day) }
        door.onScheduled = { [weak self] day in self?.calendar.announce(day) }
        // 서비스 메뉴·URL 로 들어온 약속에 자리가 있으면 상자가 가는 길을 묻는다 — 상자에서 적었을 때와 같다.
        door.onRouteAsk = { [weak self] memo in self?.capture.askRoute(memo) }

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
        hotkeyAvailable = hotkey.register(id: 1, storedHotkey()) { [weak self] in
            self?.capture.toggle()
        }
        pasteHotkey = storedPasteHotkey()
        pasteHotkeyAvailable = hotkey.register(id: Self.pasteHotkeyID, pasteHotkey) { [weak self] in
            Task { await self?.clipboardCapture.capture() }
        }
        hotkey.register(id: 3, .here) { [weak self] in
            Task { await self?.here.capture() }
        }
        peekHotkey = storedPeekHotkey()
        peekHotkeyAvailable = hotkey.register(id: Self.peekHotkeyID, peekHotkey) { [weak self] in
            self?.peekPapers()
        }
    }

    private static let pasteHotkeyID: UInt32 = 2
    private static let peekHotkeyID: UInt32 = 4

    /// 설정에 남은 조합. 없으면 기본값.
    private func storedHotkey() -> Hotkey {
        let saved = settings.current
        guard let keyCode = saved.hotkeyKeyCode, let modifiers = saved.hotkeyModifiers
        else { return .standard }
        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }

    private func storedPasteHotkey() -> Hotkey {
        let saved = settings.current
        guard let keyCode = saved.pasteHotkeyKeyCode, let modifiers = saved.pasteHotkeyModifiers
        else { return .paste }
        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }

    private func storedPeekHotkey() -> Hotkey {
        let saved = settings.current
        guard let keyCode = saved.peekHotkeyKeyCode, let modifiers = saved.peekHotkeyModifiers
        else { return .peek }
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

    /// 껐다 켜도 서랍은 놓아 둔 자리에 그대로 있다.
    func restoreDrawer() { drawer.restoreIfWasVisible() }

    func openDrawer() { drawer.open() }

    /// 서랍이 실제 창에서 약속대로 자라고 접히는가 (`verify-drawer.sh`).
    func drawerDiagnostics() async -> String { await drawer.diagnostics() }
    /// 메뉴바 「서랍」과 같은 길로 펼친 채 앞으로 (`verify-drawer-mouse.sh`).
    func summonDrawerForVerification() { drawer.summon() }

    /// 소개 영상 주행 (`scripts/record-demo.sh`). 창들은 여기만 들고 있으므로 여기서 짓는다.
    func demoTour(in region: CGRect, layouts: LayoutStore) -> DemoTour {
        DemoTour(
            region: region, store: store, layouts: layouts, settings: settings,
            windows: windows, capture: capture, calendar: calendar, drawer: drawer
        )
    }

    /// 하루가 바뀌었다 (`DayClock`). 달력 창은 여기만 들고 있다.
    func dayChanged(to day: CalendarDate) { calendar.dayChanged(to: day) }

    /// 성능 예산 측정용 진입점 (`scripts/measure-capture.sh`).
    var captureLatency: Duration? { capture.lastLatency }

    func showCaptureForMeasurement() {
        capture.show()
    }

    /// 위젯의 「적기」— 빠른 입력 상자를 연다. 단축키를 누른 것과 같다.
    func showCapture() { capture.show() }

    func closeCapture() { capture.close(returningFocus: false) }
    /// 이 기기의 비서를 빠른 입력 상자에 끼운다.
    func adoptAssistant(_ assistant: AssistantModel?) {
        self.assistant = assistant
        capture.adoptAssistant(assistant)
    }
    /// 설정의 「종이에서 Claude 부르기」가 바뀌면 비서에게도 같은 것을 건네야 한다 (`setUsesClaude`).
    private var assistant: AssistantModel?
    /// 「이 메모에게 시키기…」 — 그 메모를 대상으로 빠른 입력 상자를 연다.
    func showCapture(target: ULID) { capture.show(target: target) }

    /// 종료 직전 — 빠른 입력이 들고 있던 글을 파일에 남긴다.
    func flushCaptureDraft() { capture.flushDraft() }

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

    /// `verify-capture-paste.sh` 가 읽는 진단 — 사람이 쓰는 클립보드에 사진을
    /// 올려 두고 ⌘V 를 **앱 전체 이벤트 길로** 흘려보낸다.
    func capturePasteReach() async -> String { await capture.pasteReach() }

    /// `LAZYMEMO_MENU=1` 이 읽는 진단 — 메뉴를 실제로 한 번 지어 항목을 적는다.
    ///
    /// 메뉴는 시스템이 띄우는 창이라 렌더로도 캡처로도 잡히지 않는다. 줄이
    /// 뷰(`MemoRow`)로 바뀐 뒤로는 "메뉴가 아예 안 지어진다" 는 종류의 고장이
    /// 가능해졌으므로, 짓는 것까지만이라도 눈으로 확인할 통로를 둔다.
    var menuDiagnostics: String {
        menuNeedsUpdate(menu)
        return Self.describe(menu.items, indent: "  ")
    }

    /// 하위 메뉴(설정)까지 들여쓰기로 적는다 — 스토어 판에 Claude·업데이트 줄이
    /// 없는 것, 메모 폴더가 어디인지가 전부 그 안에 있다.
    private static func describe(_ items: [NSMenuItem], indent: String) -> String {
        items.map { entry in
            if entry.isSeparatorItem { return "\(indent)──────" }
            let mark = entry.view is MemoRow ? "▪︎" : (entry.isAlternate ? "⌥" : "·")
            let key = entry.keyEquivalent.isEmpty ? "" : "  [\(entry.keyEquivalent)]"
            let subtitle = entry.subtitle.map { "  (\($0))" } ?? ""
            let line = "\(indent)\(mark) \(entry.title)\(key)\(subtitle)"
            guard let submenu = entry.submenu else { return line }
            return line + "\n" + describe(submenu.items, indent: indent + "    ")
        }.joined(separator: "\n")
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.menuBarIcon()
        button.toolTip = L("lazymemo — \(hotkey.current.displayName) 로 빠른 입력")
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
        menu.addItem(clipboardCaptureItem())
        if !hotkeyAvailable {
            menu.addItem(disabled(L("⚠︎ \(hotkey.current.displayName) 을 다른 앱이 쓰고 있습니다")))
        }
        if !pasteHotkeyAvailable {
            menu.addItem(disabled(L("⚠︎ \(pasteHotkey.displayName) 을 다른 앱이 쓰고 있습니다")))
        }
        addMissingVaultLine(to: menu)
        addTroubleLine(to: menu)
        menu.addItem(item(title: L("빈 종이 꺼내기"), action: #selector(newMemo), key: ""))
        menu.addItem(peekItem())
        if !peekHotkeyAvailable {
            menu.addItem(disabled(L("⚠︎ \(peekHotkey.displayName) 을 다른 앱이 쓰고 있습니다")))
        }
        menu.addItem(.separator())

        let calendarItem = item(title: L("달력"), action: #selector(toggleCalendar), key: "")
        calendarItem.state = calendar.isOpen ? .on : .off
        menu.addItem(calendarItem)

        // 「서랍」은 **펼친 채 앞으로 부른다** (`DrawerWindowController.summon`).
        // 바탕화면에서 치우는 것은 그 아래 한 줄 — ⌥ 뒤에 숨겨 두었더니 「서랍」이
        // 상주 스위치이던 앞선 판의 손버릇으로 「서랍이 사라지지 않는다」가 됐다
        // (2026-09-17, 사용자). 되돌리는 길은 보여야 한다 (HIG Undo).
        let drawerItem = item(title: L("서랍"), action: #selector(summonDrawer), key: "")
        drawerItem.state = drawer.isVisible ? .on : .off
        drawerItem.toolTip = L("밀어 둔 종이가 모이는 자리 — 펼쳐서 앞으로 부릅니다")
        menu.addItem(drawerItem)
        let drawerToggle = item(
            title: drawer.isVisible ? L("서랍 치우기 — 바탕화면에서") : L("서랍 내놓기 — 바탕화면에"),
            action: #selector(toggleDrawer), key: ""
        )
        drawerToggle.indentationLevel = 1
        menu.addItem(drawerToggle)
        menu.addItem(.separator())

        addSummaryLine(to: menu)
        addMemoList(to: menu)
        addTidiedSection(to: menu)
        addArchivedSection(to: menu)
        addTrashSection(to: menu)

        menu.addItem(.separator())
        addUpdateLine(to: menu)
        menu.addItem(settingsItem())
        menu.addItem(item(title: L("시작하기 및 사용 안내…"), action: #selector(showWelcome), key: ""))
        addVaultItem(to: menu)
        menu.addItem(.separator())
        menu.addItem(item(title: L("lazymemo 종료"), action: #selector(quit), key: "q"))
    }

    /// 저장이나 읽기가 실패했다는 것을 **머리에서 말한다** (§6 의 연장).
    ///
    /// 저장 버튼이 없는 앱에서 실패가 화면에 안 나오면 사용자는 영영 모른다 —
    /// 종이에 글은 그대로 있으니 적힌 줄 알고, 껐다 켠 뒤에야 사라진 것을 안다.
    /// 그래서 목록보다 **위**에 둔다. 아래에 두면 메모 여덟 줄에 밀려 안 읽힌다.
    ///
    /// 기계의 말은 도움말로만 보인다. 메뉴에 Swift 오류 문자열이 떠 있으면
    /// 그건 이 앱의 화면이 아니다.
    private func addTroubleLine(to menu: NSMenu) {
        guard let trouble = store.trouble else { return }
        let line = disabled("⚠︎ \(trouble.doing)")
        line.toolTip = trouble.detail
        menu.addItem(line)
    }

    /// 옮겨 둔 메모 폴더를 못 찾았다 (`AppPaths.resolve`).
    ///
    /// 이때 화면에 서 있는 것은 **기본 폴더의 메모**다 — 대개 한 장도 없다.
    /// 조용히 되돌아가면 사용자가 보는 것은 "메모가 전부 사라졌다" 이고,
    /// 그 순간 이 앱은 믿을 수 없는 앱이 된다. 외장 디스크를 안 꽂았거나
    /// iCloud 가 아직 안 내려왔을 뿐일 수도 있으므로 설정을 지우지도 않는다.
    private func addMissingVaultLine(to menu: NSMenu) {
        guard let missingVault else { return }
        let line = disabled(L("⚠︎ 옮겨 둔 메모 폴더를 찾지 못했습니다"))
        line.toolTip = "\(missingVault.path(percentEncoded: false))\n"
            + L("지금은 기본 폴더를 쓰고 있습니다. 그 자리가 돌아오면 다시 그리로 갑니다.")
        menu.addItem(line)
    }

    /// 이 앱의 머리 동작. 단축키를 **오른쪽에 적어 둔다** — 메뉴를 여는 사람은
    /// 대개 단축키를 모르는 사람이고, 알고 나면 다시는 메뉴를 열지 않는다.
    private func captureItem() -> NSMenuItem {
        let entry = item(title: L("빠른 입력"), action: #selector(openCapture), key: "")
        if let (key, modifiers) = hotkey.current.menuKeyEquivalent {
            entry.keyEquivalent = key
            entry.keyEquivalentModifierMask = modifiers
        }
        return entry
    }

    /// 클립보드 원키 즉시 캡처 (기본 ⌥⌘V). 조합은 설정에서 바꿀 수 있으니 여기서도 지금 것을 적는다.
    private func clipboardCaptureItem() -> NSMenuItem {
        let entry = item(title: L("클립보드 즉시 메모"), action: #selector(captureClipboard), key: "")
        if let (key, modifiers) = pasteHotkey.menuKeyEquivalent {
            entry.keyEquivalent = key
            entry.keyEquivalentModifierMask = modifiers
        }
        entry.toolTip = L("복사한 글이나 사진을 창 없이 즉시 메모로 저장합니다")
        return entry
    }

    /// 종이 보기 (기본 ⌥⌘P) — 다른 창 뒤에 눕는 종이를 전부 잠깐 앞에 세운다 (`NoteWindowManager.peek`).
    private func peekItem() -> NSMenuItem {
        let entry = item(title: L("종이 보기"), action: #selector(peekPapers), key: "")
        if let (key, modifiers) = peekHotkey.menuKeyEquivalent {
            entry.keyEquivalent = key
            entry.keyEquivalentModifierMask = modifiers
        }
        entry.toolTip = L("바탕화면의 종이를 전부 잠깐 앞에 세웁니다 — 다시 누르면 내려앉습니다")
        return entry
    }

    @objc private func peekPapers() {
        windows.peek()
    }

    /// 종이가 얼마나 비치는가 (§14.5 의 예외).
    ///
    /// 단계를 네 칸으로 끊는다 — 슬라이더는 조준해서 끌어야 하는 물건이고,
    /// 메뉴 안에서는 더 그렇다.
    /// 「놓친 2장 · 오늘 3장 · 나중에 5장」 — 세 장이 전부가 아니라는 것을 **조용히** 말하는 한 줄
    /// (인계서 묶음 4 `#unfinished-recall`). 푸시는 없다. 놓친 것은 하위 메뉴에서 열고·끝내고·보관하고·미룬다.
    ///
    /// `Recall.summary` 가 정한다 — 폰의 「지금」 띠 밑의 요약과 같은 셈이라 두 기기가 같은 수를 말한다.
    /// 「봤어요」로 내려놓은 등장은 이 기기의 기억(`NowSeen`)이라 여기서만 빠진다 — 그것은 완료가 아니다.
    private func addSummaryLine(to menu: NSMenu) {
        let summary = Recall.summary(store.memos, seen: NowSeen.load())
        guard !summary.isEmpty else { return }

        var parts: [String] = []
        if !summary.missed.isEmpty { parts.append(L("놓친 \(summary.missed.count)장")) }
        if !summary.today.isEmpty { parts.append(L("오늘 \(summary.today.count)장")) }
        if !summary.later.isEmpty { parts.append(L("나중에 \(summary.later.count)장")) }
        let line = NSMenuItem(title: parts.joined(separator: " · "), action: nil, keyEquivalent: "")
        line.toolTip = L("놓친 것은 지난 날에 다시 보기로 했거나 시각이 적혀 있었는데 끝내지 않은 것 · 마감이 지난 칸 남은 목록")

        guard !summary.missed.isEmpty else {
            line.isEnabled = false
            menu.addItem(line)
            return
        }
        let submenu = NSMenu()
        let now = Date()
        for memo in summary.missed.prefix(Self.listedTrashLimit) {
            submenu.addItem(missedRow(memo, now: now))
        }
        if summary.missed.count > Self.listedTrashLimit {
            submenu.addItem(disabled(L("… 외 \(summary.missed.count - Self.listedTrashLimit)장 — 빠른 입력에서 찾기")))
        }
        line.submenu = submenu
        menu.addItem(line)
    }

    /// 놓친 것 한 줄 — 제목·언제, 그 아래 네 손: 열기 · 완료 · 보관 · 내일 아침으로.
    private func missedRow(_ memo: Memo, now: Date) -> NSMenuItem {
        let when = memo.surface.map { MemoTimeLabel.elapsed($0, now: now) } ?? MemoTimeLabel.text(for: memo, now: now)
        let parent = NSMenuItem(title: "\(memo.title) · \(when)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (title, action, hint) in [
            (L("열기"), #selector(openMemo(_:)), L("종이를 앞으로")),
            (L("완료"), #selector(markDone(_:)), L("끝냈다고 적습니다 — 되돌릴 수 있고, 사흘 뒤 물러납니다")),
            (L("보관"), #selector(archiveMemo(_:)), L("당장 안 볼 기록으로 — 검색하면 나옵니다")),
            (L("내일 아침으로"), #selector(postponeToMorning(_:)), L("내일 아침 9시에 다시 봅니다 — 일정은 그대로")),
        ] {
            let entry = item(title: title, action: action, key: "")
            entry.representedObject = memo.id.stringValue
            entry.toolTip = hint
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    /// 사람이 넣어 둔 것 (`Memo.archived`) — 완료도 삭제도 아니고, 검색하면 나온다. 하나씩 꺼낸다.
    private func addArchivedSection(to menu: NSMenu) {
        let archived = store.archivedMemos
        guard !archived.isEmpty else { return }
        menu.addItem(.separator())
        let parent = NSMenuItem(title: L("보관한 \(archived.count)장"), action: nil, keyEquivalent: "")
        parent.toolTip = L("당장 안 볼 기록 — 지운 것도 끝낸 것도 아닙니다. 검색하면 나옵니다")
        parent.submenu = restoreSubmenu(archived, action: #selector(unarchiveMemo(_:)), hint: L("보관에서 꺼내기"))
        menu.addItem(parent)
    }

    /// 하나씩 되돌리는 하위 메뉴 — 줄을 누르면 그 한 장만 도로 나온다.
    private func restoreSubmenu(_ memos: [Memo], action: Selector, hint: String) -> NSMenu {
        let submenu = NSMenu()
        for memo in memos.prefix(Self.listedTrashLimit) {
            let entry = item(title: memo.title, action: action, key: "")
            entry.representedObject = memo.id.stringValue
            entry.toolTip = hint
            submenu.addItem(entry)
        }
        if memos.count > Self.listedTrashLimit {
            submenu.addItem(disabled(L("… 외 \(memos.count - Self.listedTrashLimit)장 — 빠른 입력에서 찾기")))
        }
        return submenu
    }

    private func addMemoList(to menu: NSMenu) {
        // 치워 둔 것은 여기 오지 않는다 (`Tidy`). 바로 아래 줄이 몇 장인지
        // 적고 한 번에 도로 꺼낸다 — 안 적으면 그건 삭제로 읽힌다.
        let memos = store.active
        guard !memos.isEmpty else {
            menu.addItem(disabled(L("아직 적은 것이 없습니다")))
            return
        }

        menu.addItem(header(L("메모 \(memos.count)장")))
        let now = Date()
        for memo in memos.prefix(Self.listedMemoLimit) {
            menu.addItem(row(for: memo, now: now))
        }
        if memos.count > Self.listedMemoLimit {
            // 넘어간 것을 **거기서 지울 수도 있다고** 적는다. 예전에는 "찾기"
            // 라고만 해서, 아홉 번째 메모부터는 치울 길이 없는 것처럼 보였다.
            menu.addItem(disabled(L("… 외 \(memos.count - Self.listedMemoLimit)장 — 빠른 입력에서 찾기·지우기")))
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

    /// 스스로 물러난 것을 **세어서 적고, 한 번에 도로 꺼낸다**
    /// (`{#tidy-visible-undo}`).
    ///
    /// 이 줄이 이 기능의 절반이다. 다 체크한 목록과 지난 일정이 조용히
    /// 목록에서 빠지기만 하면, 사람은 그것을 「정리됐다」가 아니라
    /// 「없어졌다」로 읽는다 — 그리고 없어지는 앱에는 아무것도 안 적는다.
    /// 그래서 몇 장인지, 왜 물러났는지, 어떻게 도로 꺼내는지를 **한 자리**에
    /// 적는다.
    ///
    /// 하나씩 꺼내는 길은 오랫동안 없었다 — 빠른 입력에서 찾아 열면 그 자리에서 도로 꺼내지므로
    /// (`NoteWindowManager.reveal`). 그런데 「도로 꺼내기」 한 번은 **전부**를 세우고, 도로 꺼낸 것은
    /// 규칙이 다시 못 치우므로(`Memo.kept`), 두 장을 보려던 손이 열 장을 영영 세우는 셈이 됐다.
    /// 그래서 이제 하위 메뉴에서 한 장씩 꺼낸다 (인계서 §4 「개별 복원 경로」). 전부 꺼내는 줄은 그대로 있다.
    private func addTidiedSection(to menu: NSMenu) {
        let tidied = store.tidiedMemos
        guard !tidied.isEmpty else { return }
        menu.addItem(.separator())

        menu.addItem(header(L("치워 둔 \(tidied.count)장 — \(Self.tidiedReasons(tidied))")))

        let each = NSMenuItem(title: L("하나씩 꺼내기"), action: nil, keyEquivalent: "")
        each.submenu = restoreSubmenu(tidied, action: #selector(restoreTidiedOne(_:)), hint: L("이 한 장만 도로 꺼냅니다"))
        menu.addItem(each)

        let restore = item(title: L("도로 꺼내기"), action: #selector(restoreTidied), key: "")
        restore.image = NSImage(
            systemSymbolName: "tray.and.arrow.up", accessibilityDescription: L("도로 꺼내기")
        )
        restore.toolTip = L("지운 것이 아닙니다 — 찾으면 그대로 나오고, 열면 도로 나옵니다")
        menu.addItem(restore)
    }

    /// 무엇이 물러났는지 **낱말로** 적는다. "치워 둔 3장" 만으로는 사람이
    /// 무엇을 잃었는지 짐작할 수 없어서 결국 눌러 봐야 한다.
    private static func tidiedReasons(_ memos: [Memo], now: Date = Date()) -> String {
        // 이미 치운 메모는 `Tidy.reason` 이 nil 을 주므로(두 번 치울 것이
        // 없다), 물러난 까닭은 치우기 **전의 모습**으로 되물어야 한다.
        var asked = memos.map { memo -> Memo in
            var before = memo
            before.tidied = nil
            return before
        }
        asked = asked.filter { Tidy.reason(for: $0, now: now) != nil }

        let reasons = Tidy.Reason.allCases.filter { reason in
            asked.contains { Tidy.reason(for: $0, now: now) == reason }
        }
        guard !reasons.isEmpty else { return L("다 끝난 것") }
        return reasons.map(\.label).joined(separator: "·")
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
        addConflictSection(to: menu)

        // 다른 기기의 판은 위에서 따로 셌다 — 「방금 지운 것」은 사람이 지운 것이어야 한다.
        let conflictIDs = Set(store.conflicts.map(\.id))
        let justDeleted = trash.first { !conflictIDs.contains($0.id) }.flatMap { memo -> Memo? in
            guard let deleted = memo.deleted,
                  Date().timeIntervalSince(deleted) < Self.recentDeletionWindow
            else { return nil }
            return memo
        }

        if let justDeleted {
            let undo = item(title: L("「\(justDeleted.title)」 되돌리기"), action: #selector(restoreMemo(_:)), key: "")
            undo.representedObject = justDeleted.id.stringValue
            undo.image = NSImage(
                systemSymbolName: "arrow.uturn.backward",
                accessibilityDescription: L("되돌리기")
            )
            menu.addItem(undo)
        }

        let remaining = trash.filter { $0.id != justDeleted?.id && !conflictIDs.contains($0.id) }
        guard !remaining.isEmpty else { return }

        let parent = NSMenuItem(title: L("지운 메모 \(remaining.count)장"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for memo in remaining.prefix(Self.listedTrashLimit) {
            let entry = item(title: memo.title, action: #selector(restoreMemo(_:)), key: "")
            entry.representedObject = memo.id.stringValue
            entry.toolTip = L("되돌리기")
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        submenu.addItem(disabled(L("30일 뒤 자동으로 지워집니다")))
        parent.submenu = submenu
        menu.addItem(parent)
    }

    /// 두 기기가 따로 고쳐 만난 것 — 앱이 늦은 판을 자리에 두고 진 판을 휴지통에 앉혔다
    /// (`ConflictSettlement`). **그 사실을 사람에게 말하는 자리가 여기다.** 지운 메모 사이에 섞이면
    /// 사람은 그런 일이 있었는지 모르고, 폰의 오타 하나가 맥의 한 시간을 조용히 이긴 채로 남는다.
    ///
    /// 한 장마다 둘 중 하나 — **이 판으로**(자리의 글과 맞바꾼다, 밀려난 글은 여기 남는다) ·
    /// **둘 다 남기기**(되돌려서 나란히 둔다). 어느 쪽도 글을 없애지 않으니 틀려도 한 번 더 고르면 된다.
    /// 견줄 글은 도움말(툴팁)에 — 자리의 글과 다른 판의 첫 줄.
    private func addConflictSection(to menu: NSMenu) {
        let conflicts = store.conflicts
        guard !conflicts.isEmpty else { return }

        menu.addItem(header(L("다른 기기의 판 \(conflicts.count)장 — 따로 고친 글이 만났습니다")))
        for loser in conflicts.prefix(Self.listedTrashLimit) {
            guard let winner = loser.conflictOf.flatMap(store.memo) else { continue }
            let parent = NSMenuItem(title: L("「\(winner.title)」의 다른 판"), action: nil, keyEquivalent: "")
            parent.toolTip = Self.conflictPreview(winner: winner, loser: loser)
            let submenu = NSMenu()
            submenu.addItem(disabled(L("지금 자리: \(Self.firstLine(winner))")))
            submenu.addItem(disabled(L("다른 판: \(Self.firstLine(loser))")))
            submenu.addItem(.separator())
            let adopt = item(title: L("이 판으로"), action: #selector(adoptConflict(_:)), key: "")
            adopt.representedObject = loser.id.stringValue
            adopt.toolTip = L("자리의 글과 맞바꿉니다 — 밀려난 글은 여기 남아 한 번 더 바꿀 수 있습니다")
            submenu.addItem(adopt)
            let both = item(title: L("둘 다 남기기"), action: #selector(restoreMemo(_:)), key: "")
            both.representedObject = loser.id.stringValue
            both.toolTip = L("되돌려서 나란히 둡니다 — 나중에 합치거나 하나를 지웁니다")
            submenu.addItem(both)
            parent.submenu = submenu
            menu.addItem(parent)
        }
    }

    /// 견줄 두 글 — 자리의 것과 다른 판의 것. 긴 글은 첫 여섯 줄만.
    nonisolated static func conflictPreview(winner: Memo, loser: Memo) -> String {
        let head = { (memo: Memo) -> String in
            memo.body.split(separator: "\n", omittingEmptySubsequences: false).prefix(6).joined(separator: "\n")
        }
        return L("지금 자리\n\(head(winner))\n\n다른 판\n\(head(loser))")
    }

    private nonisolated static func firstLine(_ memo: Memo) -> String {
        let line = memo.title
        return line.count > 40 ? String(line.prefix(40)) + "…" : line
    }

    /// 폴더 열기. ⌥ 를 누르면 창 레벨 스파이크로 바뀐다.
    ///
    /// 스파이크는 Stage Manager·Mission Control 에서 창이 제자리에 있는지
    /// 확인하는 개발용 통로다. 늘 보이면 "이건 뭐지" 를 남기므로 접어 두고,
    /// 스토어 판에는 아예 없다 — 심사자가 ⌥ 를 누른 채 메뉴를 열어도 시험 창이 뜨면 안 된다.
    private func addVaultItem(to menu: NSMenu) {
        menu.addItem(item(title: L("메모 폴더 열기"), action: #selector(openVault), key: ""))
        guard !updater.source.isAppStore else { return }

        let spike = item(title: L("바탕화면 창 스파이크"), action: #selector(toggleSpike), key: "")
        spike.state = self.spike.isOpen ? .on : .off
        spike.keyEquivalentModifierMask = .option
        spike.isAlternate = true
        menu.addItem(spike)
    }

    /// 업데이트 한 줄.
    ///
    /// **새 판이 있을 때만 눈에 띈다.** 최신이면 «확인» 한 줄로 접히고, 개발 중
    /// (`swift run`)에는 아예 없다 — 바꿀 번들이 없는데 바꾸자고 하면 안 된다.
    ///
    /// Homebrew 로 깔린 앱은 스스로 바꾸지 않는다. 대신 **명령을 복사해 준다** —
    /// 터미널에 무엇을 쳐야 하는지 외우게 하지 않는다.
    private func addUpdateLine(to menu: NSMenu) {
        guard updater.source.allowsExternalUpdates else { return }

        switch updater.state {
        case .found(let release):
            let line: NSMenuItem
            if updater.source == .homebrew {
                line = item(title: L("새 판 \(release.version) 이 있습니다"), action: #selector(copyBrewCommand), key: "")
                line.subtitle = L("눌러서 `brew upgrade --cask lazymemo` 복사")
            } else {
                line = item(title: L("새 판 \(release.version) 으로 바꾸기"), action: #selector(installUpdate), key: "")
                line.subtitle = L("받아서 바꾸고 다시 엽니다")
            }
            menu.addItem(line)

        case .installing:
            menu.addItem(disabled(L("새 판을 받는 중입니다…")))

        case .checking:
            menu.addItem(disabled(L("새 판이 있는지 보는 중…")))

        case .failed(let reason):
            let line = item(title: L("업데이트 확인"), action: #selector(checkForUpdates), key: "")
            line.subtitle = reason
            menu.addItem(line)

        case .idle, .upToDate:
            let line = item(title: L("업데이트 확인"), action: #selector(checkForUpdates), key: "")
            line.subtitle = updater.state == .upToDate
                ? L("\(LazyMemo.version) — 최신입니다")
                : L("지금은 \(LazyMemo.version)")
            menu.addItem(line)
        }
    }

    /// 「설정…」 — 창을 연다 (`SettingsWindow`), ⌘, 로.
    ///
    /// 앞선 판은 하위 메뉴였다 — 항목이 몇 개뿐이라던 때의 결정인데, 열넷이 되고 설명이 두 줄씩
    /// 붙으니 메뉴가 화면 반을 차지했다. HIG Settings(macOS): "When people choose the Settings
    /// item … your custom settings window opens" · "Command-Comma".
    private func settingsItem() -> NSMenuItem {
        let entry = item(title: L("설정…"), action: #selector(showSettings), key: ",")
        entry.keyEquivalentModifierMask = .command
        return entry
    }

    @objc private func showSettings() { SettingsWindow.show(settingsScreen) }
    /// 검증 주행이 창을 열고 그림으로 남긴다 (`LAZYMEMO_SETTINGS`).
    func openSettingsForVerification() { showSettings() }

    /// 설정 창의 모델 — 사진을 찍는 법과 단추들을 넘긴다. 하는 일은 전부 여기 있던 것이다.
    private lazy var settingsScreen: SettingsScreenModel = {
        // 설정 창에서 단축키를 바꾼 뒤에는 그 창으로 돌아간다 (`HotkeyRecorder.keepsAppActive`).
        recorder.keepsAppActive = { SettingsWindow.isOpen }
        return SettingsScreenModel(
            snapshot: { [unowned self] in settingsSnapshot() },
            actions: settingsActions()
        )
    }()

    private func settingsSnapshot() -> SettingsState {
        var claude: SettingsState.Claude?
        // `claude` 가 없으면 이 절도 없다 — 없는 사람에게는 존재하지 않는 기능이다. App Store 판에는 아예 없다 (`ClaudeSupport`).
        if !updater.source.isAppStore, windows.claude != nil || settings.current.claudePath != nil {
            claude = .init(usesClaude: settings.current.usesClaude ?? true, morningBrief: brief.isEnabled)
        }
        var updates: SettingsState.Updates?
        if updater.source.allowsExternalUpdates {
            let line: String
            var action: String?
            switch updater.state {
            case .found(let release):
                line = L("새 판 \(release.version) 이 있습니다")
                action = updater.source == .homebrew ? L("brew 명령 복사") : L("\(release.version) 으로 바꾸기")
            case .installing: line = L("새 판을 받는 중입니다…")
            case .checking: line = L("새 판이 있는지 보는 중…")
            case .failed(let reason): line = reason
            case .upToDate: line = L("\(LazyMemo.version) — 최신입니다")
            case .idle: line = LazyMemo.version
            }
            updates = .init(checks: updater.isEnabled, line: line, action: action)
        }
        return SettingsState(
            capture: .init(name: hotkey.current.displayName, taken: !hotkeyAvailable),
            paste: .init(name: pasteHotkey.displayName, taken: !pasteHotkeyAvailable),
            peek: .init(name: peekHotkey.displayName, taken: !peekHotkeyAvailable),
            loginEnabled: LoginItem.isEnabled, loginAvailable: LoginItem.isAvailable,
            opacity: appearance.selected?.opacity ?? 1,
            embedsLinks: settings.current.embedsLinks ?? true,
            vaultPath: shortVaultPath, cloud: .init(syncing: isSyncingWithCloud),
            watchesPlaces: watcher.isEnabled, placesNote: watcher.note,
            hereNote: HereCapture.access.note,
            asksRoutes: settings.current.asksRoutes ?? true,
            showsSystemEvents: settings.current.showsSystemEvents ?? true,
            eventsNote: EventKitFeed.access.note,
            spotlight: SpotlightCenter.shared.enabled, spotlightTrouble: SpotlightCenter.shared.trouble,
            remindersOn: ReminderCenter.shared.enabled && !ReminderCenter.shared.denied,
            claude: claude, updates: updates
        )
    }

    private func settingsActions() -> SettingsActions {
        var actions = SettingsActions()
        actions.changeCaptureShortcut = { [weak self] in self?.changeHotkey() }
        actions.changePasteShortcut = { [weak self] in self?.changePasteHotkey() }
        actions.changePeekShortcut = { [weak self] in self?.changePeekHotkey() }
        actions.setLogin = { LoginItem.set($0) }
        actions.setOpacity = { [weak self] in self?.appearance.set($0) }
        actions.setEmbedsLinks = { [weak self] on in self?.settings.update { $0.embedsLinks = on } }
        actions.moveVault = { [weak self] in self?.mover.begin() }
        actions.openVault = { [weak self] in self?.openVault() }
        actions.syncToCloud = { [weak self] in self?.mover.beginCloud() }
        actions.setWatchesPlaces = { [weak self] in self?.watcher.setEnabled($0) }
        actions.setAsksRoutes = { [weak self] on in self?.settings.update { $0.asksRoutes = on } }
        actions.setShowsSystemEvents = { [weak self] on in self?.settings.update { $0.showsSystemEvents = on } }
        actions.setSpotlight = { SpotlightCenter.shared.setEnabled($0) }
        actions.showReminders = { [weak self] in self?.showReminders() }
        actions.setUsesClaude = { [weak self] on in self?.setUsesClaude(on) }
        actions.setMorningBrief = { [weak self] in self?.brief.setEnabled($0) }
        actions.setChecksUpdates = { [weak self] in self?.updater.setEnabled($0) }
        actions.checkUpdates = { [weak self] in self?.checkForUpdates() }
        actions.takeUpdate = { [weak self] in
            guard let self else { return }
            if updater.source == .homebrew { copyBrewCommand() } else { installUpdate() }
        }
        return actions
    }

    /// 이미 iCloud 의 폴더를 보고 있는가. 샌드박스 안에서는 `NSHomeDirectory()` 가 컨테이너라
    /// 디스크의 폴더를 못 찾는다 — 뜰 때 iCloud 에 직접 물어 둔 것이 먼저다.
    private var isSyncingWithCloud: Bool {
        let container = cloudContainer ?? AppPaths.cloudContainerOnDisk()
        return container.map({ AppPaths.cloudVault(inContainer: $0) })
            .map({ $0.standardizedFileURL.path(percentEncoded: false) })
            == paths.vault.standardizedFileURL.path(percentEncoded: false)
    }

    /// 이 기기의 알림 — 켜기 전에 잠금 화면 표시와 기기별 동의를 읽는 창 (`ReminderSettingsView`).
    @objc private func showReminders() { RecallWindow.settings() }

    /// 홈 아래는 `~` 로 줄인다. 한 줄에 전체 경로는 안 들어간다.
    private var shortVaultPath: String { VaultLabel.readable(paths.vault) }

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

    @objc func showWelcome() {
        welcome.show(
            shortcuts: WelcomeShortcuts(
                capture: hotkey.current.displayName, paste: pasteHotkey.displayName, peek: peekHotkey.displayName
            ),
            onCapture: { [weak self] in self?.capture.toggle() },
            onCalendar: { [weak self] in self?.openCalendar() },
            onDrawer: { [weak self] in self?.drawer.toggle() }
        )
    }

    @objc private func captureClipboard() {
        Task { await clipboardCapture.capture() }
    }

    @objc private func changeHotkey() {
        recorder.begin(current: hotkey.current, title: L("빠른 입력")) { [weak self] candidate in
            guard let self else { return "" }
            // 두 단축키가 같은 조합이면 한쪽이 조용히 죽는다 — 여기서 막는다.
            guard candidate != self.pasteHotkey else { return L("\(candidate.displayName) 은 클립보드 즉시 메모가 쓰고 있습니다") }
            guard candidate != self.peekHotkey else { return L("\(candidate.displayName) 은 종이 보기가 쓰고 있습니다") }
            let registered = self.hotkey.register(id: 1, candidate) { [weak self] in
                self?.capture.toggle()
            }
            guard registered else {
                // 실패했으면 쓰던 것을 도로 걸어 둔다. 바꾸려다 아예 못 쓰게
                // 되는 것이 가장 나쁘다.
                self.hotkeyAvailable = self.hotkey.register(id: 1, self.storedHotkey()) { [weak self] in
                    self?.capture.toggle()
                }
                return L("\(candidate.displayName) 은 다른 앱이 쓰고 있습니다")
            }
            self.hotkeyAvailable = true
            self.settings.update {
                $0.hotkeyKeyCode = candidate.keyCode
                $0.hotkeyModifiers = candidate.modifiers
            }
            self.configureButton()
            return nil
        }
    }

    /// 클립보드 즉시 메모의 조합 — 빠른 입력과 같은 길, 같은 되돌림.
    @objc private func changePasteHotkey() {
        recorder.begin(current: pasteHotkey, title: L("클립보드 즉시 메모")) { [weak self] candidate in
            guard let self else { return "" }
            guard candidate != self.hotkey.current else { return L("\(candidate.displayName) 은 빠른 입력이 쓰고 있습니다") }
            guard candidate != self.peekHotkey else { return L("\(candidate.displayName) 은 종이 보기가 쓰고 있습니다") }
            let registered = self.hotkey.register(id: Self.pasteHotkeyID, candidate) { [weak self] in
                Task { await self?.clipboardCapture.capture() }
            }
            guard registered else {
                self.pasteHotkeyAvailable = self.hotkey.register(id: Self.pasteHotkeyID, self.storedPasteHotkey()) { [weak self] in
                    Task { await self?.clipboardCapture.capture() }
                }
                return L("\(candidate.displayName) 은 다른 앱이 쓰고 있습니다")
            }
            self.pasteHotkey = candidate
            self.pasteHotkeyAvailable = true
            self.settings.update {
                $0.pasteHotkeyKeyCode = candidate.keyCode
                $0.pasteHotkeyModifiers = candidate.modifiers
            }
            return nil
        }
    }

    /// 종이 보기의 조합 — 앞의 둘과 같은 길, 같은 되돌림.
    @objc private func changePeekHotkey() {
        recorder.begin(current: peekHotkey, title: L("종이 보기")) { [weak self] candidate in
            guard let self else { return "" }
            guard candidate != self.hotkey.current else { return L("\(candidate.displayName) 은 빠른 입력이 쓰고 있습니다") }
            guard candidate != self.pasteHotkey else { return L("\(candidate.displayName) 은 클립보드 즉시 메모가 쓰고 있습니다") }
            let registered = self.hotkey.register(id: Self.peekHotkeyID, candidate) { [weak self] in
                self?.peekPapers()
            }
            guard registered else {
                self.peekHotkeyAvailable = self.hotkey.register(id: Self.peekHotkeyID, self.storedPeekHotkey()) { [weak self] in
                    self?.peekPapers()
                }
                return L("\(candidate.displayName) 은 다른 앱이 쓰고 있습니다")
            }
            self.peekHotkey = candidate
            self.peekHotkeyAvailable = true
            self.settings.update {
                $0.peekHotkeyKeyCode = candidate.keyCode
                $0.peekHotkeyModifiers = candidate.modifiers
            }
            return nil
        }
    }

    @objc private func checkForUpdates() {
        Task { await updater.check(userAsked: true) }
    }

    @objc private func installUpdate() {
        Task { await updater.install() }
    }

    /// brew 의 앱은 brew 가 바꾼다. 우리는 무엇을 쳐야 하는지만 손에 쥐여 준다.
    @objc private func copyBrewCommand() {
        guard let advice = updater.source.advice else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(advice, forType: .string)
    }

    private func setUsesClaude(_ on: Bool) {
        settings.update { $0.usesClaude = on }
        // 껐으면 이번 실행에서도 바로 사라져야 한다 — 다시 켤 때까지 기다리게 하지 않는다.
        Task { [weak self] in
            guard let self else { return }
            let runner = await ClaudeSupport.resolve(settings: settings)
            windows.adoptClaude(runner)
            // 웹의 답·다듬기·정리도 같은 스위치를 따른다 — 끄면 이 기기의 모델로 돌아온다.
            assistant?.adoptClaude(runner)
        }
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

    /// 다른 기기의 판을 **이 판으로** — 자리의 메모가 그 글을 받는다. 받은 메모를 앞으로 데려와
    /// 무엇이 바뀌었는지 보이게 한다.
    @objc private func adoptConflict(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = ULID(raw),
              let winner = store.trash.first(where: { $0.id == id })?.conflictOf
        else { return }
        Task {
            try? await store.adoptConflict(id)
            windows.reveal(winner)
        }
    }

    /// 치워 둔 것을 **한 번에** 도로 꺼낸다 (`{#tidy-visible-undo}`).
    ///
    /// 치울 때 `layout.json` 을 건드리지 않았으므로, 꺼내면 종이는 **원래
    /// 있던 자리로** 돌아온다. 되돌리기는 되돌리기여야 한다 — 목록에만
    /// 돌려놓고 종이는 안 세우면 그건 절반만 되돌린 것이고, 사람은 자기
    /// 바탕화면이 왜 달라졌는지 끝내 모른다.
    ///
    /// 한꺼번에 쏟아지는 것은 창 상한(24장)이 막는다 — 그리고 그 상태가
    /// 곧 치우기 전의 그 화면이다.
    @objc private func restoreTidied() {
        Task { await store.untidyAll() }
    }

    /// 치워 둔 것 **한 장**을 도로 꺼내고 그 종이를 앞으로 — 꺼낸 것이 어디 섰는지 보여야 되돌린 것이다.
    @objc private func restoreTidiedOne(_ sender: NSMenuItem) {
        guard let id = Self.memoID(of: sender) else { return }
        Task {
            await store.untidy(id)
            windows.reveal(id)
        }
    }

    // MARK: 끝내기·보관·미루기 (인계서 §4 — 규칙은 `MemoStore` 에, 여기는 손잡이뿐)

    @objc private func openMemo(_ sender: NSMenuItem) {
        guard let id = Self.memoID(of: sender) else { return }
        windows.reveal(id)
    }

    @objc private func markDone(_ sender: NSMenuItem) {
        guard let id = Self.memoID(of: sender) else { return }
        Task { try? await store.markDone(id) }
    }

    @objc private func archiveMemo(_ sender: NSMenuItem) {
        guard let id = Self.memoID(of: sender) else { return }
        Task { try? await store.archive(id) }
    }

    /// 보관에서 꺼내 앞으로 — 꺼낸 종이는 원래 자리로 돌아온다 (`layout.json` 은 건드린 적이 없다).
    @objc private func unarchiveMemo(_ sender: NSMenuItem) {
        guard let id = Self.memoID(of: sender) else { return }
        Task {
            try? await store.unarchive(id)
            windows.reveal(id)
        }
    }

    /// 내일 아침 9시에 다시 — 배너의 단추와 같은 값(`Snooze`). 일정은 그대로, 다시 볼 시각만 옮긴다.
    @objc private func postponeToMorning(_ sender: NSMenuItem) {
        guard let id = Self.memoID(of: sender) else { return }
        Task { _ = try? await store.update(id, surface: .some(Snooze.tomorrowMorning())) }
    }

    private nonisolated static func memoID(of sender: NSMenuItem) -> ULID? {
        (sender.representedObject as? String).flatMap(ULID.init)
    }

    @objc private func toggleCalendar() { calendar.toggle() }

    @objc private func summonDrawer() { drawer.summon() }

    @objc private func toggleDrawer() { drawer.toggle() }

    @objc private func toggleSpike() { spike.toggle() }

    @objc private func openVault() { NSWorkspace.shared.open(paths.vault) }

    @objc private func quit() { NSApp.terminate(nil) }
}
