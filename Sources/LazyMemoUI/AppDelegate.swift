import AppKit
import LazyMemoCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MemoStore?
    private var layouts: LayoutStore?
    private var windows: NoteWindowManager?
    private var menuBar: MenuBarController?
    private let clock = DayClock()
    private var dueClock: DueClock?
    /// 앱이 뜨기 전에 두드린 주소. 문이 열리면 그때 들여보낸다.
    private var pendingURLs: [URL] = []

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘도 메뉴 막대도 차지하지 않는 상주 앱.
        // Info.plist 의 LSUIElement 와 짝을 이루며, `swift run` 처럼 번들 없이
        // 실행할 때는 이쪽만이 유일한 근거가 된다.
        NSApp.setActivationPolicy(.accessory)
        // 메뉴 막대에 보이지 않지만, 이것이 없으면 ⌘A·⌘Z·⌘C 가 전부 죽는다.
        StandardMenu.install()

        Task {
            // App Store 판은 iCloud 컨테이너가 기본 자리다 — 폰과 같은 폴더. 첫 호출이
            // iCloud 데몬과 이야기하는 막히는 호출이라 메인 밖에서 한다. 다른 판은
            // 지금처럼 `~/Documents/lazymemo` 라 묻지 않는다 (`AppPaths.resolve`).
            let container: URL? = if InstallSource.current.isAppStore {
                await Task.detached(priority: .userInitiated) { AppPaths.ubiquityContainer() }.value
            } else { nil }
            open(AppPaths.resolve(cloudContainer: container), cloudContainer: container)
        }
    }

    /// 메모 폴더가 어디인지 정해진 뒤의 기동 전부.
    ///
    /// - Parameter location: 설정에 적힌 자리까지 살펴 정한 것 (§5.1). 옮겨 둔
    ///   폴더를 못 찾았으면 그 사실도 함께 들어 있다.
    private func open(_ location: AppPaths.Resolution, cloudContainer: URL?) {
        let paths = location.paths
        let store: MemoStore
        do {
            try paths.createDirectories()
            store = try MemoStore(paths: paths)
        } catch {
            presentFatal("저장소를 열지 못했습니다.\n\(paths.vault.path(percentEncoded: false))\n\n\(error)")
            return
        }

        let layouts = LayoutStore(location: paths.layout)
        let settings = SettingsStore(location: paths.settings)
        rememberVault(location, in: settings)
        let previews = LinkPreviewStore(
            cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
            settings: settings
        )
        let appearance = PaperAppearance(settings: settings)
        let windows = NoteWindowManager(
            store: store, layouts: layouts, previews: previews, appearance: appearance
        )
        let menuBar = MenuBarController(
            paths: paths, store: store, windows: windows, layouts: layouts,
            settings: settings, appearance: appearance,
            missingVault: location.missingVault, cloudContainer: cloudContainer
        )

        self.store = store
        self.layouts = layouts
        self.windows = windows
        self.menuBar = menuBar

        // 서비스 메뉴 「lazymemo 에 적기」. `Info.plist` 의 NSMessage 와 짝이다.
        NSApp.servicesProvider = menuBar.door
        // 개발 중 번들을 옮겨 다니면 등록이 낡는다. 한 번 털어 준다.
        NSUpdateDynamicServices()

        // 앱이 없을 때 두드린 주소가 있으면 이제 들여보낸다.
        let waiting = pendingURLs
        pendingURLs = []
        if !waiting.isEmpty {
            Task { [door = menuBar.door] in
                for url in waiting { await door.receive(url: url) }
            }
        }

        // `claude` 가 이 컴퓨터에 있는지 한 번 찾는다 (`ClaudeSupport`).
        // **없으면 아무 일도 일어나지 않는다** — 종이에 조작이 하나 안 생길 뿐이고,
        // 그 사실을 어디에도 적지 않는다 (없는 사람에게는 존재하지 않는 기능이다).
        Task { [weak windows, weak menuBar] in
            let runner = await ClaudeSupport.resolve(settings: settings)
            windows?.adoptClaude(runner)
            // 아침 시계는 `claude` 를 찾은 뒤에 건다 — 없으면 걸 이유가 없다.
            if runner != nil { menuBar?.brief.start() }
        }

        // 하루가 바뀌면 앱이 스스로 하는 일들 (`DayClock`).
        //
        // 이 앱은 바탕화면에 상주하므로 몇 주씩 안 꺼진다. 이것이 없던 동안
        // 달력의 오늘은 켠 날에 멈춰 있었고, 「미루기」는 그 날을 기준으로
        // 셈했고, 휴지통의 30일은 영영 오지 않았다.
        // 적힌 시각이 오면 그 종이가 나온다 (§7.2 — "그 날이 오면 달력이 꺼내 준다").
        let dueClock = DueClock(store: store)
        dueClock.onDue = { [weak windows] id in windows?.surface(id) }
        self.dueClock = dueClock

        clock.onNewDay = { [weak store, weak windows, weak menuBar, weak dueClock] day in
            menuBar?.dayChanged(to: day)
            windows?.dayChanged()
            // 어제 꺼내 놓은 종이는 도로 달력에 맡긴다. 어제의 일정이 오늘도
            // 바탕화면에 서 있으면 그것부터가 낡은 종이다 (철학 3).
            windows?.clearSurfaced()
            dueClock?.dayChanged()
            Task { await store?.tidy() }
        }
        clock.start()

        Task {
            // 파일이 정본이므로 화면은 스캔 결과를 따른다 (§4).
            await store.start()
            // 소개 영상 주행 — 창을 세우기 전에 무대를 심는다 (`DemoTour`).
            let demo = ProcessInfo.processInfo.environment["LAZYMEMO_DEMO"]
                .flatMap(DemoTour.region(from:))
                .map { menuBar.demoTour(in: $0, layouts: layouts) }
            if let demo { await demo.seed() }
            let firstLaunch = WelcomeNote.shouldGreet(
                greeted: settings.current.greeted, memoCount: store.memos.count
            )
            // 처음 켠 사람에게는 안내서 대신 **메모 한 장**을 놓는다.
            // 창을 세우기 전에 놓아야 그 종이도 함께 바탕화면에 오른다.
            await WelcomeNote.place(in: store, settings: settings)
            windows.start()
            // 메모를 다 읽은 **뒤에** 건다 — 빈 목록에 걸면 울릴 것이 없다.
            dueClock.start()
            // 일정은 달력에서만 보이므로(§7.2) 달력의 열림 여부도 복원 대상이다.
            menuBar.restoreCalendar()
            menuBar.restoreDrawer()

            let environment = ProcessInfo.processInfo.environment
            if firstLaunch && !environment.keys.contains(where: { $0.hasPrefix("LAZYMEMO_") }) {
                menuBar.showWelcome()
            }
            if let demo {
                // 같은 무대에서 영상 대신 정지 장면을 찍을 수도 있다 (`scripts/store-shots.sh`).
                if let shots = environment["LAZYMEMO_SHOTS"], !shots.isEmpty {
                    await demo.shots(into: URL(filePath: shots, directoryHint: .isDirectory))
                } else {
                    await demo.run()
                }
                exit(0)
            }
            if environment["LAZYMEMO_SPIKE"] == "1" {
                menuBar.openSpike()
            }
            if environment["LAZYMEMO_CALENDAR"] == "1" {
                menuBar.openCalendar()
            }
            // `{#capture-over-apps}` — 다른 앱이 앞에 있는 상태에서 상자가
            // 실제로 화면에 오르는지 검증하기 위한 통로 (`verify-capture.sh`).
            // 초를 주면 그만큼 기다렸다 연다 — 그 사이 검증 스크립트가 다른
            // 앱을 앞으로 세운다.
            if let delay = environment["LAZYMEMO_CAPTURE"].flatMap(Double.init), delay >= 0 {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                menuBar.showCaptureForMeasurement()
                Self.log("직후  \(menuBar.captureDiagnostics)")
                try? await Task.sleep(for: .seconds(1))
                Self.log("1초 뒤 \(menuBar.captureDiagnostics)")
                Self.log("⌘A     \(menuBar.selectAllReach)")
            }
            // `{#capture-outside-click}` — 상자 바깥을 누르면 치워지는지.
            if environment["LAZYMEMO_DISMISS"] == "1" {
                Self.log("바깥클릭 \(await menuBar.captureDismissReach())")
                exit(0)
            }
            // 빠른 입력에서 ⌘V 가 사진을 넣는지 (`verify-capture-paste.sh`).
            if environment["LAZYMEMO_PASTE"] == "1" {
                Self.log("붙여넣기 \(await menuBar.capturePasteReach())")
                exit(0)
            }
            // `{#capture-delete}` — 빠른 입력에서 ⌘⌫ 가 메모를 지우는지.
            if environment["LAZYMEMO_DELETE"] == "1" {
                Self.log("목록지우기 \(await menuBar.captureDeleteReach())")
                exit(0)
            }
            // 바탕화면 종이가 창 전환기에 서지 않는지 (`verify-notes.sh`).
            if environment["LAZYMEMO_WINDOWROLE"] == "1" {
                Self.log("창역할 \(DesktopLevelWindow.roleDiagnostics)")
                exit(0)
            }
            // 서랍이 실제 창에서 펼쳐지고 제자리로 접히는지 (`verify-drawer.sh`).
            if environment["LAZYMEMO_DRAWER"] == "1" {
                Self.log("서랍 \(await menuBar.drawerDiagnostics())")
                exit(0)
            }
            if environment["LAZYMEMO_MENU"] == "1" {
                Self.log("메뉴\n\(menuBar.menuDiagnostics)")
                exit(0)
            }
            if let path = environment["LAZYMEMO_RENDER"], !path.isEmpty {
                await PreviewRenderer.renderAll(
                    into: URL(filePath: path, directoryHint: .isDirectory),
                    store: store, previews: previews
                )
                // 저장할 것이 없는 렌더 전용 모드다. `NSApp.terminate` 는
                // 이 자리(비동기 Task 안)에서 델리게이트를 부르지 못하고 멈춘다.
                exit(0)
            }
            if let rounds = environment["LAZYMEMO_MEASURE"].flatMap(Int.init), rounds > 0 {
                await Self.measureQuickCapture(rounds: rounds, menuBar: menuBar)
            }
        }
    }

    /// 정한 자리를 설정에 남긴다.
    ///
    /// App Store 판은 **첫 실행에 정한 자리를 적어 둔다.** 기본 자리가 iCloud 의
    /// 유무에 따라 갈리는 판이라, 적어 두지 않으면 iCloud 를 나중에 켜거나 끄는
    /// 것만으로 다음 실행이 다른 폴더를 보고 — 사용자에게는 메모가 전부 사라진
    /// 화면이다. 자리를 바꾸는 것은 메뉴의 옮기기뿐이어야 한다 (`VaultMover`).
    /// 시험(`LAZYMEMO_VAULT`)은 적지 않는다 — 그 자리의 설정 파일은 시험의 것이다.
    ///
    /// 낡은 열쇠를 새로 만들었으면(`VaultBookmark`) 그것도 같이 적는다.
    private func rememberVault(_ location: AppPaths.Resolution, in settings: SettingsStore) {
        let vault = location.paths.vault.path(percentEncoded: false)
        if let refreshed = location.refreshedBookmark {
            settings.update { $0.vaultPath = vault; $0.vaultBookmark = refreshed }
            return
        }
        guard InstallSource.current.isAppStore, location.missingVault == nil,
              settings.current.vaultPath == nil,
              ProcessInfo.processInfo.environment[AppPaths.vaultEnvironmentKey] == nil
        else { return }
        settings.update { $0.vaultPath = vault }
    }

    /// 저장 버튼이 없는 앱이라(§8) 종료가 곧 마지막 저장 지점이다.
    /// 비동기 flush 를 기다리기 위해 종료를 한 박자 미룬다.
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        clock.stop()
        dueClock?.stop()
        // 빠른 입력의 초안은 미뤄 둔 쓰기가 있을 수 있다 — 기다리지 않고 적는다.
        menuBar?.flushCaptureDraft()
        guard let windows else { return .terminateNow }
        Task {
            await windows.flushAll()
            store?.stop()
            layouts?.flush()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// `{#latency-measure}` — 빠른 입력이 뜨기까지의 시간을 실측한다 (§11 의 150ms).
    ///
    /// 전역 단축키를 프로그램으로 누르려면 손쉬운 사용 권한이 필요해서,
    /// 단축키 이후의 경로(팝오버 표시 + 커서 세우기)만 반복 측정한다.
    /// Carbon 이 이벤트를 넘겨주는 시간은 여기에 포함되지 않는다.
    private static func measureQuickCapture(rounds: Int, menuBar: MenuBarController) async {
        var samples: [Duration] = []

        for _ in 0..<rounds {
            menuBar.showCaptureForMeasurement()
            if let latency = menuBar.captureLatency { samples.append(latency) }
            menuBar.closeCapture()
            try? await Task.sleep(for: .milliseconds(120))
        }

        let milliseconds = samples
            .map { Double($0.components.seconds) * 1000 + Double($0.components.attoseconds) / 1e15 }
            .sorted()

        guard let best = milliseconds.first,
              let median = milliseconds[safe: milliseconds.count / 2],
              let worst = milliseconds.last
        else {
            print("측정 실패 — 표본이 없습니다")
            exit(0)
        }

        print(String(format: "표본 %d회  최소 %.1fms  중앙값 %.1fms  최대 %.1fms",
                     milliseconds.count, best, median, worst))
        print(median <= 150 ? "✓ 목표 150ms 이내" : "✗ 목표 150ms 초과")
        // 측정 모드도 같은 이유로 곧장 나간다.
        exit(0)
    }

    /// 파이프로 넘길 때 stdout 은 통째로 버퍼링돼 죽을 때까지 안 나온다.
    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("[capture] \(message)\n".utf8))
    }

    /// 저장소를 못 여는 상황은 복구 경로가 없다 — 조용히 죽지 않고 이유를 보여준 뒤 종료한다.
    /// `lazymemo://add?text=…` — 다른 앱·단축어·스크립트가 두드리는 문 (`InboundLink`).
    ///
    /// **글자만 받는다.** 무엇을 받는지는 `InboundLink` 한 곳에서만 정하고,
    /// 여기서는 늘리지 않는다. 앱이 아직 안 떴으면 잠깐 들고 있다가 들여보낸다 —
    /// 이 주소로 앱이 처음 깨어나는 경우가 있기 때문이다.
    public func application(_ application: NSApplication, open urls: [URL]) {
        guard let door = menuBar?.door else {
            pendingURLs.append(contentsOf: urls)
            return
        }
        Task { for url in urls { await door.receive(url: url) } }
    }

    private func presentFatal(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "lazymemo 를 시작할 수 없습니다"
        alert.informativeText = message
        alert.addButton(withTitle: "종료")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
}
