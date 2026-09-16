import Foundation

/// 사용자가 적은 글에서 **장소**를 알아낸다.
///
/// 날짜와 달리 장소는 **자리를 바꾸지 않는다.** 날짜가 붙으면 종이가 물러나고
/// 달력이 맡지만 (§7.2), 장소가 붙어도 종이는 그대로 있다 — 장소는 종이에 찍힌
/// 잉크 자국 하나이고, 구조는 여전히 시간 하나다 (§14.2). 그래서 이 파서가 채우는
/// 것은 자리가 아니라 필드 하나뿐이다.
///
/// **읽는 규칙은 셋뿐이고, 셋 다 애매함이 없다.**
///
/// 1. 산문 안에서는 `@강남역` 만 읽는다 (`parse`). `@` 는 캘린더·슬랙·인스타에서
///    이미 장소에 쓰는 기호라 배울 것이 없고, 무엇보다 **사람이 직접 찍은 표시**라
///    우리가 짐작한 것이 아니다.
/// 2. 주소는 **문자열이 통째로 주소일 때만** 읽는다 (`address`) — 클립보드나
///    단축어에서 온 것.
/// 3. 지도 앱의 「공유」가 내놓는 **이름 · 주소 · 링크** 서너 줄을 읽는다 (`share`).
///    폰에서 장소를 던지면 이 모양으로 온다. 첫 줄이 이름이고, 주소 줄이 2번의
///    규칙을 통과하거나 링크가 지도 서비스의 것일 때만 믿는다.
///
/// 2번을 산문으로 넓히지 않는 것이 이 파일에서 가장 중요한 결정이다. 한국어에서
/// `…로`·`…구` 로 끝나는 낱말은 주소가 아닌 쪽이 훨씬 많아서 (`집으로 3분`,
/// `인구 조사로 3일`), 산문에서 주소를 짐작하면 오탐이 난다. **틀린 장소를 붙이는
/// 것은 장소를 안 붙이는 것보다 나쁘다** — 사용자가 치워야 할 것을 하나 더 만드는
/// 셈이기 때문이다. 애매한 것은 앱이 아니라 Claude 가 맡는다 (D3).
///
/// 우편번호 5자리도 후보였으나 뺐다. 맨 다섯 자리 숫자는 값·개수·전화번호 조각과
/// 구별되지 않아, 같은 이유로 오탐이 난다.
public enum PlaceParser {
    public struct Result: Sendable, Equatable {
        public var place: String
        /// 인식한 원문 조각. 본문에서 덜어내는 데 쓴다 (`NaturalDateParser.strip`).
        public var phrases: [String]

        public init(place: String, phrases: [String]) {
            self.place = place
            self.phrases = phrases
        }
    }

    /// 산문 안의 `@낱말`. 없으면 `nil` — 짐작하지 않는다.
    public static func parse(_ text: String) -> Result? {
        parseAll(text).first
    }

    /// 산문 안의 `@낱말` **전부**, 적힌 차례대로. 「@강남역에서 만나 @홍대입구로」처럼
    /// 한 메모에 자리가 여럿일 때 — 첫째는 파일의 `place:` 가 되고 나머지는
    /// 본문에 그대로 남아 카드로 선다 (`MemoPlaces`). 같은 낱말은 한 번만.
    public static func parseAll(_ text: String) -> [Result] {
        var found: [Result] = []
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            guard characters[index] == "@" else {
                index += 1
                continue
            }
            // `foo@bar.com` 은 장소가 아니다. @ 앞이 글의 처음이거나 공백일 때만
            // 사람이 장소 표시로 찍은 것이다 — 이 한 줄이 메일 주소를 전부 걸러낸다.
            guard index == 0 || characters[index - 1].isWhitespace else {
                index += 1
                continue
            }

            var end = index + 1
            while end < characters.count, !characters[end].isWhitespace { end += 1 }

            let word = String(characters[(index + 1)..<end])
            let name = trimmingTrailingPunctuation(word)
            guard name.contains(where: { $0.isLetter || $0.isNumber }) else {
                index += 1
                continue
            }
            // 덜어낼 조각은 문장부호까지 포함한 원문 그대로여야 본문이 깨끗해진다.
            if !found.contains(where: { $0.place == name }) {
                found.append(Result(place: name, phrases: ["@" + word]))
            }
            index = end
        }
        return found
    }

    /// 문자열이 **통째로** 주소일 때만 그 주소를 돌려준다.
    ///
    /// 돌려주는 것은 뽑아낸 조각이 아니라 **줄 전체**다. 건물 이름이나 층수가
    /// 뒤에 붙어 있으면 그것까지 지도에 넘기는 편이 더 정확하기 때문이다.
    public static func address(_ text: String) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.contains("\n"), line.count <= lengthLimit else { return nil }

        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard hasAddressShape(tokens) else { return nil }
        return line
    }

    /// 이보다 길면 주소가 아니라 글이다.
    private static let lengthLimit = 60

    /// 지도 앱의 「공유」가 내놓은 글에서 읽은 것.
    public struct Share: Sendable, Equatable {
        /// 첫 줄 — 장소 이름.
        public var place: String
        /// `[네이버 지도]` 같은 서비스 이름표를 뗀 본문. 이름·주소·링크는 그대로 둔다 —
        /// 이름은 곧 메모의 제목이고, 링크가 있어야 카드가 붙는다.
        public var body: String

        public init(place: String, body: String) {
            self.place = place
            self.body = body
        }
    }

    /// `[이름표]` · 이름 · 주소 · 링크 — 이 차례의 두~네 줄일 때만 읽는다.
    ///
    /// 네이버는 `[네이버 지도]` 를 한 줄로, 카카오는 `[카카오맵] 이름` 으로 붙인다.
    /// 구글은 이름 · 링크 두 줄이고 주소가 없다 — 그때는 링크가 지도의 것이어야
    /// 장소다. `이름\nhttps://youtube.com/…` 은 장소가 아니라 링크 메모다.
    public static func share(_ text: String) -> Share? {
        var lines = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard (2...4).contains(lines.count) else { return nil }

        var stamped = false
        if let stripped = strippingServiceStamp(lines[0]) {
            stamped = true
            if stripped.isEmpty { lines.removeFirst() } else { lines[0] = stripped }
        }

        // 링크는 끝에 온다. 공유 시트가 글과 주소를 따로 건네면 같은 링크가 두 줄이다.
        var links: [String] = []
        while let last = lines.last, isLink(last) {
            links.insert(last, at: 0)
            lines.removeLast()
        }
        guard (1...2).contains(lines.count), !isLink(lines[0]) else { return nil }

        // 이름은 글자로 시작한다 — `[ ] 우유`·`- 우유`·`# 제목` 은 이름이 아니라 마크다운이다.
        let name = lines[0]
        guard name.count <= InboundNote.placeLimit,
              let first = name.first, first.isLetter || first.isNumber
        else { return nil }

        if lines.count == 2 {
            guard address(lines[1]) != nil else { return nil }
        } else {
            guard let link = links.first, MapLink.isMap(link) else { return nil }
        }

        return Share(place: name, body: stamped ? (lines + links).joined(separator: "\n") : text)
    }

    /// 공유 글이 **더 긴 글 속에** 있을 때 — 「22일 3시에 여기서」를 앞뒤에 덧붙였거나, 링크 줄 뒤에 말을 이었거나,
    /// 줄바꿈이 사라져 한 줄로 붙었거나(`[네이버지도]이름주소https://naver.me/…`). 2026-09-16 에 사용자가 네이버
    /// 지도에서 바로 복사한 것을 앱이 못 알아들었다.
    public struct ShareBlock: Sendable, Equatable {
        public var place: String
        /// 이름표를 뗀 본문 전체.
        public var body: String
        /// 공유 덩어리 밖의 말 — 날짜·시각은 여기서 읽는다.
        public var rest: String

        public init(place: String, body: String, rest: String) {
            self.place = place
            self.body = body
            self.rest = rest
        }
    }

    public static func shareBlock(in text: String) -> ShareBlock? {
        if let pure = share(text) { return ShareBlock(place: pure.place, body: pure.body, rest: "") }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let live = lines.enumerated().filter { !$0.element.isEmpty }.map { (offset: $0.offset, line: $0.element) }

        // 지도 링크가 든 줄. 링크 앞에 글이 붙어 있으면 줄바꿈이 사라진 것이고, 뒤에 붙어 있으면 이어 적은 말이다.
        guard let at = live.firstIndex(where: { mapLink(in: $0.line) != nil }),
              let found = mapLink(in: live[at].line) else { return nil }
        let linkLine = live[at]

        var name: String?
        var blockStart = linkLine.offset
        if !found.head.isEmpty {
            let head = strippingServiceStamp(found.head) ?? found.head
            if let split = splitGluedNameAndAddress(head) { name = split.name }
            else if isName(head) { name = head }
            else { return nil }
        } else {
            var candidates = Array(live[max(0, at - 3)..<at])
            var stampOffset: Int?
            if let first = candidates.first, let stripped = strippingServiceStamp(first.line) {
                stampOffset = first.offset
                if stripped.isEmpty { candidates.removeFirst() } else { candidates[0] = (first.offset, stripped) }
            }
            // 링크 바로 위가 주소면 그 위가 이름, 아니면 링크 바로 위가 이름.
            if candidates.count >= 2, address(candidates[candidates.count - 1].line) != nil, isName(candidates[candidates.count - 2].line) {
                name = candidates[candidates.count - 2].line
                blockStart = candidates[candidates.count - 2].offset
            } else if let last = candidates.last, isName(last.line) {
                name = last.line
                blockStart = last.offset
            } else if let last = candidates.last, let split = splitGluedNameAndAddress(last.line) {
                name = split.name
                blockStart = last.offset
            } else {
                return nil
            }
            // 이름표는 이름 바로 위에 있을 때만 덩어리의 것이다.
            if let stampOffset, let nameAt = live.firstIndex(where: { $0.offset == blockStart }), nameAt > 0,
               live[nameAt - 1].offset == stampOffset {
                blockStart = stampOffset
            }
        }
        guard let name, NaturalDateParser.parse(name, now: Date()) == nil else { return nil }

        var rest: [String] = live.filter { $0.offset < blockStart || $0.offset > linkLine.offset }.map(\.line)
        if !found.tail.isEmpty { rest.append(found.tail) }

        let body = lines.map { strippingServiceStamp($0) ?? $0 }.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ShareBlock(place: name, body: body, rest: rest.joined(separator: "\n"))
    }

    /// 줄 속의 지도 링크와 그 앞뒤의 말. 지도 링크가 없으면 nil.
    static func mapLink(in line: String) -> (head: String, link: String, tail: String)? {
        guard let match = line.firstMatch(of: /(https?:\/\/[^\s<>()\[\]]+)/), MapLink.isMap(String(match.1)) else { return nil }
        let head = String(line[..<match.range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let tail = String(line[match.range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (head, String(match.1), tail)
    }

    /// 이름이라 부를 만한 줄 — 링크가 아니고, 글자로 시작하며, 짧다.
    static func isName(_ line: String) -> Bool {
        guard !isLink(line), line.count <= InboundNote.placeLimit, let first = line.first else { return false }
        return first.isLetter || first.isNumber
    }

    /// 「센트럴시티터미널(호남선)서울 서초구 신반포로 176 센트럴시티」— 줄바꿈이 사라져 이름과 주소가 붙은 것.
    /// 주소의 모양(시·군·구 → 로·길·동 → 번지)이 시작하는 자리를 찾고, 그 앞 낱말 끝에 붙은 광역 이름을 떼어 준다.
    static func splitGluedNameAndAddress(_ line: String) -> (name: String, address: String)? {
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 3 else { return nil }
        for index in tokens.indices {
            // 이 낱말부터가 주소인가.
            if index > 0, hasAddressShape(Array(tokens[index...])) {
                let name = tokens[..<index].joined(separator: " ")
                if isName(name) { return (name, tokens[index...].joined(separator: " ")) }
            }
            // 이 낱말 끝에 광역 이름이 붙어 있는가 — 「(호남선)서울」.
            for region in regions where tokens[index].hasSuffix(region) && tokens[index].count > region.count {
                let head = String(tokens[index].dropLast(region.count))
                let addressTokens = [region] + Array(tokens[(index + 1)...])
                guard hasAddressShape(addressTokens) else { continue }
                let name = (tokens[..<index] + [head]).joined(separator: " ")
                if isName(name) { return (name, addressTokens.joined(separator: " ")) }
            }
        }
        return nil
    }

    /// 광역 이름 — 긴 것부터, 짧은 것이 긴 것의 꼬리를 먼저 채가지 않게.
    static let regions = [
        "서울특별시", "인천광역시", "부산광역시", "대구광역시", "광주광역시", "대전광역시", "울산광역시", "세종특별자치시",
        "강원특별자치도", "전북특별자치도", "제주특별자치도", "충청북도", "충청남도", "전라북도", "전라남도", "경상북도", "경상남도",
        "경기도", "강원도", "제주도", "서울시", "인천시", "부산시", "대구시", "광주시", "대전시", "울산시", "세종시",
        "서울", "경기", "인천", "부산", "대구", "광주", "대전", "울산", "세종", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주",
    ]

    /// `[네이버 지도]` · `[카카오맵] 이름` — 앞의 `[…]` 를 뗀 나머지. 이름표가 없으면 `nil`.
    ///
    /// 두 글자 이상이어야 이름표다 — `[ ]`·`[x]` 는 체크상자다.
    private static func strippingServiceStamp(_ line: String) -> String? {
        guard let match = line.firstMatch(of: /^\[[^\]]{2,20}\]\s*/) else { return nil }
        return String(line[match.range.upperBound...])
    }

    private static func isLink(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return (lowered.hasPrefix("http://") || lowered.hasPrefix("https://"))
            && !line.contains(where: \.isWhitespace)
    }

    /// 시·군·구 → 로·길·동·읍·면 → 번지 가 이 **순서로** 나와야 주소다.
    ///
    /// 순서를 요구하는 것이 오탐을 막는 장치다. `인구 조사로 3일` 은 앞의 둘을
    /// 통과하지만 `3일` 이 번지가 아니라 걸린다.
    private static func hasAddressShape(_ tokens: [String]) -> Bool {
        guard let district = tokens.firstIndex(where: isDistrict) else { return false }
        guard let street = tokens[(district + 1)...].firstIndex(where: isStreet) else { return false }
        // 지하철역은 `강남대로 지하 396` 이다 — 이 한 낱말만 번지 앞에 끼어들 수 있다.
        var number = street + 1
        if number < tokens.count, tokens[number] == "지하" { number += 1 }
        guard number < tokens.count, isLotNumber(tokens[number]) else { return false }
        return true
    }

    private static func isDistrict(_ token: String) -> Bool {
        token.count >= 2 && ["시", "군", "구"].contains { token.hasSuffix($0) }
    }

    private static func isStreet(_ token: String) -> Bool {
        token.count >= 2 && ["로", "길", "동", "읍", "면"].contains { token.hasSuffix($0) }
    }

    /// `152` 또는 `123-45`. 숫자에 글자가 섞이면 번지가 아니다 (`3일`).
    private static func isLotNumber(_ token: String) -> Bool {
        let parts = token.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    private static func trimmingTrailingPunctuation(_ word: String) -> String {
        var name = word
        while let last = name.last, last.isPunctuation || last.isSymbol { name.removeLast() }
        return name
    }
}
