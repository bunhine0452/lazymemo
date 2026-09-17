import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 정해진 결과를 돌려주는 검색 — 또는 정해진 실패.
struct StubSearcher: WebSearcher {
    var hits: [WebHit] = []
    var failure: AssistantFailure?
    func search(_ query: String, limit: Int) async throws -> [WebHit] {
        if let failure { throw failure }
        return Array(hits.prefix(limit))
    }
}

@Suite("웹 검색")
struct WebSearchTests {
    static let fixture: String = {
        let url = AssistantFixtures.directory.appending(path: "duckduckgo-html.html")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    @Test("DDG HTML 판에서 제목·주소·발췌를 읽는다 — 2026-09-17 「서울 내일 날씨」 실물")
    func parsesDuckDuckGoHTML() {
        let hits = DuckDuckGoHTML.parse(Self.fixture)
        #expect(hits.count == 10)
        #expect(hits[1].title == "홈 - 기상청 날씨누리")
        #expect(hits[1].url.absoluteString == "https://www.weather.go.kr/")
        // `<b>내일</b>` 은 걷히고, 문장은 그대로.
        #expect(hits[1].snippet.hasPrefix("내일 경상권해안, 제주도 중심 비"))
        // `&amp;` 는 풀린다 — 주소의 쿼리가 그대로 열려야 한다.
        #expect(hits[2].url.query()?.contains("gid=1835848&language=korean") == true)
        #expect(hits.allSatisfy { $0.url.scheme == "https" })
    }

    @Test("감싼 주소(uddg=)와 광고는 걸러진다")
    func unwrapsRedirectsAndSkipsAds() {
        let html = """
        <div class="result results_links results_links_deep result--ad"><a rel="nofollow" class="result__a" href="https://ad.example/">광고</a><a class="result__snippet" href="https://ad.example/">사세요</a></div>
        <div class="result results_links results_links_deep web-result"><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fa%3Fb%3D1&amp;rut=abc">Example &amp; Co</a><a class="result__snippet" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fa">a  b
        c</a></div>
        """
        let hits = DuckDuckGoHTML.parse(html)
        #expect(hits.count == 1)
        #expect(hits[0].url.absoluteString == "https://example.org/a?b=1")
        #expect(hits[0].title == "Example & Co")
        #expect(hits[0].snippet == "a b c")
    }

    @Test("결과 없음 페이지와 봇 확인 페이지를 가른다")
    func distinguishesEmptyFromBlocked() {
        #expect(DuckDuckGoHTML.saysNoResults("<div class=\"no-results\">No results.</div>"))
        #expect(!DuckDuckGoHTML.saysNoResults("<html><body>anomaly</body></html>"))
    }

    @Test("검색어 — 「검색해줘」·「웹에서」·물음표만 떼고 나머지는 그대로")
    func makesQuery() {
        #expect(WebQuery.make(from: "웹에서 서울 내일 날씨 검색해줘") == "서울 내일 날씨")
        #expect(WebQuery.make(from: "달러 환율 얼마야?") == "달러 환율 얼마야")
        #expect(WebQuery.make(from: "구글 캘린더 공유 방법 알려줘") == "구글 캘린더 공유 방법")
        // 다 떼면 원문.
        #expect(WebQuery.make(from: "검색해줘") == "검색해줘")
    }

    @Test("「웹에서」·「검색해줘」·「구글」은 웹, 「인터넷 요금」·「치과 언제였지」는 메모")
    func classifiesWebWords() {
        #expect(AssistantIntent.classify("웹에서 서울 날씨 알려줘") == .webAnswer)
        #expect(AssistantIntent.classify("달러 환율 검색해줘") == .webAnswer)
        #expect(AssistantIntent.classify("구글에서 파이썬 3.13 뭐가 바뀌었는지") == .webAnswer)
        #expect(AssistantIntent.classify("인터넷 요금 언제 냈지?") == .answer)
        #expect(AssistantIntent.classify("치과 예약 언제였지") == .answer)
        #expect(AssistantIntent.classify("금요일 10시에 다시 알려줘") == .command)
    }
}

@Suite("AssistantCoordinator — 웹")
struct WebCoordinatorTests {
    let profile = ModelProfile(profileID: "test")
    let weather = WebHit(title: "홈 - 기상청 날씨누리", url: URL(string: "https://www.weather.go.kr/")!,
                         snippet: "내일 서울 흐리고 낮 최고 24도, 경상권해안 비")
    let other = WebHit(title: "서울 내일 날씨 - Meteocast", url: URL(string: "https://ko.meteocast.net/tomorrow/")!,
                       snippet: "해돋이 06:11, 일몰 18:45")

    func events(_ provider: MockProvider, _ searcher: StubSearcher, _ text: String) async -> [AssistantEvent] {
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: []), web: searcher, profile: profile)
        var out: [AssistantEvent] = []
        for await e in await c.run(AssistantRequest(task: .webAnswer, userText: text)) { out.append(e) }
        return out
    }

    @Test("검색 결과가 근거다 — 모델은 「[결과 …]」를 읽고, 답 밑에 출처 링크가 선다")
    func answersFromHits() async {
        let provider = MockProvider([])
        // 근거 id 는 요청 안에서 새로 나므로, prompt 의 첫 「[결과 …]」 id 를 인용해 답한다.
        provider.answerFor = { prompt in
            let id = prompt.user.components(separatedBy: "[결과 ")[1].prefix(26)
            return #"{"found": true, "answer": "내일 서울은 흐리고 낮 최고 24도", "evidence": ["\#(id)"]}"#
        }
        var captured: [Evidence] = []
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: []), web: StubSearcher(hits: [weather, other]), profile: profile)
        var out: [AssistantEvent] = []
        for await e in await c.run(AssistantRequest(task: .webAnswer, userText: "웹에서 서울 내일 날씨 검색해줘")) {
            if case .evidence(let list) = e { captured = list }
            out.append(e)
        }
        #expect(captured.count == 2)
        #expect(captured.allSatisfy { $0.isWeb })
        let prompt = provider.prompts.first
        #expect(prompt?.user.contains("[결과 \(captured[0].memoID)]") == true)
        #expect(prompt?.user.contains("출처: www.weather.go.kr") == true)
        #expect(prompt?.system.contains("웹 검색 결과") == true)
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.isWeb)
        #expect(a.text == "내일 서울은 흐리고 낮 최고 24도")
        #expect(a.sources.map(\.url) == [weather.url])
        #expect(a.sources[0].host == "weather.go.kr")
        #expect(a.quotes == [weather.snippet])
    }

    @Test("모델이 못 찾으면 「웹에서 찾지 못했습니다」— 메모 낱말이 아니다")
    func modelFindsNothing() async {
        let provider = MockProvider([#"{"found": false, "answer": "", "evidence": []}"#])
        let out = await events(provider, StubSearcher(hits: [other]), "웹에서 화성 날씨")
        #expect(out.last == .failed(.webEmpty))
    }

    @Test("검색이 비면 모델을 부르지 않고 「웹에서 찾지 못했습니다」")
    func emptySearchSkipsModel() async {
        let provider = MockProvider([])
        let out = await events(provider, StubSearcher(hits: []), "웹에서 아무거나")
        #expect(out.last == .failed(.webEmpty))
        #expect(provider.prompts.isEmpty)
    }

    @Test("검색이 막히면 「웹에 닿지 못했습니다」")
    func blockedSearchFails() async {
        let out = await events(MockProvider([]), StubSearcher(failure: .webUnavailable), "웹에서 서울 날씨")
        #expect(out.last == .failed(.webUnavailable))
    }

    @Test("검색 창구가 없으면(시험·렌더) 「웹에 닿지 못했습니다」")
    func noSearcher() async {
        let c = AssistantCoordinator(provider: MockProvider([]), evidence: MemorySource(memos: []), profile: profile)
        var out: [AssistantEvent] = []
        for await e in await c.run(AssistantRequest(task: .webAnswer, userText: "웹에서 서울 날씨")) { out.append(e) }
        #expect(out.last == .failed(.webUnavailable))
    }

    @Test("모델이 없어도 결과 셋은 그대로 보여 준다 — 문장 없이 출처와 발췌만")
    func withoutModelShowsRawHits() async {
        let provider = MockProvider([])
        provider.ready = false
        let out = await events(provider, StubSearcher(hits: [weather, other]), "웹에서 서울 날씨")
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.found)
        #expect(a.text.isEmpty)
        #expect(a.sources.map(\.url) == [weather.url, other.url])
        #expect(a.quotes == [weather.snippet, other.snippet])
        #expect(provider.prompts.isEmpty)
    }

    @Test("메모 질문에 걸리는 메모가 한 장도 없으면 모델을 부르지 않는다 — 바로 「찾지 못했습니다」")
    func memoQuestionWithoutCandidatesSkipsModel() async {
        let provider = MockProvider([#"{"found": true, "answer": "지어낸 말", "evidence": []}"#])
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: []), profile: profile)
        var out: [AssistantEvent] = []
        for await e in await c.run(AssistantRequest(task: .answer, userText: "달러 환율 얼마야?")) { out.append(e) }
        #expect(out.last == .failed(.noEvidence))
        #expect(provider.prompts.isEmpty)
    }
}

/// 실제 DuckDuckGo — `LAZYMEMO_LIVE_WEB=1` 일 때만 (망이 필요하고, DDG 가 모양을 바꾸면 여기가 먼저 빨개진다).
@Suite("DuckDuckGo · 실접속", .enabled(if: ProcessInfo.processInfo.environment["LAZYMEMO_LIVE_WEB"] == "1"))
struct LiveDuckDuckGoTests {
    @Test("한국어 질문에 제목·주소·발췌가 온다")
    func koreanQuery() async throws {
        let hits = try await DuckDuckGoSearcher(locale: Locale(identifier: "ko_KR")).search("서울 내일 날씨", limit: 5)
        print("DDG 실접속: \(hits.count)건 — \(hits.map { "\($0.title) <\($0.url.host() ?? "")>" })")
        #expect(hits.count == 5)
        #expect(hits.allSatisfy { !$0.title.isEmpty && $0.url.scheme == "https" })
        #expect(hits.contains { !$0.snippet.isEmpty })
    }
}
