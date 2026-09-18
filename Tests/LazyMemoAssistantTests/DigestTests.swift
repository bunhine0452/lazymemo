import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 「정리해서 남기기」가 내는 메모 — 어떤 데이터가 와도 자리가 같다.
@Suite("정리해서 남기기 — 메모의 자리")
struct DigestTests {
    let weather = WebHit(title: "홈 - 기상청 날씨누리", url: URL(string: "https://www.weather.go.kr/")!,
                         snippet: "내일 서울 흐리고 낮 최고 24도, 오후부터 비")
    let meteo = WebHit(title: "서울 내일 날씨 - Meteocast", url: URL(string: "https://ko.meteocast.net/tomorrow/")!,
                       snippet: "해돋이 06:11, 일몰 18:45, 강수 확률 60%")
    let footer = "「서울 내일 날씨」 웹에서 찾음 · 9월 18일"

    func answered(_ hits: [Evidence], text: String = "내일 서울은 흐리고 낮 최고 24도입니다") -> AssistantAnswer {
        AssistantAnswer(found: true, text: text, evidence: hits.map(\.memoID), quotes: hits.map(\.excerpt),
                        sources: hits.compactMap { e in e.url.map { WebSource(id: e.memoID, title: e.title ?? "", url: $0) } })
    }

    @Test("모델이 쓴 가운데를 앱의 틀에 끼운다 — 제목·출처·꼬리는 앱의 것")
    func assemblesModelOutput() {
        let hits = [weather, meteo].map(Evidence.init(hit:))
        let written = """
        내일 서울은 흐리고 낮 최고 24도입니다.

        ## 핵심
        - 아침 최저 18도, 낮 최고 24도
        - 오후 3시부터 비, 강수 확률 60%

        ## 세부
        | 시각 | 기온 |
        | --- | --- |
        | 09시 | 19도 |
        """
        let body = Digest.assemble(question: "웹에서 서울 내일 날씨 검색해줘", answer: answered(hits),
                                   written: written, results: hits, footer: footer)
        #expect(Digest.problems(in: body).isEmpty)
        #expect(body.hasPrefix("# 서울 내일 날씨\n"))
        #expect(body.contains("## 핵심"))
        #expect(body.contains("| 시각 | 기온 |"))
        #expect(body.contains("- 홈 - 기상청 날씨누리 — https://www.weather.go.kr/"))
        #expect(body.hasSuffix("\n\(footer)"))
        // 메모 목록에 서는 제목은 「# 」가 걷힌 물음이다.
        #expect(Memo(body: body).title == "서울 내일 날씨")
    }

    @Test("모델이 제목·출처를 제 손으로 붙여도 앱의 것만 남는다 — 지어낸 주소는 근거가 아니다")
    func repairsModelHeadingsAndLinks() {
        let hits = [weather].map(Evidence.init(hit:))
        let written = """
        ```markdown
        # 서울 날씨 정리
        내일 서울은 흐립니다.

        ## 핵심
        - 낮 최고 24도 (https://wrong.example/made-up)
        - [기상청](https://also-made-up.example) 이 그렇게 말합니다

        ## 출처
        - 기상청 https://also-made-up.example
        ```
        """
        let body = Digest.assemble(question: "서울 내일 날씨", answer: answered(hits), written: written, results: hits, footer: footer)
        #expect(Digest.problems(in: body).isEmpty)
        #expect(!body.contains("wrong.example"))
        #expect(!body.contains("also-made-up.example"))
        #expect(!body.contains("# 서울 날씨 정리"))
        #expect(body.contains("- 낮 최고 24도"))
        // 마크다운 링크는 이름만 남는다 — 주소만 지우면 대괄호가 덩그러니 남는다.
        #expect(body.contains("- 기상청 이 그렇게 말합니다"))
        #expect(body.contains("https://www.weather.go.kr/"))
        // 「## 출처」는 하나뿐이다.
        #expect(body.components(separatedBy: "## 출처").count == 2)
    }

    @Test("모델이 「핵심」을 빠뜨리면 앱이 세운다 — 자리가 비면 다시 결과 더미다")
    func fillsMissingCoreSection() {
        let hits = [weather, meteo].map(Evidence.init(hit:))
        let body = Digest.assemble(question: "서울 내일 날씨", answer: answered(hits),
                                   written: "내일 서울은 흐리고 낮 최고 24도입니다. 오후부터 비가 내리겠습니다.",
                                   results: hits, footer: footer)
        #expect(Digest.problems(in: body).isEmpty)
        #expect(body.contains("## 핵심"))
        #expect(body.contains("- 내일 서울 흐리고 낮 최고 24도, 오후부터 비"))
    }

    @Test("모델이 넘어져도 메모는 나온다 — 앱만으로 같은 자리를 채운다")
    func composesWithoutModel() {
        let hits = [weather, meteo].map(Evidence.init(hit:))
        let body = Digest.compose(question: "웹에서 서울 내일 날씨", answer: answered(hits), results: hits, footer: footer)
        #expect(Digest.problems(in: body).isEmpty)
        #expect(body.hasPrefix("# 서울 내일 날씨"))
        #expect(body.contains("내일 서울은 흐리고 낮 최고 24도입니다"))
        #expect(body.contains("- 해돋이 06:11, 일몰 18:45, 강수 확률 60%"))
        #expect(body.hasSuffix(footer))
    }

    @Test("모델의 글이 쓸 게 없으면 앱의 판으로 — 빈 답도 메모는 정돈돼 있다")
    func fallsBackWhenModelSaysNothing() {
        let hits = [weather].map(Evidence.init(hit:))
        #expect(Digest.repair("네!") == nil)
        #expect(Digest.repair("") == nil)
        let body = Digest.assemble(question: "서울 내일 날씨", answer: answered(hits), written: "  ", results: hits, footer: footer)
        #expect(Digest.problems(in: body).isEmpty)
    }

    @Test("모델 없이 결과만 서 있을 때 — 제목은 물음이고 출처가 전부 실린다")
    func plainAnswerDigest() {
        let hits = [weather, meteo].map(Evidence.init(hit:))
        let plain = OutputValidator.plainWebAnswer(hits)
        let body = Digest.compose(question: "서울 내일 날씨 검색해줘", answer: plain, results: hits, footer: footer)
        #expect(Digest.problems(in: body).isEmpty)
        #expect(body.hasPrefix("# 서울 내일 날씨"))
        // 앱이 대신 세운 머리글은 답 문장이 아니다.
        #expect(!body.contains("검색 결과에서 이 부분을"))
        #expect(body.contains(weather.url.absoluteString) && body.contains(meteo.url.absoluteString))
    }

    @Test("자리가 비면 무엇이 빈지 말한다 — 시험과 수리가 같은 잣대를 본다")
    func problemsAreNamed() {
        #expect(Digest.problems(in: "그냥 글").count >= 2)
        #expect(Digest.problems(in: "# 제목\n\n## 핵심\n\n## 출처\n- 이름 — https://a.example")
            .contains { $0.contains("아래에 줄이 없다") })
        #expect(Digest.problems(in: "# 제목\n\n## 핵심\n- 하나\n\n## 출처\n- 이름만") == ["출처에 주소가 없다"])
    }

    @Test("모델에게 줄 초안에는 주소가 없고 페이지 본문이 들어간다")
    func draftCarriesPageText() {
        var hits = [weather, meteo].map(Evidence.init(hit:))
        hits[0].passage = "내일(9월 19일) 서울은 대체로 흐리겠고 오후 3시부터 비가 내리겠습니다."
        let draft = Digest.draft(question: "웹에서 서울 내일 날씨 검색해줘", answer: answered(hits), results: hits)
        #expect(!draft.contains("https://"))
        #expect(draft.contains("물음: 서울 내일 날씨"))
        #expect(draft.contains("오후 3시부터 비가 내리겠습니다"))
        // 본문을 못 읽은 쪽은 발췌가 근거로 남는다.
        #expect(draft.contains(meteo.snippet))
    }

    @Test("「메모로 남기기」도 자리가 같다 — 제목·답·출처·꼬리")
    func keepBodyIsStructured() {
        let hits = [weather, meteo].map(Evidence.init(hit:))
        let answer = AssistantAnswer(found: true, text: "내일 서울은 비가 온대요", evidence: [hits[1].memoID],
                                     quotes: [meteo.snippet],
                                     sources: [WebSource(id: hits[1].memoID, title: meteo.title, url: meteo.url)])
        let body = WebFollowUp.body(question: "웹에서 서울 내일 날씨", answer: answer, results: hits, footer: footer)
        #expect(body.hasPrefix("# 서울 내일 날씨\n"))
        #expect(body.contains("내일 서울은 비가 온대요"))
        #expect(body.contains("## 출처"))
        // 인용한 것만 — 기상청은 화면에 있었을 뿐이다.
        #expect(body.contains(meteo.url.absoluteString))
        #expect(!body.contains(weather.url.absoluteString))
        #expect(body.hasSuffix("\n\(footer)"))
    }
}
