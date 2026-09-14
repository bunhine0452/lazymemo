import AppKit
import LazyMemoCore

/// 메모 폴더를 옮기는 길 (설계문서 §5.1).
///
/// **문서가 약속한 것을 앱이 지킬 수 있게 한다.** README 는 처음부터 "이 폴더를
/// iCloud Drive 안으로 옮기면 동기화가 된다" 고 적어 두었는데, 앱에는 그 폴더를
/// 따라갈 길이 없었다 — 시킨 대로 Finder 에서 옮긴 사용자가 앱을 다시 켜면
/// 기본 자리에 빈 폴더가 새로 생기고 메모가 한 장도 없다. 설계문서 §5.1 의
/// "(설정으로 이동 가능)" 은 그동안 코드에 없는 문장이었다.
///
/// **문이 하나다.** 「옮기기」와 「고르기」를 나눠 놓으면 사용자가 자기 상황을
/// 먼저 판단해야 하는데, 고른 자리를 보면 앱이 알 수 있는 것이다 — 거기 이미
/// 메모가 있으면 그것을 쓰고(이미 옮겨 둔 사람), 없으면 지금 것을 옮긴다
/// (이제 옮기려는 사람). 어느 쪽인지는 **누르기 전에** 글로 보여준다.
@MainActor
final class VaultMover {
    private let paths: AppPaths
    private let settings: SettingsStore
    /// 뜰 때 찾아 둔 iCloud 컨테이너 (App Store 판). 없으면 여기서 다시 찾는다.
    private let cloudContainer: URL?
    /// 옮기기 전에 적던 글을 전부 파일에 내린다. 옮기고 나면 옛 자리는 없다.
    private let flush: () async -> Void

    init(
        paths: AppPaths, settings: SettingsStore, cloudContainer: URL? = nil,
        flush: @escaping () async -> Void
    ) {
        self.paths = paths
        self.settings = settings
        self.cloudContainer = cloudContainer
        self.flush = flush
    }

    func begin() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "여기로"
        panel.message = "메모를 둘 폴더를 고르세요. 이미 옮겨 둔 lazymemo 폴더를 고르면 그것을 씁니다."
        panel.directoryURL = paths.vault.deletingLastPathComponent()
        NSApp.activate()
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        Task { await apply(chosen) }
    }

    /// 「iCloud 로 동기화…」 — 폰과 같은 컨테이너의 `Documents/` 로 간다 (§5.1).
    ///
    /// 컨테이너는 두 길로 찾는다. entitlement 가 있는 빌드는 iCloud 에 직접 묻고,
    /// 없는 빌드(소스 빌드·ad-hoc)는 폰이 만들어 둔 `~/Library/Mobile Documents/`
    /// 아래 폴더를 본다. 둘 다 없으면 **왜 안 되는지를 적는다** — 조용히 아무
    /// 일도 안 하면 사용자는 버튼이 고장 난 줄 안다.
    func beginCloud() {
        Task {
            // 첫 호출이 iCloud 데몬과 이야기하는 막히는 호출이라 메인 밖에서.
            let container = if let cloudContainer { cloudContainer } else {
                await Task.detached(priority: .userInitiated) {
                    AppPaths.ubiquityContainer() ?? AppPaths.cloudContainerOnDisk()
                }.value
            }
            guard let container else {
                tell(
                    "iCloud 컨테이너를 찾지 못했습니다",
                    detail: "시스템 설정에서 iCloud Drive 가 켜져 있는지 보세요. "
                        + "소스에서 지은 lazymemo 는 아이폰의 lazymemo 가 한 번 켜진 뒤에야 그 폴더가 생깁니다.",
                    critical: true
                )
                return
            }
            await apply(VaultRelocation.planCloud(container: container, current: paths.vault))
        }
    }

    private func apply(_ chosen: URL) async {
        await apply(VaultRelocation.plan(choosing: chosen, current: paths.vault))
    }

    private func apply(_ plan: VaultRelocation.Plan) async {
        switch plan {
        case .alreadyThere:
            tell("이미 그 폴더를 쓰고 있습니다", detail: readable(paths.vault))
        case .refuse(let reason):
            tell("옮길 수 없습니다", detail: reason, critical: true)
        case .adopt(let target):
            guard confirm(
                "그 폴더의 메모를 씁니다",
                detail: "\(readable(target))\n\n이미 메모가 들어 있는 폴더입니다. "
                    + "파일은 옮기지 않고 이제부터 이 폴더를 씁니다.\n\n"
                    + "지금 있는 \(readable(paths.vault)) 는 그대로 남습니다."
            ) else { return }
            await settle(plan, to: target)
        case .move(let target):
            guard confirm(
                "메모 폴더를 옮깁니다",
                detail: "\(readable(paths.vault))\n→ \(readable(target))\n\n"
                    + "메모 파일과 사진이 통째로 옮겨집니다. lazymemo 가 다시 열립니다."
            ) else { return }
            await settle(plan, to: target)
        case .merge(let target, let existing):
            let already = existing > 0 ? "거기 이미 있는 \(existing)장과 합쳐집니다. " : ""
            guard confirm(
                "iCloud 의 LazyMemo 폴더로 옮깁니다",
                detail: "\(readable(paths.vault))\n→ \(readable(target))\n\n"
                    + "메모 파일과 사진이 그 폴더로 들어갑니다. \(already)"
                    + "아이폰의 lazymemo 와 같은 폴더입니다. lazymemo 가 다시 열립니다."
            ) else { return }
            await settle(plan, to: target)
        }
    }

    /// 옮기고, 적어 두고, 다시 연다.
    private func settle(_ plan: VaultRelocation.Plan, to target: URL) async {
        // 옮기기 전에 적던 글을 내린다. 파일이 사라진 뒤에 쓰면 그 글은 어디에도 없다.
        await flush()
        do {
            let moved = try VaultRelocation.perform(plan, from: paths.vault)
            // 고른 폴더에는 열쇠를 같이 적는다 — 샌드박스 판은 다음 실행에 이것으로
            // 문을 연다 (`VaultBookmark`). iCloud 컨테이너는 entitlement 가 여는
            // 자리라 열쇠가 필요 없고, 옛 열쇠를 남겨 두면 엉뚱한 폴더를 연다.
            let bookmark: Data? = if case .merge = plan { nil } else { VaultBookmark.make(for: moved) }
            settings.update {
                $0.vaultPath = moved.path(percentEncoded: false)
                $0.vaultBookmark = bookmark
            }
            // 인덱스는 파생물이라(D4) 버리면 그만이고, 새 자리를 훑어 다시
            // 지어진다. 옛 자리를 가리키는 행을 남겨 두는 것보다 짧다.
            discardIndex()
            Relaunch.now()
        } catch {
            tell("옮기지 못했습니다", detail: "\(error)\n\n메모는 있던 자리에 그대로 있습니다.", critical: true)
        }
    }

    private func discardIndex() {
        let manager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(filePath: paths.index.path(percentEncoded: false) + suffix)
            try? manager.removeItem(at: file)
        }
    }

    private func readable(_ url: URL) -> String { VaultLabel.readable(url) }

    private func confirm(_ message: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "옮기기")
        alert.addButton(withTitle: "그만두기")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func tell(_ message: String, detail: String, critical: Bool = false) {
        let alert = NSAlert()
        alert.alertStyle = critical ? .warning : .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "확인")
        NSApp.activate()
        alert.runModal()
    }
}

/// 앱을 껐다 켠다.
///
/// 메모 폴더가 바뀌면 저장소·인덱스·파일 감시자·떠 있는 창이 전부 새 자리를
/// 봐야 한다. 그것들을 살아 있는 채로 갈아 끼우는 길도 있지만, 그 길에는
/// "반쯤 옛 자리를 보고 있는 상태" 가 생긴다 — 저장 버튼이 없는 앱에서 그
/// 상태는 곧 글을 잃는 자리다. 이 앱은 뜨는 데 1초가 안 걸리므로 껐다 켠다.
@MainActor
enum Relaunch {
    static func now() {
        let bundle = Bundle.main.bundleURL
        let command = bundle.pathExtension == "app"
            ? "open -n \(shellQuoted(bundle.path(percentEncoded: false)))"
            : shellQuoted(CommandLine.arguments[0])

        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        // 지금 프로세스가 완전히 나간 뒤에 열려야 한 벌만 뜬다.
        process.arguments = ["-c", "sleep 1; \(command)"]
        try? process.run()
        NSApp.terminate(nil)
    }

    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
