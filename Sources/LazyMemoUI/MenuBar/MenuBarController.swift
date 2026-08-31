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
    private let clipboardCapture: ClipboardCapture
    private let calendar: CalendarWindowController
    private let hotkey = HotkeyManager()
    private let recorder = HotkeyRecorder()
    private let settings: SettingsStore
    private let appearance: PaperAppearance
    private let mover: VaultMover
    /// 설정에 적혀 있었지만 찾지 못한 메모 폴더 (`AppPaths.resolve`).
    /// 값이 있으면 지금 화면은 **기본 폴더**를 보고 있다는 뜻이다.
    private let missingVault: URL?
    private let menu = NSMenu()

    /// 단축키 등록에 실패했는지 — 다른 앱이 같은 조합을 선점한 경우다.
    private var hotkeyAvailable = false

    init(
        paths: AppPaths,
        store: MemoStore,
        windows: NoteWindowManager,
        layouts: LayoutStore,
        settings: SettingsStore,
        appearance: PaperAppearance,
        missingVault: URL? = nil
    ) {
        self.paths = paths
        self.store = store
        self.windows = windows
        self.settings = settings
        self.appearance = appearance
        self.missingVault = missingVault
        self.mover = VaultMover(
            paths: paths, settings: settings,
            // 옮기기 전에 적던 글을 전부 내린다 — 옮기고 나면 옛 자리는 없다.
            flush: { [weak windows] in await windows?.flushAll() }
        )
        self.capture = QuickCaptureController(store: store, windows: windows)
        self.clipboardCapture = ClipboardCapture(store: store, windows: windows)
        self.calendar = CalendarWindowController(
            store: store, layouts: layouts,
            // 달력에서 줄을 누르는 것은 **보는 일**이다. 자리는 그대로 달력에
            // 둔다 — 안 그러면 읽으려는 클릭 한 번이 그 일정을 영영 바탕화면의
            // 종이로 만든다 (§7.2 의 예외에 걸린다).
            onSelectMemo: { [weak windows] id in windows?.reveal(id, keepingPlace: true) }
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
        clipboardCapture.onScheduled = { [weak self] day in self?.calendar.announce(day) }

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

    /// 하루가 바뀌었다 (`DayClock`). 달력 창은 여기만 들고 있다.
    func dayChanged(to day: CalendarDate) { calendar.dayChanged(to: day) }

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
        menu.addItem(clipboardCaptureItem())
        if !hotkeyAvailable {
            menu.addItem(disabled("⚠︎ \(hotkey.current.displayName) 을 다른 앱이 쓰고 있습니다"))
        }
        addMissingVaultLine(to: menu)
        addTroubleLine(to: menu)
        menu.addItem(item(title: "빈 종이 꺼내기", action: #selector(newMemo), key: ""))
        menu.addItem(.separator())

        let calendarItem = item(title: "달력", action: #selector(toggleCalendar), key: "")
        calendarItem.state = calendar.isOpen ? .on : .off
        menu.addItem(calendarItem)
        menu.addItem(.separator())

        addMemoList(to: menu)
        addTidiedSection(to: menu)
        addTrashSection(to: menu)

        menu.addItem(.separator())
        menu.addItem(settingsItem())
        addVaultItem(to: menu)
        menu.addItem(.separator())
        menu.addItem(item(title: "lazymemo 종료", action: #selector(quit), key: "q"))
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
        let line = disabled("⚠︎ 옮겨 둔 메모 폴더를 찾지 못했습니다")
        line.toolTip = "\(missingVault.path(percentEncoded: false))\n"
            + "지금은 기본 폴더를 쓰고 있습니다. 그 자리가 돌아오면 다시 그리로 갑니다."
        menu.addItem(line)
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

    /// 클립보드 원키 즉시 캡처 (⌥⌘V).
    private func clipboardCaptureItem() -> NSMenuItem {
        let entry = item(title: "클립보드 즉시 메모", action: #selector(captureClipboard), key: "v")
        entry.keyEquivalentModifierMask = [.option, .command]
        entry.toolTip = "복사한 글이나 사진을 창 없이 즉시 메모로 저장합니다"
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
        // 치워 둔 것은 여기 오지 않는다 (`Tidy`). 바로 아래 줄이 몇 장인지
        // 적고 한 번에 도로 꺼낸다 — 안 적으면 그건 삭제로 읽힌다.
        let memos = store.active
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

        menu.addItem(header("치워 둔 \(tidied.count)장 — \(Self.tidiedReasons(tidied))"))

        let restore = item(title: "도로 꺼내기", action: #selector(restoreTidied), key: "")
        restore.image = NSImage(
            systemSymbolName: "tray.and.arrow.up", accessibilityDescription: "도로 꺼내기"
        )
        restore.toolTip = "지운 것이 아닙니다 — 찾으면 그대로 나오고, 열면 도로 나옵니다"
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
        guard !reasons.isEmpty else { return "다 끝난 것" }
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

        submenu.addItem(loginItem())

        submenu.addItem(.separator())
        submenu.addItem(paperOpacityItem())

        submenu.addItem(.separator())
        submenu.addItem(vaultLocationItem())

        submenu.addItem(.separator())
        let embed = item(title: "링크를 카드로 펼치기", action: #selector(toggleLinkEmbedding), key: "")
        embed.state = settings.current.embedsLinks ?? true ? .on : .off
        // 네트워크를 쓰는 유일한 기능이다. 켜져 있다는 사실이 보여야 한다 (§9.3).
        embed.subtitle = "제목과 그림을 가져오려고 그 주소에 접속합니다"
        submenu.addItem(embed)

        parent.submenu = submenu
        return parent
    }

    /// 메모가 어디에 있는지, 그리고 옮기는 길 (설계문서 §5.1).
    ///
    /// **지금 자리를 먼저 적는다.** 옮기는 버튼만 있으면 어디서 어디로 가는지
    /// 모른 채 누르게 되고, 이 앱에서 그것은 메모 전부가 걸린 조작이다.
    private func vaultLocationItem() -> NSMenuItem {
        let entry = item(title: "메모 폴더 옮기기…", action: #selector(moveVault), key: "")
        entry.subtitle = "지금은 \(shortVaultPath)"
        entry.toolTip = "고른 폴더에 이미 메모가 있으면 옮기지 않고 그것을 씁니다"
        return entry
    }

    /// 홈 아래는 `~` 로 줄인다. 메뉴 한 줄에 전체 경로는 안 들어간다.
    private var shortVaultPath: String {
        let path = paths.vault.path(percentEncoded: false)
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// 재부팅을 넘기는 스위치 (`LoginItem`).
    ///
    /// 설정 안에서 가장 위에 둔다. 이 앱은 켜져 있지 않으면 아무것도 아니라서,
    /// 여기 있는 항목 중 유일하게 **안 켜면 앱 전체가 없어지는** 것이다.
    private func loginItem() -> NSMenuItem {
        let entry = item(title: "로그인할 때 시작", action: #selector(toggleLoginItem), key: "")
        entry.state = LoginItem.isEnabled ? .on : .off
        if LoginItem.isAvailable {
            entry.subtitle = "껐다 켜도 메모가 그대로 떠 있습니다"
        } else {
            // 개발 빌드(`swift run`)는 등록할 몸이 없다. 켤 수 없는 스위치를
            // 멀쩡한 척 보여 주지 않는다.
            entry.isEnabled = false
            entry.subtitle = "앱 번들로 실행할 때만 됩니다"
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

    @objc private func toggleSpike() { spike.toggle() }

    @objc private func openVault() { NSWorkspace.shared.open(paths.vault) }

    @objc private func quit() { NSApp.terminate(nil) }
}
