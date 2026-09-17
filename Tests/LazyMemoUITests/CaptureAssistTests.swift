import Foundation
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 한 상자가 적기·찾기에 더해 **묻기·시키기·되묻기**를 겸한다 — 모드 없이 글이 무엇인지를 앱이 가린다.
@MainActor
@Suite("빠른 입력 — 비서를 겸하는 한 상자")
struct CaptureAssistTests {
    private func makeStore() throws -> MemoStore {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-assist-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(vault: root.appending(path: "vault", directoryHint: .isDirectory),
                             support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        return try MemoStore(paths: paths)
    }

    @Test("물음은 비서에게, 동사는 시키기로, 그냥 글은 메모로")
    func routing() throws {
        let model = QuickCaptureModel(store: try makeStore())
        model.query = "치과 언제였지?"
        #expect(model.commit() == .ask("치과 언제였지?"))
        model.query = "금요일 10시에 다시 알려줘"
        #expect(model.commit() == .command("금요일 10시에 다시 알려줘", target: nil))
        model.query = "우유 사기"
        #expect(model.commit() == .create(QuickCaptureModel.Draft(text: "우유 사기", due: nil, at: nil)))
    }

    @Test("「웹에서 …」·「… 검색해줘」는 바로 웹, 메모에서 못 찾은 뒤의 빈 상자 ⌘↵ 도 웹 — 글을 고치면 권유는 물러난다")
    func webRouting() throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        model.query = "웹에서 서울 내일 날씨 알려줘"
        #expect(model.intent == .web)
        #expect(model.commit() == .searchWeb("웹에서 서울 내일 날씨 알려줘"))
        model.query = "달러 환율 검색해줘"
        #expect(model.commit() == .searchWeb("달러 환율 검색해줘"))
        // 권유 없는 빈 상자는 닫기다.
        model.query = ""
        #expect(model.intent == .nothing)
        #expect(model.commit() == .nothing)

        let assistant = AssistantModel(service: store.service, support: FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-assist-web-\(UUID().uuidString)", directoryHint: .isDirectory))
        model.assistant = assistant
        assistant.stageForPreview(failed: "메모에서 근거를 찾지 못했습니다", offersWeb: "달러 환율 얼마야?")
        #expect(model.intent == .web)
        #expect(model.commit() == .searchWeb("달러 환율 얼마야?"))
        // 새 글을 치면 권유는 잊는다 — 옛 물음이 몰래 나가지 않는다.
        model.query = "우유"
        #expect(assistant.offersWeb == nil)
        #expect(model.intent == .memo)
    }

    @Test("「이 메모에게」로 열렸으면 그 메모가 대상이고, 물음도 그 메모에게 시키는 말로 본다")
    func targetFromOpener() throws {
        let model = QuickCaptureModel(store: try makeStore())
        let id = ULID()
        model.target = id
        model.query = "이거 지워"
        #expect(model.commit() == .command("이거 지워", target: id))
    }

    @Test("날짜·자리가 든 서술은 그대로 메모가 되고, 약속인데 시각이 없으면 되묻고 답으로 완성한다")
    func composeAndAskTime() throws {
        let model = QuickCaptureModel(store: try makeStore())
        model.query = "10월 3일까지 보고서 제출"
        guard case .compose(let patch) = model.commit() else { Issue.record("compose 가 아니다"); return }
        #expect(patch.due == .set(CalendarDate(year: 2026, month: 10, day: 3)) || patch.due != .keep)
        #expect(patch.body == "보고서 제출")

        model.query = "9월 30일에 @홍대입구 친구랑 밥 먹기로 했어"
        #expect(model.commit() == .askTime("약속 시간이 언제인가요?"))
        #expect(model.pendingQuestion == "약속 시간이 언제인가요?")
        model.query = "12시야"
        guard case .compose(let done) = model.commit() else { Issue.record("답으로 완성되지 않았다"); return }
        #expect(done.place == "홍대입구")
        if case .set(let at) = done.at {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: at)
            #expect(comps.hour == 12 && comps.minute == 0)
        } else { Issue.record("시각이 없다") }
        #expect(model.pendingQuestion == nil)
    }

    @Test("되물음에 딴 말을 하면 초안은 놓고 새 말로 본다")
    func replyThatIsNotAnAnswer() throws {
        let model = QuickCaptureModel(store: try makeStore())
        model.query = "9월 30일에 친구랑 밥 먹기로 했어"
        _ = model.commit()
        model.query = "치과 언제였지?"
        #expect(model.commit() == .ask("치과 언제였지?"))
        #expect(model.pendingQuestion == nil)
    }
}

@MainActor
@Suite("빠른 입력 — ⌘↵ 라벨이 곧 동사다 (설계 D5·D10·D12)")
struct CaptureIntentTests {
    private func makeStore() throws -> MemoStore {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-intent-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(vault: root.appending(path: "vault", directoryHint: .isDirectory),
                             support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        return try MemoStore(paths: paths)
    }

    @Test("글이 무엇인지에 따라 라벨이 바뀐다")
    func labels() async throws {
        let store = try makeStore()
        _ = try await store.create(body: "치과 예약 — 강남역")
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        #expect(model.intent == .nothing)
        model.query = "우유 사기"; #expect(model.intent == .memo)
        model.query = "내일 3시 치과"; #expect(model.intent == .calendar)
        model.query = "치과 언제였지?"; #expect(model.intent == .ask)
        model.query = "금요일 10시에 다시 알려줘"; #expect(model.intent == .command)
        // 고른 줄 + 시키는 말 → 그 줄에 적용. 고른 줄 + 그냥 글 → 열기.
        model.query = ""
        model.prepareForShow()
        model.moveSelection(1)
        #expect(model.intent == .open("치과 예약 — 강남역"))
        model.query = "금요일 10시에 다시 알려줘"
        #expect(model.intent == .applyTo("치과 예약 — 강남역"))
        if case .command(_, let target) = model.commit() { #expect(target != nil) } else { Issue.record("그 줄에 적용되지 않았다") }
    }

    @Test("후보 목록에서 줄을 고르면 「그 메모에게」— 같은 말을 그 메모에게 다시 한다")
    func pickCandidate() async throws {
        let store = try makeStore()
        let a = try await store.create(body: "지수 계좌")
        let b = try await store.create(body: "지수 생일")
        let model = QuickCaptureModel(store: store)
        model.showMemos([a.id, b.id], as: .candidates)
        #expect(model.listed.map(\.id) == [a.id, b.id])
        model.moveSelection(1)
        #expect(model.intent == .pick("지수 계좌"))
        #expect(model.commit() == .pick(a.id))
    }

    @Test("되묻기 중 esc 는 초안을 시각 없이 그대로 적는다")
    func escapeSavesDraft() throws {
        let model = QuickCaptureModel(store: try makeStore())
        model.query = "9월 30일에 친구랑 밥 먹기로 했어"
        _ = model.commit()
        #expect(model.pendingSummary?.contains("친구랑 밥 먹기로 했어") == true)
        let draft = model.takePendingDraft()
        #expect(draft?.body == "친구랑 밥 먹기로 했어")
        #expect(draft?.at == .keep)
        #expect(model.pendingQuestion == nil)
    }
}
