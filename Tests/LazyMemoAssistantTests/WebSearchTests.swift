import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 정해진 결과를 돌려주는 검색 — 또는 정해진 실패. `byQuery` 가 있으면 검색어마다 다르게 답한다.
struct StubSearcher: WebSearcher {
    var hits: [WebHit] = []
    var byQuery: [String: [WebHit]]?
    var failure: AssistantFailure?
    /// 실제로 던진 검색어 — 다시 던졌는지 본다.
    let asked = Asked()

    final class Asked: @unchecked Sendable {
        private let lock = NSLock()
        private var queries: [String] = []
        func add(_ q: String) { lock.withLock { queries.append(q) } }
        var all: [String] { lock.withLock { queries } }
    }

    func search(_ query: String, limit: Int) async throws -> [WebHit] {
        asked.add(query)
        if let failure { throw failure }
        return Array((byQuery?[query] ?? (byQuery == nil ? hits : [])).prefix(limit))
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

    @Test("검색어 — 시키는 말·군더더기는 떼고 이름·숫자·날짜는 그대로")
    func stripsFillerKeepsFacts() {
        #expect(WebQuery.make(from: "2026년 최저임금 얼마인지 좀 알려줘") == "2026년 최저임금 얼마인지")
        #expect(WebQuery.make(from: "아이폰 17 프로 가격 궁금해!") == "아이폰 17 프로 가격")
        #expect(WebQuery.make(from: "Swift 6.2 릴리스 노트 찾아줘") == "Swift 6.2 릴리스 노트")
        #expect(WebQuery.make(from: "please tell me the KTX 첫차 시간") == "the KTX 첫차 시간")
        // 물음표·따옴표는 떼도 낱말은 남는다.
        #expect(WebQuery.make(from: "「서울 내일 날씨」?") == "서울 내일 날씨")
    }

    @Test("다시 던지는 검색어 — 물음말·풀이말을 떼고 알맹이만, 글자는 원문 그대로")
    func simplifiesForRetry() {
        #expect(WebQuery.simplify(from: "내년 최저임금이 얼마나 오르는지 알려줘") == "내년 최저임금이")
        // 숫자·판 번호는 살아남는다 — 이것이 빠지면 다시 던져도 소용이 없다.
        #expect(WebQuery.simplify(from: "Swift 6.2 에서 뭐가 바뀌었는지 검색해줘") == "Swift 6.2")
        // 줄일 것이 없으면 같은 글이다 — 그러면 코디네이터는 같은 검색을 두 번 던지지 않는다.
        #expect(WebQuery.simplify(from: "서울 내일 날씨") == WebQuery.make(from: "서울 내일 날씨"))
    }

    @Test("엔티티는 풀되 `&amp;` 는 맨 나중에 — 글에 적힌 「&lt;」가 태그가 되지 않게")
    func decodesEntitiesInOrder() {
        #expect(DuckDuckGoHTML.decode("a &amp;lt; b") == "a &lt; b")
        #expect(DuckDuckGoHTML.decode("605.2 km&sup2; &mdash; 25 gu") == "605.2 km² — 25 gu")
        #expect(DuckDuckGoHTML.decode("&#54620;&#44544;") == "한글")
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

@Suite("AssistantCoordinator — 페이지 본문 근거")
struct WebPageEvidenceTests {
    let profile = ModelProfile(profileID: "test")
    let weather = WebHit(title: "홈 - 기상청 날씨누리", url: URL(string: "https://www.weather.go.kr/")!,
                         snippet: "내일 서울 흐리고 낮 최고 24도")
    let meteo = WebHit(title: "서울 내일 날씨 - Meteocast", url: URL(string: "https://ko.meteocast.net/tomorrow/")!,
                       snippet: "해돋이 06:11")
    let naver = WebHit(title: "네이버 날씨", url: URL(string: "https://weather.naver.com/")!, snippet: "오늘·내일·모레")
    let wiki = WebHit(title: "서울 - 위키백과", url: URL(string: "https://ko.wikipedia.org/wiki/Seoul")!, snippet: "대한민국의 수도")

    func run(_ provider: MockProvider, _ searcher: StubSearcher, _ fetcher: StubFetcher?, _ text: String) async -> (events: [AssistantEvent], evidence: [Evidence]) {
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: []), web: searcher,
                                     pages: fetcher, profile: profile)
        var out: [AssistantEvent] = []
        var captured: [Evidence] = []
        for await e in await c.run(AssistantRequest(task: .webAnswer, userText: text)) {
            if case .evidence(let list) = e { captured = list }
            out.append(e)
        }
        return (out, captured)
    }

    @Test("앞의 세 쪽은 본문까지 읽어 모델에게 준다 — 발췌는 그대로 남고 화면은 그것을 그린다")
    func feedsPageBodies() async {
        let provider = MockProvider([])
        provider.answerFor = { prompt in
            let id = prompt.user.components(separatedBy: "[결과 ")[1].prefix(26)
            return #"{"found": true, "answer": "내일 서울은 오후부터 비", "evidence": ["\#(id)"]}"#
        }
        let fetcher = StubFetcher(pages: [
            weather.url.absoluteString: "내일(9월 19일) 서울은 대체로 흐리겠고 오후 3시부터 비가 내리겠습니다. 아침 최저 18도, 낮 최고 24도.",
            meteo.url.absoluteString: "Sunrise 06:11, sunset 18:45.",
        ])
        let (out, evidence) = await run(provider, StubSearcher(hits: [weather, meteo, naver, wiki]), fetcher, "웹에서 서울 내일 날씨 검색해줘")
        // 본문까지 읽는 것은 앞의 셋뿐 — 넷째는 발췌로 남는다 (`PageBudget.maxPages`).
        #expect(fetcher.seen.all.count == 3)
        #expect(evidence.count == 4)
        #expect(evidence[0].passage?.contains("오후 3시부터") == true)
        // 못 읽은 쪽은 발췌가 근거다 — 그래도 목록에서 빠지지 않는다.
        #expect(evidence[2].passage == nil)
        #expect(evidence[2].excerpt == naver.snippet)
        // 화면이 그리는 것은 여전히 발췌다.
        #expect(evidence[0].excerpt == weather.snippet)
        let prompt = provider.prompts.first
        #expect(prompt?.user.contains("본문: 내일(9월 19일)") == true)
        #expect(prompt?.user.contains("발췌: \(weather.snippet)") == true)
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.text == "내일 서울은 오후부터 비")
    }

    @Test("본문을 한 쪽도 못 읽어도 답은 나온다 — 발췌로 물러난다")
    func fallsBackToSnippetsWhenFetchFails() async {
        let provider = MockProvider([])
        provider.answerFor = { prompt in
            let id = prompt.user.components(separatedBy: "[결과 ")[1].prefix(26)
            return #"{"found": true, "answer": "낮 최고 24도", "evidence": ["\#(id)"]}"#
        }
        let fetcher = StubFetcher(pages: [:])
        let (out, evidence) = await run(provider, StubSearcher(hits: [weather, meteo]), fetcher, "웹에서 서울 내일 날씨")
        #expect(evidence.allSatisfy { $0.passage == nil })
        #expect(provider.prompts.first?.user.contains("본문:") == false)
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.text == "낮 최고 24도")
    }

    @Test("첫 검색이 빈손이면 더 짧은 검색어로 한 번 더 던진다")
    func retriesWithSimplerQuery() async {
        let provider = MockProvider([])
        provider.answerFor = { prompt in
            let id = prompt.user.components(separatedBy: "[결과 ")[1].prefix(26)
            return #"{"found": true, "answer": "2026년 최저임금은 시간당 10,320원", "evidence": ["\#(id)"]}"#
        }
        let wage = WebHit(title: "최저임금위원회", url: URL(string: "https://www.minimumwage.go.kr/")!,
                          snippet: "2026년 최저임금은 시간당 10,320원으로 2025년보다 2.9% 올랐습니다")
        let searcher = StubSearcher(byQuery: ["2026년 최저임금이": [wage]])
        let (out, evidence) = await run(provider, searcher, nil, "2026년 최저임금이 얼마나 오르는지 검색해줘")
        // 문장째 던져 빈손 → 물음말·풀이말을 뗀 말로 한 번 더.
        #expect(searcher.asked.all == ["2026년 최저임금이 얼마나 오르는지", "2026년 최저임금이"])
        #expect(evidence.count == 1)
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.text == "2026년 최저임금은 시간당 10,320원")
    }

    @Test("두 번 던져도 빈손이면 「웹에서 찾지 못했습니다」 — 모델은 부르지 않는다")
    func twiceEmptyGivesUp() async {
        let provider = MockProvider([])
        let searcher = StubSearcher(byQuery: [:])
        let (out, _) = await run(provider, searcher, nil, "웹에서 있지도 않은 낱말 얼마나 되는지 검색해줘")
        #expect(out.last == .failed(.webEmpty))
        #expect(provider.prompts.isEmpty)
        #expect(searcher.asked.all.count == 2)
    }

    @Test("줄일 것이 없으면 같은 검색을 두 번 던지지 않는다")
    func doesNotRepeatIdenticalQuery() async {
        let provider = MockProvider([])
        let searcher = StubSearcher(byQuery: [:])
        let (out, _) = await run(provider, searcher, nil, "서울 내일 날씨")
        #expect(out.last == .failed(.webEmpty))
        #expect(searcher.asked.all == ["서울 내일 날씨"])
    }

    @Test("정리는 다시 검색하지 않는다 — 앱이 쥔 초안을 모델이 다듬는다")
    func digestDoesNotSearchAgain() async {
        let provider = MockProvider(["내일 서울은 흐립니다.\n\n## 핵심\n- 낮 최고 24도"])
        let searcher = StubSearcher(hits: [weather])
        let c = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: []), web: searcher, profile: profile)
        var out: [AssistantEvent] = []
        for await e in await c.run(AssistantRequest(task: .digest, userText: "물음: 서울 내일 날씨\n\n[1] 기상청\n낮 최고 24도")) { out.append(e) }
        #expect(searcher.asked.all.isEmpty)
        guard case .completed(.tidied(let written)) = out.last else { Issue.record("\(out)"); return }
        #expect(written.contains("## 핵심"))
        #expect(provider.prompts.first?.system.contains("메모 한 장으로 정리") == true)
    }

    @Test("맥에 `claude` 가 있으면 웹의 답·다듬기·정리만 그쪽에 맡긴다")
    func cliTakesWebAndTidyOnly() async {
        #expect(AssistantCoordinator.prefersCLI(.webAnswer))
        #expect(AssistantCoordinator.prefersCLI(.tidy))
        #expect(AssistantCoordinator.prefersCLI(.digest))
        // 메모에서 답 찾기·시키기는 메모 본문이 나가는 일이라 언제나 이 기기 안이다 (DESIGN §9.3).
        #expect(!AssistantCoordinator.prefersCLI(.answer))
        #expect(!AssistantCoordinator.prefersCLI(.command))
        #expect(!AssistantCoordinator.prefersCLI(.brief))

        let local = MockProvider([#"{"found": false, "answer": "", "evidence": []}"#])
        let cli = MockProvider([])
        cli.answerFor = { prompt in
            let id = prompt.user.components(separatedBy: "[결과 ")[1].prefix(26)
            return #"{"found": true, "answer": "claude 가 답했다", "evidence": ["\#(id)"]}"#
        }
        let c = AssistantCoordinator(provider: local, evidence: MemorySource(memos: []), web: StubSearcher(hits: [weather]), profile: profile)
        await c.adopt(cli: cli)
        var out: [AssistantEvent] = []
        for await e in await c.run(AssistantRequest(task: .webAnswer, userText: "웹에서 서울 내일 날씨")) { out.append(e) }
        #expect(local.prompts.isEmpty)
        #expect(cli.prompts.count == 1)
        guard case .completed(.answer(let a)) = out.last else { Issue.record("\(out)"); return }
        #expect(a.text == "claude 가 답했다")
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

    @Test("검색 → 앞의 세 쪽 본문 → 모델 없이 정리한 메모 한 장")
    func searchThenReadThenDigest() async throws {
        let question = "2026년 최저임금 얼마야?"
        let hits = try await DuckDuckGoSearcher(locale: Locale(identifier: "ko_KR")).search(WebQuery.make(from: question), limit: 5)
        var evidence = hits.map(Evidence.init(hit:))
        let reader = WebPageReader()
        let budget = PageBudget.perSource(PageBudget.maxPages)
        for index in evidence.indices.prefix(PageBudget.maxPages) {
            guard let url = evidence[index].url, let page = await reader.read(url) else {
                print("본문 못 읽음: \(evidence[index].url?.host() ?? "?")")
                continue
            }
            evidence[index].passage = Readable.clip(page.text, to: budget)
            print("본문 \(evidence[index].passage?.count ?? 0)자 — \(url.host() ?? "")")
        }
        #expect(evidence.contains { $0.passage?.isEmpty == false })
        // 모델 없이도 자리는 갖춰진다 — 실모델이 쓴 가운데는 `Digest.assemble` 이 같은 틀에 끼운다.
        let body = Digest.compose(question: question, answer: OutputValidator.plainWebAnswer(evidence),
                                  results: evidence, footer: "「\(WebQuery.make(from: question))」 웹에서 찾음 · 9월 18일")
        print("--- 정리한 메모 ---\n\(body)\n---")
        #expect(Digest.problems(in: body).isEmpty)
    }
}
