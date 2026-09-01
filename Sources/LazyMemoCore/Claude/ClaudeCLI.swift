import Foundation

/// 이 컴퓨터에 `claude` 가 있는가, 그리고 어떻게 부르는가.
///
/// **있으면 켜지고 없으면 조용히 없다.** 이 앱의 기능으로 광고하지 않고
/// 스크린샷에도 넣지 않는다 — 없는 사람에게는 존재하지 않는 기능이라,
/// 화면에 자리를 차지하고 있으면 그 자체가 «되지 않는 것» 이 된다.
///
/// ## GUI 앱의 PATH 는 셸의 PATH 가 아니다
///
/// 앱은 로그인 셸을 거치지 않고 뜨므로 PATH 가 `/usr/bin:/bin:/usr/sbin:/sbin`
/// 뿐이다. 터미널에서 `which claude` 가 되는데 앱에서는 안 되는 이유가 이것이고,
/// 여기서 그냥 `which` 를 부르면 **거의 모든 사용자에게 «없음» 이 나온다.**
///
/// 그래서 두 걸음이다. ① 있을 만한 자리를 직접 본다(빠르고 프로세스를 안 띄운다).
/// ② 못 찾으면 **로그인 셸에게 물어본다** — `zsh -lc 'command -v claude'`.
/// fnm·nvm·asdf·mise 처럼 셸이 PATH 를 만들어 주는 도구를 쓰면 ①로는 못 찾는데,
/// 실제로 그런 설치가 흔하다. 찾은 자리는 **적어 두고 다시 묻지 않는다**
/// (`Settings.claudePath`) — 켤 때마다 셸을 띄울 이유가 없다.
public struct ClaudeCLI: Sendable, Equatable {
    public let path: String

    public init(path: String) { self.path = path }

    /// 프로세스를 띄우지 않고 볼 수 있는 자리들.
    public static func candidates(home: String) -> [String] {
        [
            home + "/.claude/local/claude",
            home + "/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
        ]
    }

    public static func known(
        home: String,
        exists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> ClaudeCLI? {
        candidates(home: home).first(where: exists).map(ClaudeCLI.init)
    }

    /// 로그인 셸이 아는 자리. 셸을 한 번 띄우므로 ①이 실패했을 때만 부른다.
    public static func askingLoginShell(
        shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
        run: (String, [String]) throws -> String
    ) -> ClaudeCLI? {
        guard let output = try? run(shell, ["-lc", "command -v claude"]) else { return nil }
        return reading(output)
    }

    /// 셸이 뱉은 줄에서 자리를 읽는다.
    ///
    /// 로그인 셸은 프로필이 찍은 인사말을 함께 뱉을 수 있으므로 **마지막 줄**을
    /// 본다. 절대 경로가 아니면 버린다 — 셸 함수나 별칭일 수 있고, 그것은
    /// 우리가 부를 수 있는 것이 아니다.
    static func reading(_ output: String) -> ClaudeCLI? {
        guard let line = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .last?
            .trimmingCharacters(in: .whitespaces),
            line.hasPrefix("/"), !line.contains(" ")
        else { return nil }
        return ClaudeCLI(path: line)
    }

    /// 물어볼 말을 넘기는 방식. **글은 인자가 아니라 stdin 으로 준다** —
    /// 메모가 길면 인자 길이 상한에 걸리고, 따옴표가 든 글은 새는 자리가 된다.
    public func arguments(for prompt: String) -> [String] {
        ["-p", prompt]
    }
}
