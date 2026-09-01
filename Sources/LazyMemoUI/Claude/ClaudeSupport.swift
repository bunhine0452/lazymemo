import Foundation
import LazyMemoCore

/// `claude` 를 찾아 두는 곳. **한 번만 찾고 적어 둔다.**
///
/// 로그인 셸에게 물어보는 길(`ClaudeCLI.askingLoginShell`)은 셸을 한 번 띄우므로
/// 켤 때마다 하면 기동이 그만큼 늦다. 찾은 자리를 `settings.json` 에 적어 두고
/// 다음부터는 그 파일이 아직 있는지만 본다 — 지워졌으면 그때 다시 찾는다.
enum ClaudeSupport {
    static func resolve(settings: SettingsStore) async -> ClaudeRunner? {
        guard settings.current.usesClaude ?? true else { return nil }

        let manager = FileManager.default
        let home = NSHomeDirectory()

        // 적어 둔 자리가 아직 있으면 그것으로 끝.
        if let cached = settings.current.claudePath, manager.isExecutableFile(atPath: cached) {
            return ClaudeRunner(cli: ClaudeCLI(path: cached))
        }

        if let known = ClaudeCLI.known(home: home) {
            settings.update { $0.claudePath = known.path }
            return ClaudeRunner(cli: known)
        }

        // 셸에게 묻는 것은 마지막이다. fnm·nvm·asdf 아래는 이 길로만 찾힌다.
        let found = await Task.detached(priority: .utility) {
            ClaudeCLI.askingLoginShell { shell, arguments in
                let process = Process()
                process.executableURL = URL(filePath: shell)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return String(decoding: data, as: UTF8.self)
            }
        }.value

        guard let found else { return nil }
        settings.update { $0.claudePath = found.path }
        return ClaudeRunner(cli: found)
    }
}
