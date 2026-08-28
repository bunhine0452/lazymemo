import AppKit
import LazyMemoCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let paths = AppPaths.standard()

    private var store: MemoStore?
    private var layouts: LayoutStore?
    private var windows: NoteWindowManager?
    private var menuBar: MenuBarController?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘도 메뉴 막대도 차지하지 않는 상주 앱.
        // Info.plist 의 LSUIElement 와 짝을 이루며, `swift run` 처럼 번들 없이
        // 실행할 때는 이쪽만이 유일한 근거가 된다.
        NSApp.setActivationPolicy(.accessory)
        // 메뉴 막대에 보이지 않지만, 이것이 없으면 ⌘A·⌘Z·⌘C 가 전부 죽는다.
        StandardMenu.install()

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
        let previews = LinkPreviewStore(
            cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
            settings: settings
        )
        let windows = NoteWindowManager(store: store, layouts: layouts, previews: previews)
        let menuBar = MenuBarController(
            paths: paths, store: store, windows: windows, layouts: layouts, settings: settings
        )

        self.store = store
        self.layouts = layouts
        self.windows = windows
        self.menuBar = menuBar

        Task {
            // 파일이 정본이므로 화면은 스캔 결과를 따른다 (§4).
            await store.start()
            windows.start()

            let environment = ProcessInfo.processInfo.environment
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

    /// 저장 버튼이 없는 앱이라(§8) 종료가 곧 마지막 저장 지점이다.
    /// 비동기 flush 를 기다리기 위해 종료를 한 박자 미룬다.
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
