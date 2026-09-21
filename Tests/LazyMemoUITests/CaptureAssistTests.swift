import Foundation
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 한 상자가 적기·찾기에 더해 **묻기·시키기·되묻기**를 겸한다 — 다만 **기본 ⌘⏎ 는 적는다** (인계서 묶음 3).
///
/// 앞선 판은 글이 무엇인지를 앱이 가렸다 — 물음표면 비서, 「알림」「폴더」가 들어 있으면 시키는 말. 그러면
/// 「왜 고객이 이탈할까?」「알림 문구 아이디어」가 메모가 되지 않았다. 이제 비서에게는 ⌥⌘⏎ / ✦ (`commitAsk`)로만
/// 가고, 사람이 이미 비서와 이야기 중일 때만 ⌘⏎ 가 그 대화를 잇는다.
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

    @Test("⌘⏎ 는 적는다 — 물음도, 동사가 든 말도. 비서에게는 ⌥⌘⏎ 로만")
    func routing() throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        model.query = "치과 언제였지?"
        #expect(model.commit() == .create(QuickCaptureModel.Draft(text: "치과 언제였지?", due: nil, at: nil)))
        model.query = "우유 사기"
        #expect(model.commit() == .create(QuickCaptureModel.Draft(text: "우유 사기", due: nil, at: nil)))

        // 비서가 없으면 ⌥⌘⏎ 도 아무 일도 없다 — 모델 없는 기계에서도 적기는 산다.
        model.query = "치과 언제였지?"
        #expect(model.commitAsk() == .nothing)
        #expect(model.askIntent == nil)

        let assistant = AssistantModel(service: store.service, support: FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-assist-route-\(UUID().uuidString)", directoryHint: .isDirectory))
        model.assistant = assistant
        #expect(model.commit() == .create(QuickCaptureModel.Draft(text: "치과 언제였지?", due: nil, at: nil)), "비서가 있어도 ⌘⏎ 는 적는다")
        #expect(model.askIntent == .ask)
        #expect(model.commitAsk() == .ask("치과 언제였지?"))
        model.query = "금요일 10시에 다시 알려줘"
        #expect(model.askIntent == .command)
        #expect(model.commitAsk() == .command("금요일 10시에 다시 알려줘", target: nil))
        model.query = "웹에서 서울 날씨 알려줘"
        #expect(model.commitAsk() == .searchWeb("웹에서 서울 날씨 알려줘"))
    }

    /// 인계서 묶음 3 의 회귀 사례 — 저장 뜻의 글 30개는 전부 기록으로 남는다. 한국어/영어/물음표/명령형/인용문/긴 글.
    @Test("저장 뜻의 글은 전부 기록으로 남는다 — 물음표·왜·어디·알림·폴더가 들어 있어도", arguments: [
        "왜 고객이 이탈할까?", "어디서든 일하기", "알림 문구 아이디어", "폴더 구조 초안", "우유 사기",
        "내일 3시 치과 @강남역", "회의록 정리해서 보내기", "지워야 할 파일 목록", "메모 앱 아이디어: 태그 없이",
        "언제 이사 갈지 생각해 보기", "누가 발표하지?", "Why do customers churn?", "Work from anywhere",
        "Reminder copy ideas", "Folder structure draft", "Buy milk", "Dentist tomorrow 3pm @Gangnam",
        "What did she say about the deadline?", "\"게으른 사람을 위한 메모\" — 책 제목 후보", "「알림은 방해다」라는 말",
        "다시 보기 기능은 왜 필요한가", "오늘 뭐 먹지?", "비밀번호 힌트: 강아지 이름", "엄마 생신 선물 — 스카프?",
        "주말에 뭐 하지", "보고서 마감 언제였더라", "치과 언제였지?", "회의 옮겨야 하나?",
        "10월 3일까지 보고서 제출하고 팀에 공유하고 피드백 받아서 다시 정리한 뒤 최종본을 대표에게 보내기 — 그 전에 표지 디자인도 새로 뽑아야 한다",
        "알림 꺼 둘까? 폴더도 정리하고… 그냥 다 지워 버릴까 싶기도 하고",
    ])
    func savesEveryWritingIntent(text: String) throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        model.assistant = AssistantModel(service: store.service, support: FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-assist-30-\(UUID().uuidString)", directoryHint: .isDirectory))
        model.query = text
        switch model.commit() {
        case .create(let draft): #expect(!draft.text.isEmpty)
        case .compose(let patch): #expect(!(patch.body ?? "").isEmpty)
        case let other: Issue.record("적지 않았다: \(other) — \(text)")
        }
        #expect(model.intent == .memo || model.intent == .calendar)
        #expect(model.pendingQuestion == nil, "되묻지 않는다")
    }

    @Test("「웹에서 …」·「… 검색해줘」는 바로 웹, 메모에서 못 찾은 뒤의 빈 상자 ⌘↵ 도 웹 — 글을 고치면 권유는 물러난다")
    func webRouting() throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        model.query = "웹에서 서울 내일 날씨 알려줘"
        #expect(model.intent == .calendar, "⌘⏎ 는 적는다 — 「내일」은 날짜로 읽힌 채")
        #expect(model.askIntent == nil, "비서가 없으면 물을 곳이 없다")
        // 권유 없는 빈 상자는 닫기다.
        model.query = ""
        #expect(model.intent == .nothing)
        #expect(model.commit() == .nothing)

        let assistant = AssistantModel(service: store.service, support: FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-assist-web-\(UUID().uuidString)", directoryHint: .isDirectory))
        model.assistant = assistant
        model.query = "웹에서 서울 내일 날씨 알려줘"
        #expect(model.askIntent == .web)
        #expect(model.commitAsk() == .searchWeb("웹에서 서울 내일 날씨 알려줘"))
        model.query = "달러 환율 검색해줘"
        #expect(model.commitAsk() == .searchWeb("달러 환율 검색해줘"))
        model.query = ""
        assistant.stageForPreview(failed: "메모에서 근거를 찾지 못했습니다", offersWeb: "달러 환율 얼마야?")
        // 못 찾은 뒤의 빈 ⌘↵ 는 사람이 이미 비서와 이야기 중인 것이라 웹으로 간다.
        #expect(model.intent == .web)
        #expect(model.commit() == .searchWeb("달러 환율 얼마야?"))
        // 새 글을 치면 권유는 잊는다 — 옛 물음이 몰래 나가지 않는다.
        model.query = "우유"
        #expect(assistant.offersWeb == nil)
        #expect(model.intent == .memo)
    }

    @Test("웹의 답이 서 있으면 「메모해」「정리해줘」「치과 메모에 추가해줘」는 그 답에 대한 말이고, 치는 동안 답이 남는다")
    func webFollowUpRouting() throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        let assistant = AssistantModel(service: store.service, support: FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-assist-follow-\(UUID().uuidString)", directoryHint: .isDirectory))
        model.assistant = assistant
        // 답이 없을 때의 「메모해」는 평소의 글이다 — ⌘⏎ 는 적고, ⌥⌘⏎ 라야 시키는 말.
        model.query = "메모해"
        #expect(model.intent == .memo)
        #expect(model.askIntent == .command)

        let hit = Evidence(hit: WebHit(title: "기상청", url: URL(string: "https://www.weather.go.kr/")!, snippet: "내일 비"))
        assistant.stageForPreview(answer: AssistantAnswer(found: true, text: "내일 서울은 비", evidence: [hit.memoID], quotes: ["내일 비"],
                                                          sources: [WebSource(id: hit.memoID, title: "기상청", url: hit.url!)]),
                                  results: [hit], question: "웹에서 서울 내일 날씨")
        #expect(assistant.followUps == [.keep, .append(hint: nil)])   // 모델이 없으니 정리는 빠진다.
        #expect(assistant.webResults.map(\.cited) == [true])
        model.query = "메모해"
        #expect(assistant.answer != nil)   // 글을 쳐도 웹의 답은 남는다 — 이 말이 그 답에 대한 것이다.
        #expect(model.intent == .followUp(.keep))
        #expect(model.commit() == .followUp(.keep))
        model.query = "치과 메모에 추가해줘"
        #expect(model.intent == .followUp(.append(hint: "치과")))
        model.query = "정리해줘"
        #expect(model.commit() == .followUp(.tidy))
        // 답에 대한 말이 아니면 평소대로 — 우산은 새 메모다.
        model.query = "우산 챙기기"
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

    @Test("날짜·자리가 든 서술은 그대로 메모가 되고, 약속인데 시각이 없으면 **묻지 않고** 날짜만으로 적는다")
    func composeWithoutAsking() throws {
        let model = QuickCaptureModel(store: try makeStore())
        model.query = "10월 3일까지 보고서 제출"
        guard case .compose(let patch) = model.commit() else { Issue.record("compose 가 아니다"); return }
        #expect(patch.due == .set(CalendarDate(year: 2026, month: 10, day: 3)) || patch.due != .keep)
        #expect(patch.body == "보고서 제출")

        model.query = "9월 30일에 @홍대입구 친구랑 밥 먹기로 했어"
        guard case .compose(let dated) = model.commit() else { Issue.record("날짜만으로 적지 않았다"); return }
        #expect(dated.place == "홍대입구")
        #expect(dated.due == .set(CalendarDate(year: 2026, month: 9, day: 30)))
        #expect(dated.at == .keep)
        #expect(model.pendingQuestion == nil, "되묻지 않는다 — 시각은 결과 카드의 선택 행동")
    }

    @Test("결과 카드 — 날짜만 있는 약속은 「시각 정하기」를, 자리 있는 약속은 「가는 길 찾기」를 권하고, 상자는 다음 글을 받는다")
    func leftCardOffers() async throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        let dated = try await store.create(body: "친구랑 밥", due: CalendarDate(year: 2026, month: 9, day: 30), place: "홍대입구")
        #expect(model.show(left: dated))
        #expect(model.left?.offersTime == true)
        #expect(model.left?.offersRoute == false, "설정(플래너)이 없으면 길은 권하지 않는다")

        // 다음 글은 새 메모다 — 앞 메모의 답이 아니다.
        model.query = "우유 사기"
        #expect(model.left == nil, "첫 글자에 카드는 물러난다")
        #expect(model.commit() == .create(QuickCaptureModel.Draft(text: "우유 사기", due: nil, at: nil)))
        #expect(model.pendingQuestion == nil)

        // 「시각 정하기」를 눌러야 그때 묻고, 답은 **그 메모**에 적힌다.
        model.query = ""
        model.show(left: dated)
        model.offerTime()
        #expect(model.pendingQuestion == "약속 시간이 언제인가요?")
        #expect(model.left == nil)
        model.query = "12시야"
        guard case .setTime(let id, let at) = model.commit() else { Issue.record("그 메모의 시각으로 가지 않았다"); return }
        #expect(id == dated.id)
        #expect(Calendar.current.dateComponents([.hour, .minute], from: at) == DateComponents(hour: 12, minute: 0))
        #expect(model.pendingQuestion == nil)

        // 「시각 없이」— 그 메모는 날짜만 든 채 그대로, 새 메모도 없다.
        model.show(left: dated)
        model.offerTime()
        model.query = "없어"
        #expect(model.commit() == .nothing)
        #expect(model.takePendingDraft() == nil)

        // 권할 것이 없는 메모는 카드가 서지 않는다 (상자는 닫힌다).
        let plain = try await store.create(body: "우유 사기")
        #expect(!model.show(left: plain))
        #expect(model.left == nil)
    }

    @Test("되물음에 딴 말을 하면 초안은 놓고 새 말로 본다 — 새 말도 적는다")
    func replyThatIsNotAnAnswer() async throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        let dated = try await store.create(body: "친구랑 밥", due: CalendarDate(year: 2026, month: 9, day: 30))
        model.show(left: dated)
        model.offerTime()
        model.query = "치과 언제였지?"
        #expect(model.commit() == .create(QuickCaptureModel.Draft(text: "치과 언제였지?", due: nil, at: nil)))
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
        model.query = "치과 언제였지?"; #expect(model.intent == .memo)
        model.query = "금요일 10시에 다시 알려줘"; #expect(model.intent == .calendar)
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

    @Test("「시각 정하기」 중 esc 는 아무것도 새로 적지 않는다 — 그 메모는 날짜만 든 채 이미 있다")
    func escapeDuringTimeQuestion() async throws {
        let store = try makeStore()
        let model = QuickCaptureModel(store: store)
        let dated = try await store.create(body: "친구랑 밥 먹기로 했어", due: CalendarDate(year: 2026, month: 9, day: 30))
        model.show(left: dated)
        model.offerTime()
        #expect(model.pendingSummary?.contains("친구랑 밥 먹기로 했어") == true)
        #expect(model.takePendingDraft() == nil)
        #expect(model.pendingQuestion == nil)
    }
}
