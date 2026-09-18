import Foundation
import LazyMemoCore

/// 웹의 답 뒤에 오는 말 — 「메모해」「정리해줘」「치과 메모에 추가해줘」.
///
/// 웹에서 찾은 것은 메모가 아니라 화면에 잠깐 선 글이다. 사람은 그 다음에 대개 셋 중 하나를 한다 —
/// 그대로 남기거나, 정리해서 남기거나, 이미 있는 메모에 붙인다. 답이 서 있는 동안 그 셋을 먼저
/// 묻고(`question`), 말로 해도 같은 곳에 닿는다. **답이 서 있을 때만 뜻이 있다** — 「메모해」는
/// 평소에는 새 메모를 만들라는 말이다 (`CommandResolver.verbs`).
public enum WebFollowUp: Hashable, Sendable {
    /// 그대로 메모로 남긴다 — 답 한 줄, 출처와 발췌, 어디서 찾았는지.
    case keep
    /// 모델이 다듬어 메모로 남긴다. 모델이 없으면 `keep` 과 같다.
    case tidy
    /// 이미 있는 메모에 붙인다. `hint` 는 그 메모를 가리키는 말(「치과」) — 없으면 고르게 한다.
    case append(hint: String?)

    /// 답 밑에 서는 되물음.
    public static let question = "이걸 어떻게 할까요?"
    /// 붙일 메모를 고르게 하는 되물음 — 「어느 메모?」와 같은 자리 (`AssistantIntent.asksWhichMemo`).
    public static let whichMemo = "어느 메모에 붙일까요?"

    // MARK: 말 읽기

    /// 「…에 추가」「…에 붙여」「…에 넣어」— 앞이 메모를 가리키는 말이다.
    static let appendPattern = #"(.*?)(?:에다|에)\s*(?:추가|붙여|붙이|넣어|넣고|더해|적어|이어|합쳐)"#
    static let tidyWords = ["정리", "요약", "다듬", "깔끔", "summar", "tidy", "organize", "clean"]
    static let keepWords = ["메모", "남겨", "남기", "적어", "저장", "기록", "보관", "keep", "save", "note", "remember"]
    /// 덧붙는 말 — 이것만 남으면 «그 답을» 가리킨 것이다.
    static let fillers = ["검색결과", "검색 결과", "결과", "이내용", "이 내용", "내용", "이거", "이걸", "이것", "그거", "그걸", "그것",
                          "답변", "답", "위에", "위", "웹", "찾은거", "찾은 것", "찾은것", "그대로", "새로", "새", "하나", "좀", "그냥",
                          "부탁", "주세요", "해주세요", "해줘", "해줄래", "해 줘", "해서", "하고", "한 뒤", "해", "줘", "요", "로", "으로", "를", "을", "도", "만",
                          "this", "it", "please", "the", "answer", "result", "results", "a", "as", "memo", "note"]
    /// 붙일 메모를 가리키는 말에서 걷어내는 것 — 「기존 메모」「어디 메모」는 가리킨 것이 없다.
    static let targetFillers = ["메모", "노트", "기존", "원래", "있던", "지금", "다른", "그", "저", "이", "어느", "어디", "아무", "적당한",
                                "이거", "이걸", "이것", "이 내용", "이내용", "내용", "검색 결과", "검색결과", "결과", "답", "위", "웹", "찾은 것", "찾은것", "찾은거"]

    /// 이 말이 웹의 답에 대한 다음 손짓인가. 물음·새 검색·다른 내용이 든 말은 아니다 —
    /// 「내일 우산 챙기기 메모해」는 답이 아니라 우산을 적으라는 말이다.
    public static func read(_ text: String) -> WebFollowUp? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !WebQuery.mentionsWeb(text), !text.hasSuffix("?"), !text.hasSuffix("？") else { return nil }
        // 「어디 메모에 추가해줘」의 「어디」는 물음말이 아니라 «아무 데나» 다 — 붙이라는 말을 물음보다 먼저 본다.
        if let hint = appendTarget(in: text) { return .append(hint: hint.isEmpty ? nil : hint) }
        guard !CommandResolver.looksLikeQuestion(text) else { return nil }
        let lowered = text.lowercased()
        if CommandResolver.mentions(tidyWords, in: lowered) {
            // 「요약해서 남겨」— 남기라는 말은 정리에 딸린 말이다.
            return remainder(of: lowered, without: tidyWords + keepWords).count <= 1 ? .tidy : nil
        }
        if CommandResolver.mentions(keepWords, in: lowered) {
            return remainder(of: lowered, without: keepWords).count <= 1 ? .keep : nil
        }
        return nil
    }

    /// 「치과 메모에 추가해줘」→ 「치과」. 붙이라는 말이 아니면 nil, 가리킨 메모가 없으면 빈 문자열.
    static func appendTarget(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: appendPattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        var hint = String(text[range])
        for word in targetFillers { hint = hint.replacingOccurrences(of: word, with: " ") }
        return hint.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// 뜻이 있는 말을 걷어낸 나머지 — 덧붙는 말·문장부호도 뺀다.
    static func remainder(of text: String, without words: [String]) -> String {
        var rest = text
        for word in words + fillers { rest = rest.replacingOccurrences(of: word, with: "") }
        return rest.filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }
    }

    // MARK: 메모 본문

    /// 남길 글 — 제목(물음)·답 한 문장·출처 목록·꼬리. 자리는 정리한 메모와 같다 (`Digest.keep`).
    ///
    /// 답이 인용한 것만 담는다. 나머지 결과는 화면에 있을 뿐이다 — 메모는 사람이 읽은 것이어야지 검색
    /// 페이지의 복사본이어서는 안 된다. 인용이 없으면(모델 없이 결과만) 보여 준 앞의 셋.
    public static func body(question: String, answer: AssistantAnswer, results: [Evidence], footer: String) -> String {
        Digest.keep(question: question, answer: answer, results: results, footer: footer)
    }
}
