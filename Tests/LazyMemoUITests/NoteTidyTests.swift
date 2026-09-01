import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 종이 위 「다듬기」와 이 앱이 처음 갖는 기다리는 상태
/// (`{#claude-tidy-action}`·`{#claude-wait-state}`).
@MainActor
@Suite("Claude 가 종이를 다듬는다")
struct NoteTidyTests {
    private func fakeClaude(_ script: String) throws -> ClaudeRunner {
        let path = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "fake-claude-\(UUID().uuidString)")
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        return ClaudeRunner(cli: ClaudeCLI(path: path.path), timeout: .seconds(10))
    }

    private func makeModel(claude: ClaudeRunner?, body: String) throws -> NoteModel {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-tidy-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let previews = LinkPreviewStore(
            cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
            settings: settings
        )
        return NoteModel(memo: Memo(body: body), store: store, previews: previews, claude: claude)
    }

    @Test("claude 가 없으면 조작 자체가 없다")
    func absentWithoutCLI() throws {
        #expect(!(try makeModel(claude: nil, body: "장보기").canTidy))
        #expect(try makeModel(claude: try fakeClaude("cat"), body: "장보기").canTidy)
    }

    @Test("다듬으면 글이 바뀌고 8초 동안 되돌릴 수 있다")
    func tidiesAndOffersUndo() async throws {
        let model = try makeModel(claude: try fakeClaude("echo '- 우유'"), body: "우유")
        model.text = "우유"

        await model.tidyWithClaude()

        #expect(model.text == "- 우유")
        #expect(model.thinking == .done(previous: "우유"))

        await model.undoTidy()
        #expect(model.text == "우유")
        #expect(model.thinking == .none)
    }

    @Test("답이 오는 사이에 글이 바뀌었으면 버린다 — 다듬은 것이 아니라 지운 것이 된다")
    func discardsWhenTextMovedUnderneath() async throws {
        let model = try makeModel(claude: try fakeClaude("sleep 1; echo '다듬은 글'"), body: "처음")
        model.text = "처음"

        let running = Task { await model.tidyWithClaude() }
        try? await Task.sleep(for: .milliseconds(300))
        model.text = "그사이 적은 줄"
        await running.value

        #expect(model.text == "그사이 적은 줄")
        if case .failed(let reason) = model.thinking {
            #expect(reason.contains("바뀌어"))
        } else {
            Issue.record("버렸다는 말이 없다: \(model.thinking)")
        }
    }

    @Test("실패는 조용히 삼키지 않는다 — 아무 일도 없어 보이면 한 번 더 누른다")
    func surfacesFailure() async throws {
        let model = try makeModel(claude: try fakeClaude("exit 2"), body: "장보기")
        model.text = "장보기"

        await model.tidyWithClaude()

        #expect(model.text == "장보기")
        if case .failed = model.thinking {} else {
            Issue.record("실패가 상태에 남지 않았다: \(model.thinking)")
        }
    }

    @Test("빈 종이는 보내지 않는다 — 다듬을 것이 없는데 토큰을 쓰지 않는다")
    func skipsEmptyNotes() async throws {
        let model = try makeModel(claude: try fakeClaude("echo '무언가'"), body: "")
        model.text = "   \n  "

        await model.tidyWithClaude()

        #expect(model.thinking == .none)
        #expect(model.text == "   \n  ")
    }

    @Test("바뀐 것이 없으면 그렇게 말한다")
    func saysWhenNothingChanged() async throws {
        let model = try makeModel(claude: try fakeClaude("cat"), body: "장보기")
        model.text = "장보기"

        await model.tidyWithClaude()

        if case .failed(let reason) = model.thinking {
            #expect(reason.contains("다듬을 것이 없었습니다"))
        } else {
            Issue.record("같은 글이 돌아왔는데 다듬었다고 했다: \(model.thinking)")
        }
    }
}
