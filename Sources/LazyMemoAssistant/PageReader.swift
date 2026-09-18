import Foundation

/// 검색 결과가 가리키는 페이지 하나에서 읽어 온 글.
public struct WebPage: Sendable, Equatable {
    public let url: URL
    /// 페이지가 스스로 말하는 제목. 없으면 nil — 그때는 검색 결과의 제목이 남는다.
    public let title: String?
    /// 읽을 만한 본문만 (메뉴·바닥글·스크립트를 걷어낸 것).
    public let text: String
    public init(url: URL, title: String?, text: String) { self.url = url; self.title = title; self.text = text }
}

/// 결과 페이지의 본문을 읽어 오는 창구. **읽기만 한다** — 쿠키도 캐시도 로그인도 없다.
///
/// 발췌(snippet) 한 줄은 자주 모자란다. 2026-09-17 실측에서 「대한민국 수도 인구」에 모델이
/// *총인구* 를 답한 것은 모델이 틀려서가 아니라 **발췌에 그것밖에 없었기 때문**이다. 근거를
/// 본문으로 넓히는 것이 답을 정확하게 만드는 가장 싼 길이다.
public protocol PageFetcher: Sendable {
    /// 못 읽으면 nil — 그때는 검색 발췌가 근거로 남는다 (`AssistantCoordinator`).
    func read(_ url: URL) async -> WebPage?
}

/// 근거 본문에 내주는 글자 수. 4096 토큰 안에 지시문·물음·발췌가 함께 들어가야 한다.
public enum PageBudget {
    /// 본문 전부가 나눠 갖는 몫. 셋이면 한 쪽에 800자 — 한국어 800자는 대략 700~900 토큰이고,
    /// 세 쪽 2400자에 지시문·발췌·물음을 더해도 4096 안에 자리가 남는다.
    public static let total = 2400
    /// 한 번에 본문까지 읽어 오는 페이지 수. 넷을 넘기면 한 쪽에 남는 글이 근거가 못 될 만큼 짧아진다.
    public static let maxPages = 3

    public static func perSource(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(400, total / count)
    }
}

/// 실제로 페이지를 받아 오는 판. 8초·1MB 안에서, 쿠키 없이.
public struct WebPageReader: PageFetcher {
    /// 한 쪽에 8초. 세 쪽을 나란히 받으니 검색 뒤 기다림은 8초를 넘지 않는다.
    public static let timeout: TimeInterval = 8
    /// 읽는 양의 상한. 이보다 긴 페이지는 앞의 1MB 만 읽는다 — 본문은 언제나 앞에 있다.
    public static let maxBytes = 1_024 * 1_024

    public init() {}

    public func read(_ url: URL) async -> WebPage? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(DuckDuckGoSearcher.agent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await Self.session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let type = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        guard Self.isTextual(type) else { return nil }
        let html = Self.decode(data.prefix(Self.maxBytes), contentType: type)
        return Readable.page(from: html, url: url)
    }

    /// 글로 읽을 수 있는 종류인가. PDF·이미지·JSON 은 아니다 — 그때는 검색 발췌가 근거로 남는다.
    /// 종류를 말하지 않는 서버도 있어서(빈 문자열) 그쪽은 읽어 보고 판단한다.
    static func isTextual(_ contentType: String) -> Bool {
        let type = contentType.lowercased()
        if type.contains("json") { return false }
        return type.isEmpty || type.contains("html") || type.contains("xml") || type.contains("text/plain")
    }

    /// 검색과 같은 이유로 쿠키·캐시를 남기지 않는다 — 어느 페이지를 열었는지가 기기에 쌓이지 않게.
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.timeoutIntervalForRequest = WebPageReader.timeout
        config.timeoutIntervalForResource = WebPageReader.timeout
        config.httpMaximumConnectionsPerHost = PageBudget.maxPages
        return URLSession(configuration: config)
    }()

    /// 한국 사이트에는 아직 EUC-KR 이 남아 있다 — 헤더나 `<meta charset>` 이 말하는 대로 읽는다.
    static func decode(_ data: some DataProtocol, contentType: String) -> String {
        let bytes = Data(data)
        if let name = charset(in: contentType) ?? charsetInHead(bytes),
           let encoding = encoding(named: name), encoding != .utf8,
           let text = String(data: bytes, encoding: encoding) {
            return text
        }
        return String(data: bytes, encoding: .utf8) ?? String(decoding: bytes, as: UTF8.self)
    }

    static func charset(in contentType: String) -> String? {
        guard let range = contentType.range(of: "charset=") else { return nil }
        let raw = contentType[range.upperBound...].prefix { !$0.isWhitespace && $0 != ";" }
        let name = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return name.isEmpty ? nil : name
    }

    /// `<head>` 의 앞 2KB 만 본다 — charset 선언은 규격상 거기 있어야 한다.
    static func charsetInHead(_ data: Data) -> String? {
        let head = String(decoding: data.prefix(2_048), as: UTF8.self)
        guard let regex = try? NSRegularExpression(pattern: #"charset\s*=\s*["']?([A-Za-z0-9_\-]+)"#, options: [.caseInsensitive]),
              let m = regex.firstMatch(in: head, range: NSRange(head.startIndex..., in: head)),
              let r = Range(m.range(at: 1), in: head) else { return nil }
        return String(head[r])
    }

    /// IANA 이름(`euc-kr`·`ks_c_5601-1987`·`windows-949`…)을 그대로 넘긴다 — 표를 우리가 들지 않는다.
    static func encoding(named name: String) -> String.Encoding? {
        let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cf != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
    }
}

/// 페이지에서 **읽을 만한 글만** 남긴다 — 「Readability」의 아주 작은 판.
///
/// 규칙은 셋이다. ① 글이 아닌 것(스크립트·메뉴·바닥글)은 통째로 버린다. ② `<article>`·`<main>`
/// 이 있으면 그 안만 본다 — 한국 포털·블로그도 이 둘은 대개 제대로 단다. ③ 그래도 남는
/// 메뉴 부스러기는 **긴 문단이 처음 나온 자리부터 마지막까지**만 취해 걷어낸다.
public enum Readable {
    /// 글이 될 수 없는 것들. 메뉴가 잔뜩인 페이지에서 본문을 건지는 첫 걸음이다.
    static let dropped = ["script", "style", "noscript", "svg", "iframe", "form", "select", "button",
                          "template", "nav", "header", "footer", "aside"]
    /// **줄줄이 늘어선 링크는 차림표다.** 태그 이름이 `nav` 가 아니어도 그렇다 — 한국 사이트의 차림표는
    /// 대개 `<div id="gnb">` 안의 `<a>` 열이고, 그것을 남겨 두면 「홈 날씨 태풍 로그인 회원가입…」 한 줄이
    /// 40자를 넘어 **본문 행세**를 한다(`densest` 가 그 줄부터 본문으로 친다). 링크 글이 짧고 넷 넘게
    /// 이어지면 차림표로 본다 — 글 속의 링크는 이 모양이 되지 않는다.
    static let linkRun = "(?:<a\\b[^>]*>[^<]{0,40}</a>(?:\\s|<[^>]{0,60}>)*){4,}"
    /// 줄이 갈리는 자리 — 여기가 갈려야 문단과 메뉴가 서로 붙지 않는다.
    static let breaks = ["br", "p", "div", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6",
                         "section", "article", "blockquote", "td", "th", "dt", "dd", "pre", "figcaption"]

    public static func page(from html: String, url: URL) -> WebPage? {
        let text = extract(html)
        guard !text.isEmpty else { return nil }
        return WebPage(url: url, title: pageTitle(html), text: text)
    }

    public static func extract(_ html: String) -> String {
        var body = html.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: " ", options: .regularExpression)
        for tag in dropped { body = removeElements(named: tag, in: body) }
        body = body.replacingOccurrences(of: linkRun, with: "\n", options: [.regularExpression, .caseInsensitive])
        let scope = subtree(named: "article", in: body) ?? subtree(named: "main", in: body) ?? body
        return densest(textLines(of: scope)).joined(separator: "\n")
    }

    /// 페이지의 `<title>` — 「… | 네이버 블로그」처럼 뒤에 붙는 사이트 이름은 그대로 둔다(잘못 자르면 제목이 사라진다).
    public static func pageTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title\\s*>", options: [.caseInsensitive]),
              let m = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(m.range(at: 1), in: html) else { return nil }
        let title = DuckDuckGoHTML.clean(String(html[r]))
        return title.isEmpty ? nil : title
    }

    /// 여는 태그부터 짝이 되는 닫는 태그까지 통째로. 같은 이름이 겹치면 안쪽에서 끊기지만,
    /// 그때 새어 나온 부스러기는 `densest` 가 다시 걸러 낸다.
    static func removeElements(named tag: String, in html: String) -> String {
        html.replacingOccurrences(of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>", with: "\n",
                                  options: [.regularExpression, .caseInsensitive])
    }

    /// 그 태그 중 **글이 가장 많은** 하나. 「관련 기사」 카드도 `<article>` 이라 개수로 고르면 안 된다.
    static func subtree(named tag: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<\(tag)\\b[^>]*>([\\s\\S]*?)</\(tag)\\s*>", options: [.caseInsensitive]) else { return nil }
        let best = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            .compactMap { Range($0.range(at: 1), in: html).map { String(html[$0]) } }
            .max { plainLength($0) < plainLength($1) }
        // 너무 짧으면 그건 본문이 아니라 카드다 — 페이지 전체를 보는 편이 낫다.
        guard let best, plainLength(best) >= 200 else { return nil }
        return best
    }

    static func plainLength(_ html: String) -> Int {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).reduce(0) { $0 + $1.count }
    }

    static func textLines(of html: String) -> [String] {
        var text = html
        for tag in breaks {
            text = text.replacingOccurrences(of: "</?\(tag)\\b[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        }
        // 남은 태그는 한 칸으로 — 「<b>내일</b>비」가 「내일비」로 붙지 않게.
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return DuckDuckGoHTML.decode(text)
            .split(separator: "\n")
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
    }

    /// 글이 있는 자리만 — **긴 문단이 처음 나온 줄부터 마지막 줄까지.** 차림표·바닥글은 그 밖에 산다.
    ///
    /// 다만 **마지막 문단 뒤**는 한 걸음 더 간다. 표·목록은 문장이 아니라 짧은 줄의 연속이고,
    /// 가격·사양·시각표는 하필 글의 맨 끝에 붙는다 — 거기서 자르면 「어떤 데이터든 잘 정리」의
    /// 그 데이터가 통째로 없어진다. 바닥글(저작권·이용약관)을 만나면 멈춘다.
    static func densest(_ lines: [String]) -> [String] {
        let long = lines.indices.filter { lines[$0].count >= 40 }
        guard let first = long.first, var last = long.last else { return lines.filter(keeps) }
        var index = last + 1
        while index < lines.count, keeps(lines[index]), !isBoilerplate(lines[index]) {
            last = index
            index += 1
        }
        return lines[first...last].filter(keeps)
    }

    /// 어느 페이지에나 있는, 그 페이지의 내용이 아닌 말. 본문 안에서는 지우지 않는다 —
    /// **끝을 어디로 잡을지**에만 쓴다 (개인정보처리방침을 설명하는 글을 도려내지 않으려고).
    static let boilerplate = ["개인정보", "저작권", "ⓒ", "©", "이용약관", "로그인", "회원가입", "무단수집", "무단전재",
                              "copyright", "all rights reserved", "사이트맵", "고객센터", "구독하기", "공유하기"]

    static func isBoilerplate(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return boilerplate.contains { lowered.contains($0) }
    }

    /// 낱말 하나짜리 차림표는 글이 아니다. 다만 **숫자가 든 줄은 남긴다** — 「점심 12,000원」·「3월 5일」.
    static func keeps(_ line: String) -> Bool {
        if line.count >= 20 { return true }
        if line.contains(where: \.isNumber) { return true }
        guard line.count >= 6, let last = line.last else { return false }
        return ".?!다요음임".contains(last)
    }

    /// 상한까지 자르되 문장 가운데서 끊지 않는다 — 반 토막 난 문장은 근거가 못 된다.
    public static func clip(_ text: String, to limit: Int) -> String {
        guard limit > 0 else { return "" }
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let cut = head.lastIndex(where: { $0 == "\n" || ".?!다요".contains($0) }),
           head.distance(from: head.startIndex, to: cut) > limit / 2 {
            return String(head[...cut]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return head.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
