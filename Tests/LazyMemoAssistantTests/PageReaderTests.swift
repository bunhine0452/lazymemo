import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 언제나 같은 본문을 주는 페이지 읽기 — 또는 아무것도 못 읽는 것.
struct StubFetcher: PageFetcher {
    var pages: [String: String] = [:]
    /// 읽으려고 든 주소 — 몇 쪽을 나란히 읽었는지 센다.
    let seen = Recorder()

    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []
        func add(_ url: URL) { lock.withLock { urls.append(url) } }
        var all: [URL] { lock.withLock { urls } }
    }

    func read(_ url: URL) async -> WebPage? {
        seen.add(url)
        guard let text = pages[url.absoluteString] else { return nil }
        return WebPage(url: url, title: nil, text: text)
    }
}

@Suite("페이지 본문 읽기")
struct PageReaderTests {
    static func fixture(_ name: String) -> String {
        let url = AssistantFixtures.directory.appending(path: name)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    @Test("한국어 블로그 — <article> 안의 글만, 차림표·바닥글·스크립트는 없다")
    func readsKoreanArticle() {
        let html = Self.fixture("page-ko-blog.html")
        let text = Readable.extract(html)
        // 본문의 숫자는 한 글자도 잃지 않는다 — 답의 정확도가 여기서 온다.
        #expect(text.contains("10,320원"))
        #expect(text.contains("2,156,880원"))
        #expect(text.contains("3개월 이내"))
        // 표도 글이다 — 줄로 풀려 남는다.
        #expect(text.contains("9,860원") && text.contains("2.9%"))
        // 글이 아닌 것은 없다.
        #expect(!text.contains("로그인"))
        #expect(!text.contains("이용약관"))
        #expect(!text.contains("개인정보처리방침"))
        #expect(!text.contains("연말정산"))
        #expect(!text.contains("최저임금 추적"))
        #expect(!text.contains("나눔고딕"))
        #expect(Readable.pageTitle(html) == "2026년 최저임금 총정리 : 네이버 블로그")
    }

    @Test("영어 위키 — <main> 안만, 엔티티는 풀리고 목록의 숫자는 남는다")
    func readsEnglishMain() {
        let html = Self.fixture("page-en-wiki.html")
        let text = Readable.extract(html)
        #expect(text.contains("9,384,000"))
        #expect(text.contains("Han River"))
        #expect(text.contains("605.2 km²"))
        // `&mdash;`·`&amp;` 가 글자로 풀린다.
        #expect(text.contains("—") && text.contains("half of the national population & one"))
        #expect(!text.contains("Random article"))
        #expect(!text.contains("Creative Commons"))
        #expect(!text.contains("View history"))
        #expect(Readable.pageTitle(html) == "Seoul - Wikipedia")
    }

    @Test("차림표뿐인 페이지 — <nav> 가 아니어도 줄줄이 선 링크는 걷는다")
    func stripsNavHeavyPage() {
        let text = Readable.extract(Self.fixture("page-nav-heavy.html"))
        #expect(text.contains("아침 최저기온은 18도"))
        #expect(text.contains("오후 3시부터"))
        #expect(!text.contains("회원가입"))
        #expect(!text.contains("사이트맵"))
        #expect(!text.contains("이메일무단수집거부"))
        // 첫 줄이 「홈 날씨 테마날씨 …」면 차림표를 본문으로 읽은 것이다.
        #expect(text.split(separator: "\n").first?.contains("테마날씨") != true)
    }

    @Test("글로 읽을 수 없는 것은 읽지 않는다 — PDF·이미지·JSON")
    func skipsNonHTML() {
        #expect(WebPageReader.isTextual("text/html; charset=utf-8"))
        #expect(WebPageReader.isTextual("application/xhtml+xml"))
        #expect(WebPageReader.isTextual(""))
        #expect(!WebPageReader.isTextual("application/pdf"))
        #expect(!WebPageReader.isTextual("image/png"))
        #expect(!WebPageReader.isTextual("application/json"))
        // 글이 한 줄도 안 남으면 페이지가 아니다.
        #expect(Readable.page(from: "<html><body><script>var a=1;</script></body></html>",
                              url: URL(string: "https://example.org")!) == nil)
    }

    @Test("EUC-KR 페이지도 읽는다 — 헤더가 말하는 대로")
    func decodesEUCKR() throws {
        let cf = CFStringConvertIANACharSetNameToEncoding("euc-kr" as CFString)
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
        let html = "<html><body><p>서울 내일 날씨는 흐림</p></body></html>"
        let data = try #require(html.data(using: encoding))
        #expect(WebPageReader.decode(data, contentType: "text/html; charset=EUC-KR").contains("서울 내일 날씨는 흐림"))
        // charset 이 헤더에 없으면 `<meta>` 를 본다.
        let withMeta = try #require(("<meta charset=\"euc-kr\">" + html).data(using: encoding))
        #expect(WebPageReader.decode(withMeta, contentType: "text/html").contains("흐림"))
    }

    @Test("몫만큼 자르되 문장 가운데서 끊지 않는다")
    func clipsAtSentence() {
        let text = "첫 문장입니다. 둘째 문장입니다. 셋째 문장은 잘려야 합니다."
        let clipped = Readable.clip(text, to: 22)
        #expect(clipped.hasSuffix("…"))
        #expect(clipped.hasPrefix("첫 문장입니다. 둘째 문장입니다."))
        #expect(Readable.clip("짧다", to: 100) == "짧다")
        // 셋이면 한 쪽에 800자 — 4096 토큰 안에 지시문·물음이 들어갈 자리가 남는다.
        #expect(PageBudget.perSource(3) == 800)
        #expect(PageBudget.perSource(1) == 2400)
    }
}
