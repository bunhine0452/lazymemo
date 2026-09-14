import AppKit
import LazyMemoCore
import Observation

/// 앱 안에서 판을 바꾼다.
///
/// **소란스럽지 않게.** 새 판이 나왔다고 창을 띄우지 않는다 — 이 앱은 자기를
/// 드러내지 않기로 했고(철학 4), 업데이트만 예외일 이유가 없다. 알림은 메뉴의
/// 한 줄이고, 사용자가 메뉴를 열었을 때 거기 있다.
///
/// 바꾸는 마지막 걸음은 앱이 스스로 못 한다 — 자기가 돌고 있는 번들을 자기가
/// 갈아 끼울 수 없기 때문이다. 그래서 작은 스크립트에 넘기고 앱은 물러난다
/// (`UpdateInstaller.swapScript`). 그 스크립트는 어느 갈래로 가든 마지막에 앱을
/// 다시 열므로, **화면에서 보면 앱이 잠깐 닫혔다 뜨는 것**이 전부다.
@MainActor
@Observable
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case found(Release)
        case installing
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastChecked: Date?

    let settings: SettingsStore
    let source: InstallSource
    private let fetch: UpdateCheck.Fetch

    init(
        settings: SettingsStore,
        source: InstallSource = .current,
        fetch: @escaping UpdateCheck.Fetch = Updater.download
    ) {
        self.settings = settings
        self.source = source
        self.fetch = fetch
    }

    /// 자동으로 물어봐도 되는가. 개발 중에는 바꿀 번들이 없으므로 묻지도 않는다.
    var isEnabled: Bool {
        source.allowsExternalUpdates && (settings.current.checksForUpdates ?? true)
    }

    func setEnabled(_ enabled: Bool) {
        settings.update { $0.checksForUpdates = enabled }
        if !enabled { state = .idle }
    }

    /// 새 판이 있는지 본다. `userAsked` 면 설정이 꺼져 있어도 이번 한 번은 묻는다 —
    /// 사람이 직접 눌렀다면 그것이 곧 허락이다.
    func check(userAsked: Bool = false) async {
        guard source.allowsExternalUpdates, userAsked || isEnabled else { return }
        guard state != .checking, state != .installing else { return }

        state = .checking
        do {
            let latest = try await UpdateCheck.latest(fetch: fetch)
            lastChecked = Date()
            state = UpdateCheck.newer(than: LazyMemo.semanticVersion, in: latest)
                .map(State.found) ?? .upToDate
        } catch {
            lastChecked = Date()
            // 확인에 실패하는 것은 **앱의 잘못이 아닐 때가 대부분**이다 (네트워크가
            // 없거나 GitHub 이 느리거나). 그래도 조용히 «최신입니다» 가 되면 안 된다.
            state = .failed(String(describing: error))
        }
    }

    /// 내려받아 바꾸고 다시 연다. **여기서 돌아오면 실패한 것이다** — 성공하면 앱이 죽는다.
    func install() async {
        guard case .found(let release) = state else { return }
        guard source == .standalone else {
            state = .failed(UpdateInstaller.Failure.notReplaceable(source).description)
            return
        }

        state = .installing
        do {
            let staged = try await UpdateInstaller(fetch: fetch).stage(release, source: source)
            try handOff(staged)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// 자리 바꾸기를 스크립트에 넘기고 물러난다.
    private func handOff(_ staged: URL) throws {
        let script = UpdateInstaller.swapScript(
            pid: ProcessInfo.processInfo.processIdentifier,
            staged: staged,
            destination: Bundle.main.bundleURL
        )
        let path = staged
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "swap.sh")
        try Data(script.utf8).write(to: path)

        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = [path.path]
        try process.run()   // 기다리지 않는다 — 이 스크립트가 기다리는 것이 우리다.

        // 평소의 종료 경로를 그대로 탄다. 적던 글은 여기서 flush 된다.
        NSApp.terminate(nil)
    }

    /// 실제 네트워크. `URLSession` 은 이 앱의 업데이트 경로에서 여기 한 곳뿐이다.
    @Sendable static func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        // GitHub 은 이름 없는 요청을 거절할 때가 있다. **판 번호는 싣지 않는다** —
        // 견주는 일은 받아온 뒤 이 기계 안에서 한다.
        request.setValue("lazymemo", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        return try await URLSession.shared.data(for: request).0
    }
}
