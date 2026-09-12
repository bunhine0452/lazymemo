import Foundation
import Testing
@testable import LazyMemoCore

// 시험 대상이 macOS 에만 있다 (`Process`).
#if os(macOS)
/// 서브프로세스 배선 — stdin·상한·종료 코드.
///
/// **진짜 `claude` 를 부르지 않는다.** 시험이 사용자의 토큰을 쓰면 안 되고,
/// 여기서 확인할 것은 답의 내용이 아니라 «글이 제대로 건너가고, 끝나지 않는
/// 것이 없고, 실패가 실패로 돌아오는가» 다.
@Suite("ClaudeRunner — 기다림의 배선")
struct ClaudeRunnerTests {
    private func fakeClaude(_ script: String) throws -> ClaudeCLI {
        let path = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "fake-claude-\(UUID().uuidString)")
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        return ClaudeCLI(path: path.path)
    }

    @Test("글이 stdin 으로 건너간다")
    func passesTextOnStdin() async throws {
        let runner = ClaudeRunner(cli: try fakeClaude("cat"))
        #expect(try await runner.ask("다듬어줘", about: "장보기\n- 우유") == "장보기\n- 우유")
    }

    @Test("물어본 말은 인자로 간다")
    func passesPromptAsArgument() async throws {
        // 마지막 인자를 되돌려 주는 가짜.
        let runner = ClaudeRunner(cli: try fakeClaude("echo \"$2\""))
        #expect(try await runner.ask("다듬어줘", about: "무시") == "다듬어줘")
    }

    @Test("답에 붙은 코드펜스는 걷어서 돌려준다")
    func cleansAnswer() async throws {
        let runner = ClaudeRunner(cli: try fakeClaude("printf '```\\n장보기\\n```\\n'"))
        #expect(try await runner.ask("x", about: "y") == "장보기")
    }

    @Test("빈 답은 답이 아니다")
    func rejectsEmpty() async throws {
        let runner = ClaudeRunner(cli: try fakeClaude("true"))
        await #expect(throws: ClaudeRunner.Failure.empty) {
            try await runner.ask("x", about: "y")
        }
    }

    @Test("실패는 실패로 돌아온다 — 조용히 삼키지 않는다")
    func reportsFailure() async throws {
        let runner = ClaudeRunner(cli: try fakeClaude("exit 3"))
        await #expect(throws: ClaudeRunner.Failure.failed(3)) {
            try await runner.ask("x", about: "y")
        }
    }

    @Test("실행할 수 없으면 없다고 한다")
    func reportsMissingBinary() async {
        let runner = ClaudeRunner(cli: ClaudeCLI(path: "/nowhere/claude"))
        await #expect(throws: ClaudeRunner.Failure.notFound) {
            try await runner.ask("x", about: "y")
        }
    }

    @Test("끝나지 않는 것은 없다 — 상한을 넘기면 끊는다")
    func timesOut() async throws {
        let runner = ClaudeRunner(cli: try fakeClaude("sleep 30"), timeout: .seconds(1))
        await #expect(throws: ClaudeRunner.Failure.timedOut) {
            try await runner.ask("x", about: "y")
        }
    }
}
#endif
