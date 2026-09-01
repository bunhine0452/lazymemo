import Foundation
import Testing
@testable import LazyMemoCore

@Suite("ClaudeCLI — 있으면 켜지고 없으면 조용히 없다")
struct ClaudeCLITests {
    private let home = "/Users/someone"

    @Test("있을 만한 자리에서 찾는다")
    func findsKnownPath() {
        let found = ClaudeCLI.known(home: home) { $0 == "/opt/homebrew/bin/claude" }
        #expect(found?.path == "/opt/homebrew/bin/claude")
    }

    @Test("먼저 나오는 자리를 쓴다 — 집 안의 것이 시스템 것보다 앞이다")
    func prefersHomeInstall() {
        let found = ClaudeCLI.known(home: home) { _ in true }
        #expect(found?.path == home + "/.claude/local/claude")
    }

    @Test("없으면 없다고 한다")
    func absent() {
        #expect(ClaudeCLI.known(home: home) { _ in false } == nil)
    }

    @Test("로그인 셸이 아는 자리를 받는다 — fnm·nvm 아래는 이 길로만 찾힌다")
    func asksLoginShell() {
        let found = ClaudeCLI.askingLoginShell(shell: "/bin/zsh") { shell, arguments in
            #expect(shell == "/bin/zsh")
            #expect(arguments == ["-lc", "command -v claude"])
            return "/Users/someone/.local/share/fnm/node-versions/v24/bin/claude\n"
        }
        #expect(found?.path.hasSuffix("/bin/claude") == true)
    }

    @Test("프로필이 찍은 인사말이 섞여 있어도 마지막 줄을 본다")
    func readsLastLine() {
        #expect(ClaudeCLI.reading("Welcome!\nnvm loaded\n/usr/local/bin/claude\n")?.path
            == "/usr/local/bin/claude")
    }

    @Test("절대 경로가 아니면 버린다 — 셸 함수나 별칭은 우리가 부를 수 없다")
    func rejectsNonPaths() {
        #expect(ClaudeCLI.reading("claude: aliased to foo") == nil)
        #expect(ClaudeCLI.reading("claude") == nil)
        #expect(ClaudeCLI.reading("") == nil)
        #expect(ClaudeCLI.reading("/usr/local/bin/my claude") == nil)
    }

    @Test("셸이 실패해도 던지지 않는다 — 없는 것과 같다")
    func survivesShellFailure() {
        struct Boom: Error {}
        #expect(ClaudeCLI.askingLoginShell { _, _ in throw Boom() } == nil)
    }

    @Test("글은 인자가 아니라 stdin 으로 준다")
    func passesTextOnStdin() {
        let cli = ClaudeCLI(path: "/usr/local/bin/claude")
        #expect(cli.arguments(for: "정리해줘") == ["-p", "정리해줘"])
    }
}
