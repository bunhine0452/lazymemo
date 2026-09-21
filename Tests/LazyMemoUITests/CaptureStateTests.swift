import AppKit
import Foundation
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// **끝난 일은 화면에서 물러난다.**
///
/// 2026-09-18 사용자: 「맥에서 다이어트 하는 법 검색해줘 하고 결과를 받고 «정리하기» 를 누른 뒤,
/// 검색 결과가 esc 를 눌러도 사라지지 않는다」. 세 곳이 함께 걸려 있었다 — 남기고 나서도 답 카드가
/// 그대로 섰고, esc 는 상자만 닫았고, 다시 열면 그 카드가 도로 서 있었다. 치우는 길이 아예 없었다.
@MainActor
@Suite("빠른 입력 — 끝난 것은 물러나고, esc 는 한 겹씩 벗긴다")
struct CaptureStateTests {
    private func makePaths(_ name: String) throws -> AppPaths {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return paths
    }

    private func makeAssistant(_ store: MemoStore, support: URL) -> AssistantModel {
        AssistantModel(service: store.service, support: support)
    }

    /// 웹에서 막 돌아온 화면 — 답 한 문장과 인용한 결과 한 칸.
    private func stageWebAnswer(_ assistant: AssistantModel) {
        let hit = Evidence(hit: WebHit(title: "다이어트 기본", url: URL(string: "https://www.example.org/diet")!,
                                       snippet: "덜 먹고 더 걷는다"))
        let answer = AssistantAnswer(found: true, text: "적게 먹고 자주 걷는 것이 기본입니다",
                                     evidence: [hit.memoID], quotes: ["덜 먹고 더 걷는다"],
                                     sources: [WebSource(id: hit.memoID, title: "다이어트 기본", url: hit.url!)])
        assistant.stageForPreview(answer: answer, results: [hit], question: "웹에서 다이어트 하는 법 검색해줘")
    }

    @Test("「메모로 남기기」 뒤에는 답과 결과 카드가 물러나고 결과 줄 하나만 남는다")
    func followUpRetiresTheWebAnswer() async throws {
        let paths = try makePaths("capture-state")
        let store = try MemoStore(paths: paths)
        let assistant = makeAssistant(store, support: paths.support)
        stageWebAnswer(assistant)
        #expect(assistant.isStanding)
        #expect(!assistant.webResults.isEmpty)

        assistant.followUp(.keep)
        await settle("메모가 적히지 않았다") { assistant.receipt != nil }

        // 답·결과·물음은 물러난다 — 할 일이 끝난 카드다.
        #expect(assistant.answer == nil)
        #expect(assistant.webQuestion == nil)
        #expect(assistant.webResults.isEmpty)
        #expect(assistant.followUps.isEmpty)
        // 남는 것은 한 줄 — 「메모로 남겼습니다 · 되돌리기」. 되돌릴 것을 잃으면 안 된다.
        #expect(assistant.applied?.kind == .createMemo)
        #expect(assistant.receipt?.kind == .createMemo)
        #expect(assistant.isStanding)
    }

    @Test("답이 서 있으면 esc 는 상자를 닫는 대신 그것부터 치우고, 친 글은 그대로 남는다")
    func escapePeelsTheAnswerFirst() async throws {
        let paths = try makePaths("capture-peel")
        let store = try MemoStore(paths: paths)
        let model = QuickCaptureModel(store: store)
        let assistant = makeAssistant(store, support: paths.support)
        model.assistant = assistant

        model.query = "다이어트"
        stageWebAnswer(assistant)
        #expect(model.canDismissAssistantResult)

        #expect(model.dismissAssistantResult())
        #expect(assistant.answer == nil)
        #expect(!assistant.isStanding)
        // 적던 글은 esc 한 번에 사라지지 않는다 — 벗긴 것은 답 한 겹뿐이다.
        #expect(model.query == "다이어트")
        // 결과 줄(되돌리기)도 같은 손짓으로 치워진다.
        stageWebAnswer(assistant)
        assistant.followUp(.keep)
        await settle("메모가 적히지 않았다") { assistant.receipt != nil }
        #expect(model.canDismissAssistantResult)
        #expect(model.dismissAssistantResult())
        #expect(!assistant.isStanding)
    }

    @Test("벗길 겹이 없으면 esc 는 제 일로 — 상자를 닫는다. 되물음 중에도 가로채지 않는다 (D12)")
    func escapeClosesWhenNothingStands() async throws {
        let paths = try makePaths("capture-close")
        let store = try MemoStore(paths: paths)
        let model = QuickCaptureModel(store: store)
        model.assistant = makeAssistant(store, support: paths.support)

        model.query = "우유 사기"
        #expect(!model.canDismissAssistantResult)
        #expect(!model.dismissAssistantResult())

        // 되묻는 중의 esc 는 「시각 없이 남기기」다 — 여기서 가로채면 이미 «적어라» 한 글이 사라진다.
        model.query = "9월 30일에 친구랑 밥 먹기로 했어"
        _ = model.commit()
        #expect(model.pendingQuestion != nil)
        #expect(!model.dismissAssistantResult())
    }

    @Test("상자를 닫으면 비서도 손을 뗀다 — 다시 열 때 지난번 답이 서 있지 않는다")
    func closingTheBoxClearsTheAssistant() async throws {
        let paths = try makePaths("capture-reopen")
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let windows = NoteWindowManager(
            store: store,
            layouts: LayoutStore(location: paths.layout),
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: settings
            ),
            appearance: PaperAppearance(settings: settings)
        )
        let controller = QuickCaptureController(store: store, windows: windows)
        let assistant = makeAssistant(store, support: paths.support)
        controller.adoptAssistant(assistant)

        controller.typeForTesting("다이어트 하는 법")
        stageWebAnswer(assistant)
        controller.close(returningFocus: false)

        #expect(assistant.answer == nil)
        #expect(assistant.receipt == nil)
        #expect(!assistant.isStanding)
        // 닫아도 적던 글은 상자가 기억한다 (§8) — 물러나는 것은 비서의 화면뿐이다.
        #expect(controller.draftForTesting == "다이어트 하는 법")
    }

    @Test("답이 서 있거나 읽는 중이면 상자는 「들고 있다」 — 바깥 클릭이 치우지 않는 조건")
    func holdsWorkWhileAnswerStands() async throws {
        let paths = try makePaths("holds")
        let store = try MemoStore(paths: paths)
        let assistant = makeAssistant(store, support: paths.support)
        let model = QuickCaptureModel(store: store)
        model.assistant = assistant
        #expect(!model.holdsWork)
        stageWebAnswer(assistant)
        #expect(model.holdsWork)
        #expect(model.dismissAssistantResult())
        #expect(!model.holdsWork)
    }
}
