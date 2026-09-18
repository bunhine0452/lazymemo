import Foundation

/// 웹 검색 결과 한 줄 — 제목·주소·발췌. 페이지 본문은 받지 않는다 (4096 토큰 안에 다섯 줄이면 넉넉하다).
public struct WebHit: Sendable, Equatable {
    public let title: String
    public let url: URL
    public let snippet: String
    public init(title: String, url: URL, snippet: String) { self.title = title; self.url = url; self.snippet = snippet }
}

/// 웹을 찾는 창구. **검색은 앱이 하고 모델은 결과를 읽는다** — 모델에게 검색어를 짓게 하지 않는다 (`Prompts` 원칙).
public protocol WebSearcher: Sendable {
    func search(_ query: String, limit: Int) async throws -> [WebHit]
}

/// DuckDuckGo 의 **HTML 판** — 키 없이 답한다 (2026-09-17 실측: 한국어 질문에 제목·주소·발췌 열 줄).
///
/// `html.duckduckgo.com/html/` 은 자바스크립트 없는 브라우저를 위한 페이지다. 문서화된 API 가 아니다 —
/// 모양이 바뀌거나 브라우저 아닌 요청을 막으면(`lite.` 판은 이미 202 로 막는다) 그날로 끊기고, 그때는
/// 「웹에 닿지 못했습니다」다. 키가 필요한 검색은 두지 않는다 (2026-09-17, 사용자: 「api 키를 넣으면 안 돼」) —
/// `NaverWebRouter` 와 같은 결정.
public struct DuckDuckGoSearcher: WebSearcher {
    static let endpoint = "https://html.duckduckgo.com/html/"
    static let timeout: TimeInterval = 15
    static let agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// DDG 의 지역 코드 — 한국어면 `kr-kr`, 아니면 전 세계.
    let region: String

    public init(locale: Locale = .current) {
        region = locale.language.languageCode?.identifier == "ko" ? "kr-kr" : "wt-wt"
    }

    public func search(_ query: String, limit: Int) async throws -> [WebHit] {
        var parts = URLComponents(string: Self.endpoint)
        parts?.queryItems = [.init(name: "q", value: query), .init(name: "kl", value: region)]
        guard let url = parts?.url else { throw AssistantFailure.webUnavailable }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(Self.agent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue(region == "kr-kr" ? "ko-KR,ko;q=0.9" : "en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await Self.session.data(for: request) }
        catch { throw AssistantFailure.webUnavailable }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AssistantFailure.webUnavailable }
        let html = String(decoding: data, as: UTF8.self)
        let hits = DuckDuckGoHTML.parse(html)
        // 200 인데 결과가 없다 — 정말 없는 것과 봇 확인 페이지를 가른다.
        if hits.isEmpty, !DuckDuckGoHTML.saysNoResults(html) { throw AssistantFailure.webUnavailable }
        return Array(hits.prefix(limit))
    }

    /// 쿠키·캐시를 남기지 않는다 — 검색어가 기기에 쌓이지 않게.
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
}

/// `html.duckduckgo.com` 의 결과 마크업 — `result__a`(제목·주소)와 `result__snippet`(발췌) 두 조각만 읽는다.
enum DuckDuckGoHTML {
    static func parse(_ html: String) -> [WebHit] {
        var hits: [WebHit] = []
        var seen: Set<String> = []
        for block in html.components(separatedBy: "class=\"result results_links").dropFirst() {
            // 광고 블록은 여는 태그에 `result--ad` — 답의 근거로 삼지 않는다.
            if block.prefix(while: { $0 != ">" }).contains("result--ad") { continue }
            guard let anchor = first(#"<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#, in: block, groups: 2),
                  let url = resolve(anchor[0]) else { continue }
            let title = clean(anchor[1])
            let snippet = first(#"<a[^>]*class="result__snippet"[^>]*>(.*?)</a>"#, in: block, groups: 1).map { clean($0[0]) } ?? ""
            guard !title.isEmpty, seen.insert(url.absoluteString).inserted else { continue }
            hits.append(WebHit(title: title, url: url, snippet: snippet))
        }
        return hits
    }

    static func saysNoResults(_ html: String) -> Bool {
        html.contains("class=\"no-results\"") || html.contains("No results.")
    }

    /// DDG 가 주소를 `//duckduckgo.com/l/?uddg=…` 로 감싸 줄 때가 있다 — 안의 주소를 꺼낸다.
    static func resolve(_ raw: String) -> URL? {
        let text = decode(raw)
        if let parts = URLComponents(string: text.hasPrefix("//") ? "https:" + text : text),
           parts.host?.hasSuffix("duckduckgo.com") == true,
           let inner = parts.queryItems?.first(where: { $0.name == "uddg" })?.value {
            return URL(string: inner)
        }
        guard let url = URL(string: text), let scheme = url.scheme, scheme == "https" || scheme == "http" else { return nil }
        return url
    }

    static func first(_ pattern: String, in text: String, groups: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1...groups).compactMap { Range(m.range(at: $0), in: text).map { String(text[$0]) } }
    }

    /// 태그를 걷고 `&amp;` 따위를 풀고 공백을 한 칸으로.
    static func clean(_ fragment: String) -> String {
        let untagged = fragment.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return decode(untagged).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// 이름 있는 참조. **`&amp;` 는 여기 없다** — 그것만은 맨 나중에 푼다(아래).
    static let entities: [String: String] = [
        "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&nbsp;": " ",
        "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&middot;": "·",
        "&laquo;": "«", "&raquo;": "»", "&lsquo;": "‘", "&rsquo;": "’", "&ldquo;": "“", "&rdquo;": "”",
        "&deg;": "°", "&sup2;": "²", "&sup3;": "³", "&times;": "×", "&divide;": "÷",
        "&trade;": "™", "&copy;": "©", "&reg;": "®", "&euro;": "€", "&pound;": "£", "&yen;": "¥", "&bull;": "•",
    ]

    static func decode(_ text: String) -> String {
        var out = text
        for (entity, char) in entities { out = out.replacingOccurrences(of: entity, with: char) }
        // `&#12345;` 숫자 참조.
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9A-Fa-f]+);") {
            for m in regex.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed() {
                guard let whole = Range(m.range, in: out), let inner = Range(m.range(at: 1), in: out) else { continue }
                let code = String(out[inner])
                let value = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let value, let scalar = Unicode.Scalar(value) { out.replaceSubrange(whole, with: String(Character(scalar))) }
            }
        }
        // `&amp;` 는 **맨 나중**이다. 먼저 풀면 `&amp;lt;` 가 `&lt;` 를 거쳐 `<` 가 된다 — 글에 적힌
        // 「&lt;」를 태그로 둔갑시키는 길이라 순서가 곧 규칙이다.
        return out.replacingOccurrences(of: "&amp;", with: "&")
    }
}

/// 사람의 말을 검색어로 — 「웹에서 서울 내일 날씨 검색해줘」→「서울 내일 날씨」. 물음말·조사는 검색 엔진이 알아서 읽으니 두고,
/// 검색하라는 말과 물음표만 뗀다.
public enum WebQuery {
    /// 웹을 찾으라는 말 — 이것이 있으면 메모를 거치지 않고 바로 웹이다 (`AssistantIntent.classify`).
    /// 「인터넷」·「찾아봐」 홀로는 안 된다 — 「인터넷 요금 언제 냈지?」는 메모 질문이다. 애매하면 메모 먼저, 못 찾으면 웹을 권한다.
    public static let words = ["웹에서", "웹으로", "인터넷에서", "인터넷으로", "검색해", "검색 해", "검색좀", "검색 좀", "구글", "search the web", "google"]
    /// 검색어에서 떼는 말 — 「구글」·「인터넷」 홀로는 남긴다(「구글 캘린더 공유 방법」).
    ///
    /// **떼는 것은 시키는 말뿐이다.** 이름·숫자·날짜는 한 글자도 건드리지 않는다 — 「2026년 최저임금」에서
    /// 「2026년」이 빠지면 검색 엔진은 올해를 답하고, 그 답은 틀린 답이다.
    static let tails = ["검색해줘", "검색해 줘", "검색해봐", "검색해 봐", "검색해", "검색 해줘", "검색 해 줘", "검색좀", "검색 좀",
                        "찾아봐줘", "찾아봐", "찾아 봐", "찾아줘", "찾아 줘", "알려줘", "알려 줘", "알려주세요", "알려주라",
                        "가르쳐줘", "가르쳐 줘", "말해줘", "말해 줘", "설명해줘", "설명해 줘", "정리해줘", "요약해줘",
                        "궁금한데", "궁금해요", "궁금해", "궁금합니다", "부탁해요", "부탁해", "구글링", "구글에서",
                        "웹에서", "웹으로", "인터넷에서", "인터넷으로",
                        "on the web", "search the web for", "search for", "look up", "tell me", "please"]
    /// 뜻을 담지 않은 채 사이에 끼는 말. 뗀 자리에 한 칸이 남으므로 낱말끼리 붙지 않는다.
    static let noise = [" 좀 ", " 좀", "제발", "빨리", " 그냥 "]

    public static func mentionsWeb(_ text: String) -> Bool {
        let lower = text.lowercased()
        return words.contains { lower.contains($0) }
    }

    public static func make(from text: String) -> String {
        var out = text
        for tail in tails { out = out.replacingOccurrences(of: tail, with: " ", options: .caseInsensitive) }
        for word in noise { out = out.replacingOccurrences(of: word, with: " ", options: .caseInsensitive) }
        out = out.replacingOccurrences(of: "[?？!！]", with: " ", options: .regularExpression)
        let cleaned = out.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,·\"'「」“”"))
        return cleaned.isEmpty ? text : cleaned
    }

    /// 다시 던질 때 빼는 말 — 물음의 «모양»을 이루는 것들. 낱말이 아니라 문장의 부속이다.
    static let questionWords: Set<String> = [
        "얼마나", "얼마", "언제", "어디", "어디서", "어떻게", "어떤", "무엇", "뭐가", "뭐야", "뭐", "왜", "누가", "누구", "몇",
        "에서", "에는", "이거", "그거", "요즘", "현재", "지금",
        "what", "when", "where", "how", "why", "who", "which", "is", "are", "the", "of", "in", "to", "for",
    ]
    /// 풀이말의 끝 — 이것으로 끝나는 말은 검색어의 알맹이가 아니다 (「바뀌었는지」·「오르는지」).
    static let questionEndings = ["는지", "은지", "인지", "나요", "까요", "습니까", "인가요", "일까", "할까", "될까", "인가", "이야"]

    /// 첫 검색이 빈손일 때 한 번 더 던지는 **더 짧은** 검색어.
    ///
    /// 사람은 문장으로 묻고(「내년 최저임금이 얼마나 오르는지 알려줘」) 검색 엔진은 낱말로 찾는다.
    /// 물음말·풀이말을 떼고 알맹이만 남긴다 — 다만 **글자는 원문 그대로** 옮긴다: 「Swift 6.2」의
    /// 대소문자와 소수점까지 뭉개면 그것대로 못 찾는다. 줄일 것이 없으면 `make` 와 같은 글이고,
    /// 그러면 코디네이터는 같은 검색을 두 번 던지지 않는다.
    public static func simplify(from text: String) -> String {
        let base = make(from: text)
        let kept = base.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,·\"'()「」")) }
            .filter(keepsInQuery)
            .prefix(6)
        let simplified = kept.joined(separator: " ")
        return simplified.isEmpty ? base : simplified
    }

    static func keepsInQuery(_ word: String) -> Bool {
        let lowered = word.lowercased()
        guard lowered.count >= 2, QueryTerms.normalize(lowered) != nil, !questionWords.contains(lowered) else { return false }
        return !questionEndings.contains { lowered.hasSuffix($0) && lowered.count > $0.count + 1 }
    }
}
