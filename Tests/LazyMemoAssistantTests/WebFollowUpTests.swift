import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 웹의 답 뒤에 오는 말 — 남기기·정리·붙이기를 읽고, 남길 글을 짓고, 붙이기가 되돌려진다.
@Suite("웹의 답 뒤 — 다음 손짓")
struct WebFollowUpTests {
    let weather = WebHit(title: "홈 - 기상청 날씨누리", url: URL(string: "https://www.weather.go.kr/")!,
                         snippet: "내일 경상권해안, 제주도 중심 비, 강풍과 풍랑 유의.")
    let meteo = WebHit(title: "서울 내일 날씨 - Meteocast", url: URL(string: "https://ko.meteocast.net/tomorrow/")!,
                       snippet: "해돋이 06:11, 일몰 18:45.")
    let naver = WebHit(title: "네이버 날씨", url: URL(string: "https://weather.naver.com/")!, snippet: "오늘·내일·모레 날씨.")

    @Test("「메모해」「정리해줘」「치과 메모에 추가해줘」— 셋을 가른다")
    func readsThreeMoves() {
        #expect(WebFollowUp.read("메모해") == .keep)
        #expect(WebFollowUp.read("메모해줘") == .keep)
        #expect(WebFollowUp.read("이거 메모로 남겨줘") == .keep)
        #expect(WebFollowUp.read("저장") == .keep)
        #expect(WebFollowUp.read("save this") == .keep)
        #expect(WebFollowUp.read("정리해줘") == .tidy)
        #expect(WebFollowUp.read("이 내용 요약해서 남겨") == .tidy)
        #expect(WebFollowUp.read("치과 메모에 추가해줘") == .append(hint: "치과"))
        #expect(WebFollowUp.read("장보기에 넣어줘") == .append(hint: "장보기"))
        #expect(WebFollowUp.read("치과 예약 메모에 붙여") == .append(hint: "치과 예약"))
    }

    @Test("「기존 메모에」「어디 메모에」는 가리킨 메모가 없다 — 고르게 한다")
    func appendWithoutTargetAsks() {
        #expect(WebFollowUp.read("기존 메모에 추가해줘") == .append(hint: nil))
        #expect(WebFollowUp.read("어디 메모에 추가해줘") == .append(hint: nil))
        #expect(WebFollowUp.read("메모에 붙여줘") == .append(hint: nil))
    }

    @Test("다른 내용이 든 말·물음·새 검색은 다음 손짓이 아니다")
    func otherWordsAreNotFollowUps() {
        // 우산을 적으라는 말이지 답을 남기라는 말이 아니다.
        #expect(WebFollowUp.read("내일 우산 챙기기 메모해") == nil)
        #expect(WebFollowUp.read("치과 언제였지?") == nil)
        #expect(WebFollowUp.read("웹에서 달러 환율 검색해줘") == nil)
        #expect(WebFollowUp.read("") == nil)
        #expect(WebFollowUp.read("금요일 10시에 다시 알려줘") == nil)
    }

    @Test("남길 글 — 답 한 줄, 인용한 출처마다 제목·발췌·주소, 끝에 어디서 찾았는지")
    func composesBody() {
        let hits = [weather, meteo, naver].map(Evidence.init(hit:))
        let answer = AssistantAnswer(found: true, text: "내일 서울은 비가 온대요", evidence: [hits[1].memoID],
                                     quotes: [meteo.snippet], sources: [WebSource(id: hits[1].memoID, title: meteo.title, url: meteo.url)])
        let body = WebFollowUp.body(question: "웹에서 서울 내일 날씨", answer: answer, results: hits, footer: "「서울 내일 날씨」 웹에서 찾음 · 9월 17일")
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.first == "내일 서울은 비가 온대요")
        // 인용한 것만 — 기상청·네이버는 화면에 있었을 뿐이다.
        #expect(body.contains(meteo.title) && body.contains(meteo.url.absoluteString) && body.contains(meteo.snippet))
        #expect(!body.contains(weather.title) && !body.contains(naver.url.absoluteString))
        #expect(lines.last == "「서울 내일 날씨」 웹에서 찾음 · 9월 17일")
    }

    @Test("답 문장이 없으면(모델 없이 결과만) 첫 줄은 물음이고, 보여 준 결과 셋이 실린다")
    func plainAnswerUsesQuestion() {
        let hits = [weather, meteo, naver].map(Evidence.init(hit:))
        let plain = OutputValidator.plainWebAnswer(hits)
        let body = WebFollowUp.body(question: "서울 내일 날씨 검색해줘", answer: plain, results: hits, footer: "꼬리")
        #expect(body.hasPrefix("서울 내일 날씨\n"))
        #expect(body.contains(weather.url.absoluteString) && body.contains(meteo.url.absoluteString) && body.contains(naver.url.absoluteString))
    }

    @Test("다듬을 글에는 주소가 없고, 다듬은 뒤에 출처와 꼬리가 도로 붙는다")
    func tidyDraftAndSources() {
        let hits = [weather, meteo].map(Evidence.init(hit:))
        let answer = AssistantAnswer(found: true, text: "내일 비", evidence: [hits[0].memoID], quotes: [weather.snippet],
                                     sources: [WebSource(id: hits[0].memoID, title: weather.title, url: weather.url)])
        let draft = WebFollowUp.draftForTidy(question: "서울 내일 날씨", answer: answer, results: hits)
        #expect(!draft.contains("https://"))
        #expect(draft.contains(weather.snippet))
        let done = WebFollowUp.attachSources(to: "- 내일 비\n- 강풍 유의", answer: answer, results: hits, footer: "꼬리")
        #expect(done.hasPrefix("- 내일 비\n- 강풍 유의\n\n"))
        #expect(done.contains("\(weather.title) — \(weather.url.absoluteString)"))
        #expect(done.hasSuffix("\n\n꼬리"))
    }

    @Test("붙이기는 끝에 한 줄 띄우고 잇고, 되돌리면 원래 본문이다")
    func appendAndUndo() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-append-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(vault: root.appending(path: "vault", directoryHint: .isDirectory),
                             support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try MemoService(paths: paths)
        let memo = try await service.create(body: "치과 예약 — 강남역")
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .appendToMemo, memoID: memo.id, expectedContentHash: memo.contentHash,
                                    patch: FieldPatch(body: "내일 비\nhttps://www.weather.go.kr/"))
        let receipt = try await executor.execute(action)
        #expect(receipt.after.body == "치과 예약 — 강남역\n\n내일 비\nhttps://www.weather.go.kr/")
        let back = try await executor.undo(receipt)
        #expect(back?.body == "치과 예약 — 강남역")
    }

    @Test("「어느 메모에 붙일까요?」도 「어느 메모?」다 — 목록이 후보가 된다")
    func whichMemoQuestionIsCandidates() {
        let ask = ProposedAction(requestID: UUID(), kind: .ask, question: WebFollowUp.whichMemo)
        #expect(AssistantIntent.asksWhichMemo(ask))
    }

    @Test("모델의 명령 스키마에 덧붙이기는 없다 — 말로 시켜도 앱이 만들지 않는다")
    func appendIsNotAModelCommand() {
        #expect(AssistantPrompts.jsonSchema(for: .command)?.contains("appendToMemo") == false)
        let request = AssistantRequest(task: .command, userText: "치과 메모에 추가해줘")
        let resolved = CommandResolver.resolve(RawCommand(kind: "appendToMemo"), request: request, selected: nil, candidates: [])
        #expect(resolved?.kind != .appendToMemo)
    }
}
