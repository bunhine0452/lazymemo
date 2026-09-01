import Foundation

/// 사용자가 적은 글에서 **장소**를 알아낸다.
///
/// 날짜와 달리 장소는 **자리를 바꾸지 않는다.** 날짜가 붙으면 종이가 물러나고
/// 달력이 맡지만 (§7.2), 장소가 붙어도 종이는 그대로 있다 — 장소는 종이에 찍힌
/// 잉크 자국 하나이고, 구조는 여전히 시간 하나다 (§14.2). 그래서 이 파서가 채우는
/// 것은 자리가 아니라 필드 하나뿐이다.
///
/// **읽는 규칙은 둘뿐이고, 둘 다 애매함이 없다.**
///
/// 1. 산문 안에서는 `@강남역` 만 읽는다 (`parse`). `@` 는 캘린더·슬랙·인스타에서
///    이미 장소에 쓰는 기호라 배울 것이 없고, 무엇보다 **사람이 직접 찍은 표시**라
///    우리가 짐작한 것이 아니다.
/// 2. 주소는 **문자열이 통째로 주소일 때만** 읽는다 (`address`) — 클립보드나
///    단축어에서 온 것. 지도 앱의 공유 텍스트가 이 모양이다.
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
            return Result(place: name, phrases: ["@" + word])
        }
        return nil
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

    /// 시·군·구 → 로·길·동·읍·면 → 번지 가 이 **순서로** 나와야 주소다.
    ///
    /// 순서를 요구하는 것이 오탐을 막는 장치다. `인구 조사로 3일` 은 앞의 둘을
    /// 통과하지만 `3일` 이 번지가 아니라 걸린다.
    private static func hasAddressShape(_ tokens: [String]) -> Bool {
        guard let district = tokens.firstIndex(where: isDistrict) else { return false }
        guard let street = tokens[(district + 1)...].firstIndex(where: isStreet) else { return false }
        guard street + 1 < tokens.count, isLotNumber(tokens[street + 1]) else { return false }
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
