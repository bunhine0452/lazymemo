import AppKit
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoReminders
import LazyMemoSpotlight

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
        hotkey.register(id: 2, .paste) { [weak self] in
            Task { await self?.clipboardCapture.capture() }
        }
        hotkey.register(id: 3, .here) { [weak self] in
            Task { await self?.here.capture() }
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

    /// 껐다 켜도 서랍은 놓아 둔 자리에 그대로 있다.
    func restoreDrawer() { drawer.restoreIfWasVisible() }

    func openDrawer() { drawer.open() }

    /// 서랍이 실제 창에서 약속대로 자라고 접히는가 (`verify-drawer.sh`).
    func drawerDiagnostics() async -> String { await drawer.diagnostics() }

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

    func closeCapture() { capture.close(returningFocus: false) }
    /// 이 기기의 비서를 빠른 입력 상자에 끼운다.
    func adoptAssistant(_ assistant: AssistantModel?) { capture.adoptAssistant(assistant) }
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
        addMissingVaultLine(to: menu)
        addTroubleLine(to: menu)
        menu.addItem(item(title: L("빈 종이 꺼내기"), action: #selector(newMemo), key: ""))
        menu.addItem(.separator())

        let calendarItem = item(title: L("달력"), action: #selector(toggleCalendar), key: "")
        calendarItem.state = calendar.isOpen ? .on : .off
        menu.addItem(calendarItem)

        let drawerItem = item(title: L("서랍"), action: #selector(toggleDrawer), key: "")
        drawerItem.state = drawer.isVisible ? .on : .off
        drawerItem.toolTip = L("밀어 둔 종이가 모이는 자리 — 바탕화면에 놓입니다")
        menu.addItem(drawerItem)
        menu.addItem(.separator())

        addMemoList(to: menu)
        addTidiedSection(to: menu)
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

    /// 클립보드 원키 즉시 캡처 (⌥⌘V).
    private func clipboardCaptureItem() -> NSMenuItem {
        let entry = item(title: L("클립보드 즉시 메모"), action: #selector(captureClipboard), key: "v")
        entry.keyEquivalentModifierMask = [.option, .command]
        entry.toolTip = L("복사한 글이나 사진을 창 없이 즉시 메모로 저장합니다")
        return entry
    }

    /// 종이가 얼마나 비치는가 (§14.5 의 예외).
    ///
    /// 단계를 네 칸으로 끊는다 — 슬라이더는 조준해서 끌어야 하는 물건이고,
    /// 메뉴 안에서는 더 그렇다.
    private func paperOpacityItem() -> NSMenuItem {
        let parent = NSMenuItem(title: L("종이 투명도"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for step in PaperAppearance.steps {
            let entry = item(title: step.label, action: #selector(setPaperOpacity(_:)), key: "")
            entry.representedObject = step.opacity as NSNumber
            entry.state = appearance.selected == step ? .on : .off
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        submenu.addItem(disabled(L("포인터를 올리면 원래대로 진해집니다")))
        parent.submenu = submenu
        return parent
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
    /// 하나씩 꺼내는 길은 따로 두지 않았다. 빠른 입력에서 찾아 열면 그
    /// 자리에서 도로 꺼내지므로(`NoteWindowManager.reveal`), 메뉴에 목록을
    /// 한 벌 더 얹으면 그것이야말로 또 하나의 치울 거리가 된다.
    private func addTidiedSection(to menu: NSMenu) {
        let tidied = store.tidiedMemos
        guard !tidied.isEmpty else { return }
        menu.addItem(.separator())

        menu.addItem(header(L("치워 둔 \(tidied.count)장 — \(Self.tidiedReasons(tidied))")))

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

        let justDeleted = trash.first.flatMap { memo -> Memo? in
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

        let remaining = trash.filter { $0.id != justDeleted?.id }
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

    /// 설정. 항목이 몇 개뿐이라 창을 따로 짓지 않는다 — 창을 여는 것 자체가
    /// 조작 한 번이고, 이 앱은 그 한 번을 아끼는 앱이다.
    private func settingsItem() -> NSMenuItem {
        let parent = NSMenuItem(title: L("설정"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(item(title: L("알림…"), action: #selector(showReminders), key: ""))
        submenu.addItem(.separator())

        let shortcut = item(title: L("단축키 바꾸기…"), action: #selector(changeHotkey), key: "")
        shortcut.subtitle = L("지금은 \(hotkey.current.displayName)")
        submenu.addItem(shortcut)

        submenu.addItem(loginItem())

        submenu.addItem(.separator())
        submenu.addItem(paperOpacityItem())

        submenu.addItem(.separator())
        submenu.addItem(vaultLocationItem())
        submenu.addItem(cloudSyncItem())

        submenu.addItem(.separator())
        // `claude` 가 없으면 이 줄들도 없다 — 없는 사람에게는 존재하지 않는 기능이다.
        // App Store 판에는 아예 없다 (`ClaudeSupport`).
        if !updater.source.isAppStore, windows.claude != nil || settings.current.claudePath != nil {
            let tidy = item(title: L("종이에서 Claude 부르기"), action: #selector(toggleClaude), key: "")
            tidy.state = settings.current.usesClaude ?? true ? .on : .off
            tidy.subtitle = L("종이의 ✧ 를 누를 때만 나갑니다 · 8초 안에 되돌릴 수 있습니다")
            submenu.addItem(tidy)

            let morning = item(title: L("아침 여덟 시에 브리핑 놓기"), action: #selector(toggleMorningBrief), key: "")
            morning.state = brief.isEnabled ? .on : .off
            // **누르지 않았는데 값이 드는 유일한 기능이다.** 그 사실을 적는다.
            morning.subtitle = L("매일 메모를 Claude 에게 보냅니다 — 구독 사용량이 듭니다")
            submenu.addItem(morning)
            submenu.addItem(.separator())
        }

        let watch = item(title: L("가면 떠오르게 하기"), action: #selector(togglePlaceWatch), key: "")
        watch.state = watcher.isEnabled ? .on : .off
        // **켜 둔 것을 잊게 두지 않는다** — 몇 자리를 지켜보는지까지 적는다.
        watch.subtitle = watcher.note
        submenu.addItem(watch)

        // 위치는 켜고 끄는 값이 아니라 **권한이 정한다.** 그래서 토글이 아니라
        // 지금 어떤 상태인지만 적는다 — 거절해 놓고 «왜 안 되지» 가 남으면 안 된다.
        if let note = HereCapture.access.note {
            let location = disabled(L("지금 여기 — ⌥⌘L"))
            location.subtitle = note
            submenu.addItem(location)
            submenu.addItem(.separator())
        }

        let events = item(title: L("시스템 캘린더 함께 보기"), action: #selector(toggleSystemEvents), key: "")
        events.state = settings.current.showsSystemEvents ?? true ? .on : .off
        // 권한을 묻는 자리는 달력을 처음 열 때다. 거절했다면 그 사실이 여기 보인다 —
        // 조용히 빈 달력을 내놓으면 사용자는 연동이 고장 난 줄 안다.
        events.subtitle = EventKitFeed.access.note ?? L("달력을 처음 열 때 한 번 묻습니다 · 읽기만 합니다")
        submenu.addItem(events)

        // 앱을 열지 않고도 찾힌다. 기기 밖으로 나가는 것은 없지만 이 맥의 검색에 메모가
        // 보인다는 사실은 적어 둔다 — 같이 쓰는 맥이면 끌 이유가 있다.
        let spotlight = item(title: L("Spotlight 에서 찾기"), action: #selector(toggleSpotlight), key: "")
        spotlight.state = SpotlightCenter.shared.enabled ? .on : .off
        spotlight.subtitle = SpotlightCenter.shared.trouble
            ?? L("메모 제목과 글이 이 맥의 검색에 보입니다 — 기기 밖으로 나가지 않습니다")
        submenu.addItem(spotlight)
        submenu.addItem(.separator())

        if updater.source.allowsExternalUpdates {
            let check = item(title: L("새 판이 나오면 알기"), action: #selector(toggleUpdateChecks), key: "")
            check.state = updater.isEnabled ? .on : .off
            // 네트워크를 쓰는 두 번째 기능이다. 켜져 있다는 사실이 보여야 한다 (§9.3).
            check.subtitle = L("GitHub 에 판 번호만 물어봅니다 — 메모는 나가지 않습니다")
            submenu.addItem(check)
            submenu.addItem(.separator())
        }

        let embed = item(title: L("링크를 카드로 펼치기"), action: #selector(toggleLinkEmbedding), key: "")
        embed.state = settings.current.embedsLinks ?? true ? .on : .off
        // 네트워크를 쓰는 유일한 기능이다. 켜져 있다는 사실이 보여야 한다 (§9.3).
        embed.subtitle = L("제목과 그림을 가져오려고 그 주소에 접속합니다")
        submenu.addItem(embed)

        submenu.addItem(.separator())
        // 약속의 가는 길 — 되물음에 답할 때만 지도·길찾기에 접속한다. 세 번째로 §9.3 이 갈리는 자리.
        let routes = item(title: L("약속을 적으면 가는 길 묻기"), action: #selector(toggleRouteAsking), key: "")
        routes.state = settings.current.asksRoutes ?? true ? .on : .off
        routes.subtitle = L("「어디서 출발하시나요?」에 답할 때만 지도와 길찾기에 접속합니다")
        submenu.addItem(routes)

        // 대중교통은 네이버 지도 웹이 키 없이 답한다(`NaverWebRouter`). ODsay 키는 그것이 끊겼을 때의 예비다.
        let key = item(title: L("예비 길찾기 키 (ODsay)…"), action: #selector(changeTransitKey), key: "")
        let hasKey = !(settings.current.transitKey ?? "").isEmpty
        key.subtitle = hasKey
            ? L("넣어 두었습니다 — 네이버 지도가 답하지 않을 때 씁니다")
            : L("없어도 됩니다 — 네이버 지도가 답하지 않을 때만 · lab.odsay.com 에서 무료로 받습니다")
        submenu.addItem(key)

        parent.submenu = submenu
        return parent
    }

    /// 이 기기의 알림 — 켜기 전에 잠금 화면 표시와 기기별 동의를 읽는 창 (`ReminderSettingsView`).
    @objc private func showReminders() { RecallWindow.settings() }

    /// 메모가 어디에 있는지, 그리고 옮기는 길 (설계문서 §5.1).
    ///
    /// **지금 자리를 먼저 적는다.** 옮기는 버튼만 있으면 어디서 어디로 가는지
    /// 모른 채 누르게 되고, 이 앱에서 그것은 메모 전부가 걸린 조작이다.
    private func vaultLocationItem() -> NSMenuItem {
        let entry = item(title: L("메모 폴더 옮기기…"), action: #selector(moveVault), key: "")
        entry.subtitle = L("지금은 \(shortVaultPath)")
        entry.toolTip = L("고른 폴더에 이미 메모가 있으면 옮기지 않고 그것을 씁니다")
        return entry
    }

    /// 아이폰과 같은 폴더를 보는 길. 이미 그 안이면 그렇다고 적고 누를 것이 없다.
    private func cloudSyncItem() -> NSMenuItem {
        // 샌드박스 안에서는 `NSHomeDirectory()` 가 컨테이너라 디스크의 폴더를 못 찾는다 —
        // 뜰 때 iCloud 에 직접 물어 둔 것이 먼저다.
        let container = cloudContainer ?? AppPaths.cloudContainerOnDisk()
        if container.map({ AppPaths.cloudVault(inContainer: $0) })
            .map({ $0.standardizedFileURL.path(percentEncoded: false) })
            == paths.vault.standardizedFileURL.path(percentEncoded: false) {
            let entry = disabled(L("iCloud 로 동기화 중"))
            entry.subtitle = L("아이폰의 lazymemo 와 같은 폴더를 봅니다")
            return entry
        }
        let entry = item(title: L("iCloud 로 동기화…"), action: #selector(syncToCloud), key: "")
        entry.subtitle = L("iCloud Drive 의 LazyMemo 폴더로 옮깁니다 — 아이폰과 같은 자리")
        entry.toolTip = L("별도 계정 없이 iCloud 가 옮깁니다. 이미 거기 메모가 있으면 합칩니다")
        return entry
    }

    /// 홈 아래는 `~` 로 줄인다. 메뉴 한 줄에 전체 경로는 안 들어간다.
    private var shortVaultPath: String { VaultLabel.readable(paths.vault) }

    /// 재부팅을 넘기는 스위치 (`LoginItem`).
    ///
    /// 설정 안에서 가장 위에 둔다. 이 앱은 켜져 있지 않으면 아무것도 아니라서,
    /// 여기 있는 항목 중 유일하게 **안 켜면 앱 전체가 없어지는** 것이다.
    private func loginItem() -> NSMenuItem {
        let entry = item(title: L("로그인할 때 시작"), action: #selector(toggleLoginItem), key: "")
        entry.state = LoginItem.isEnabled ? .on : .off
        if LoginItem.isAvailable {
            entry.subtitle = L("껐다 켜도 메모가 그대로 떠 있습니다")
        } else {
            // 개발 빌드(`swift run`)는 등록할 몸이 없다. 켤 수 없는 스위치를
            // 멀쩡한 척 보여 주지 않는다.
            entry.isEnabled = false
            entry.subtitle = L("앱 번들로 실행할 때만 됩니다")
        }
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

    // MARK: 동작

    @objc private func openCapture() { capture.toggle() }

    @objc func showWelcome() {
        welcome.show(
            shortcut: hotkey.current.displayName,
            onCapture: { [weak self] in self?.capture.toggle() },
            onCalendar: { [weak self] in self?.openCalendar() },
            onDrawer: { [weak self] in self?.drawer.toggle() }
        )
    }

    @objc private func captureClipboard() {
        Task { await clipboardCapture.capture() }
    }

    @objc private func changeHotkey() {
        recorder.begin(current: hotkey.current) { [weak self] candidate in
            guard let self else { return false }
            let registered = self.hotkey.register(id: 1, candidate) { [weak self] in
                self?.capture.toggle()
            }
            guard registered else {
                // 실패했으면 쓰던 것을 도로 걸어 둔다. 바꾸려다 아예 못 쓰게
                // 되는 것이 가장 나쁘다.
                self.hotkeyAvailable = self.hotkey.register(id: 1, self.storedHotkey()) { [weak self] in
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

    @objc private func toggleLoginItem() {
        LoginItem.set(!LoginItem.isEnabled)
    }

    @objc private func moveVault() { mover.begin() }
    @objc private func syncToCloud() { mover.beginCloud() }

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

    @objc private func toggleClaude() {
        settings.update { $0.usesClaude = !($0.usesClaude ?? true) }
        // 껐으면 이번 실행에서도 바로 사라져야 한다 — 다시 켤 때까지 기다리게 하지 않는다.
        Task { [weak self] in
            guard let self else { return }
            windows.adoptClaude(await ClaudeSupport.resolve(settings: settings))
        }
    }

    @objc private func toggleMorningBrief() {
        brief.setEnabled(!brief.isEnabled)
    }

    @objc private func togglePlaceWatch() {
        watcher.setEnabled(!watcher.isEnabled)
    }

    @objc private func toggleSystemEvents() {
        settings.update { $0.showsSystemEvents = !($0.showsSystemEvents ?? true) }
    }

    @objc private func toggleSpotlight() {
        SpotlightCenter.shared.setEnabled(!SpotlightCenter.shared.enabled)
    }

    @objc private func toggleUpdateChecks() {
        updater.setEnabled(!updater.isEnabled)
    }

    @objc private func toggleLinkEmbedding() {
        settings.update { $0.embedsLinks = !($0.embedsLinks ?? true) }
    }

    @objc private func toggleRouteAsking() {
        settings.update { $0.asksRoutes = !($0.asksRoutes ?? true) }
    }

    /// ODsay 키를 넣거나 지운다. 창 하나에 칸 하나 — 키는 이 맥의 설정 파일에만 남는다.
    @objc private func changeTransitKey() {
        let alert = NSAlert()
        alert.messageText = L("예비 길찾기 키 (ODsay)")
        alert.informativeText = L("가는 길은 네이버 지도가 키 없이 답합니다. ODsay LAB(lab.odsay.com)에서 무료로 받은 API 키를 넣어 두면 네이버 지도가 답하지 않을 때 그것으로 버스·지하철을 찾습니다. 키는 이 맥에만 남고 iCloud 로 건너가지 않습니다.")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = settings.current.transitKey ?? ""
        field.placeholderString = L("API 키")
        alert.accessoryView = field
        alert.addButton(withTitle: L("저장"))
        alert.addButton(withTitle: L("그만두기"))
        NSApp.activate()
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let entered = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.update { $0.transitKey = entered.isEmpty ? nil : entered }
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

    @objc private func toggleCalendar() { calendar.toggle() }

    @objc private func toggleDrawer() { drawer.toggle() }

    @objc private func toggleSpike() { spike.toggle() }

    @objc private func openVault() { NSWorkspace.shared.open(paths.vault) }

    @objc private func quit() { NSApp.terminate(nil) }
}
