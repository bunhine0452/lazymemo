import Foundation
import LazyMemoCore

/// 질문을 낱말로 — 「치과 예약 언제였지?」 → ["치과", "예약"] (명세 §4 「원문 질의 + 한글 검색」).
///
/// FTS 에 질문 문장을 통째로 구(phrase)로 던지면 아무것도 안 걸린다. 사람은 메모의 문장이 아니라
/// 자기 말로 묻는다. 그래서 조사·물음말·군더더기를 떼고 남는 낱말로 찾고, 동의어는 표로 넓힌다.
public enum QueryTerms {
    public struct Term: Sendable, Equatable {
        public let text: String
        /// 1.0 이 온전한 낱말. 동의어·한 글자 낱말은 그보다 가볍다.
        public let weight: Double
    }

    /// 뒤에 붙는 조사 — 긴 것부터 떼야 「에서」가 「서」로 남지 않는다.
    static let particles = [
        "에서는", "한테서", "으로는", "이라고", "께서는", "에서", "에게", "한테", "으로", "이랑", "까지", "부터",
        "처럼", "보다", "이나", "에는", "께서", "은", "는", "이", "가", "을", "를", "의", "에", "로", "와", "과",
        "도", "랑", "나", "야", "께", "님",
    ]

    /// 낱말 끝의 풀이말 어미 — 「추천해」→「추천」, 「받았더라」는 통째로 버린다.
    static let verbTails = ["했었지", "했더라", "이었지", "했었나", "했지", "였지", "더라", "었지", "았지", "나요", "어요",
                            "아요", "에요", "할까", "될까", "했어", "랬지", "했나", "됐어", "됐지", "는지", "해줘", "해서",
                            "해야", "하기", "하고", "해", "한", "준", "줘"]

    /// 혼자서는 아무것도 가리키지 않는 말.
    static let stopwords: Set<String> = [
        "뭐", "뭐야", "뭐지", "뭔", "언제", "어디", "어떻게", "어떡", "얼마", "몇", "누구", "누가", "왜", "좀", "그", "저", "이",
        "것", "거", "게", "건", "지난번", "저번", "지난", "다음", "이번", "정리", "알려", "보여", "찾아", "해", "했",
        "있", "없", "기억", "메모", "내", "나", "우리", "때", "적어둔", "적은", "적어", "써둔", "쓴", "및", "그리고",
        "좀", "다시", "관련", "대해", "대한", "말", "얘기", "이야기", "the", "a", "an", "what", "when", "where", "how",
        "is", "was", "my", "did", "do", "me",
    ]

    /// 같은 것을 다르게 부르는 말. 한 묶음 안에서는 서로를 찾는다.
    static let synonyms: [[String]] = [
        ["비밀번호", "비번", "패스워드", "password", "pw"],
        ["와이파이", "wifi", "wi-fi", "무선"],
        ["계좌번호", "계좌"],
        ["생일", "생신"],
        ["독서모임", "북클럽", "독서회", "책모임"],
        ["러닝화", "런닝화", "운동화"],
        ["정기점검", "점검", "엔진오일", "정비"],
        ["헬스장", "헬스", "짐", "gym", "피트니스"],
        ["결혼식", "웨딩", "결혼"],
        ["병원", "의원", "클리닉"],
        ["휴대폰", "핸드폰", "폰", "전화기"],
        ["자동차", "차"],
        ["예방접종", "접종", "백신"],
        ["만료", "만기"],
        ["숙소", "호텔", "펜션", "에어비앤비"],
        ["접수번호", "접수", "수리번호"],
        ["빌려준", "빌려줌", "빌려", "대여"],
        ["주소", "집주소"],
        ["팀장", "팀장님"],
        ["약", "복용"],
    ]

    public static func extract(_ text: String) -> [Term] {
        var out: [Term] = []
        var seen = Set<String>()
        func add(_ s: String, _ w: Double) {
            guard !s.isEmpty, !seen.contains(s) else { return }
            seen.insert(s)
            out.append(Term(text: s, weight: w))
        }
        for raw in tokens(text) {
            guard let word = normalize(raw) else { continue }
            let single = word.count == 1
            add(word, single ? 0.3 : 1.0)
            for group in synonyms where group.contains(word) {
                for other in group where other != word { add(other, 0.9) }
            }
        }
        return out
    }

    /// 질문의 개념 하나마다 그 개념을 뜻하는 말들 — 「독서모임 책」 → [[독서모임, 북클럽, …], [책]].
    /// 근거 메모가 질문의 개념을 몇 개나 담고 있는지 셀 때 쓴다 (한 글자 낱말은 빼고).
    public static func concepts(_ text: String) -> [[String]] {
        var out: [[String]] = []
        for raw in tokens(text) {
            guard let word = normalize(raw), word.count >= 2, !out.contains(where: { $0.contains(word) }) else { continue }
            out.append(synonyms.first { $0.contains(word) } ?? [word])
        }
        return out
    }

    public static func conceptHits(_ concepts: [[String]], in text: String) -> Int {
        let hay = text.lowercased()
        return concepts.filter { alternatives in alternatives.contains { hay.contains($0) } }.count
    }

    static func tokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for ch in text.lowercased() {
            if ch.isLetter || ch.isNumber || (ch == "-" && !current.isEmpty) {
                current.append(ch)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }.filter { !$0.isEmpty }
    }

    /// 조사·어미를 떼고 남는 알맹이. 없으면 nil.
    static func normalize(_ raw: String) -> String? {
        var word = raw
        if stopwords.contains(word) { return nil }
        if word.allSatisfy(\.isNumber) { return word }
        if word.allSatisfy({ $0.isASCII }) { return word.count >= 2 ? word : nil }
        for tail in verbTails where word.hasSuffix(tail) && word.count - tail.count >= 2 {
            word = String(word.dropLast(tail.count))
            break
        }
        if stopwords.contains(word) { return nil }
        // 「수현이가」→「수현이」→「수현」: 조사가 겹쳐 붙는다. 두 번까지.
        for _ in 0..<2 {
            guard let particle = particles.first(where: { word.hasSuffix($0) && word.count - $0.count >= 2 }) else { break }
            // 「치과」의 과, 「여권」의 권 — 두 글자 낱말의 끝 글자는 조사가 아니라 낱말의 일부일 때가 많다.
            guard word.count >= 3 || particle.count >= 2 else { break }
            word = String(word.dropLast(particle.count))
        }
        if stopwords.contains(word) { return nil }
        return word.isEmpty ? nil : word
    }
}

/// 낱말이 얼마나 겹치는가로 메모를 줄 세운다. vault 는 사람 하나의 메모라 수백 장이고,
/// 그 정도는 메모리에서 세는 편이 FTS 의 trigram 한계(두 글자 낱말)를 피한다.
public enum MemoRanker {
    public struct Hit: Sendable, Equatable {
        public let memo: Memo
        public let score: Double
    }

    public static func rank(_ memos: [Memo], terms: [QueryTerms.Term], now: Date = Date(), limit: Int = 20) -> [Hit] {
        guard !terms.isEmpty else { return [] }
        var hits: [Hit] = []
        for memo in memos {
            let haystack = (memo.body + "\n" + memo.tags.joined(separator: " ") + "\n" + (memo.folder ?? "") + "\n" + (memo.place ?? "")).lowercased()
            let title = memo.title.lowercased()
            var score = 0.0
            for term in terms {
                if haystack.contains(term.text) {
                    score += term.weight
                    if title.contains(term.text) { score += 0.2 }
                } else if term.text.count >= 3, term.weight >= 0.9 {
                    // 「빌려준」→「빌려」: 어간만 맞아도 절반은 친다.
                    let head = String(term.text.prefix(2))
                    if haystack.contains(head) { score += 0.4 }
                }
            }
            guard score > 0.35 else { continue }
            // 같은 점수면 요즘 것. 한 해 차이가 0.01 을 넘지 않게 — 낱말 하나를 이기지 못한다.
            let age = max(0, now.timeIntervalSince(memo.updated)) / (365 * 86_400)
            score += max(0, 0.01 - age * 0.01)
            hits.append(Hit(memo: memo, score: score))
        }
        hits.sort { $0.score > $1.score }
        return Array(hits.prefix(limit))
    }

    public static func search(_ query: String, in memos: [Memo], now: Date = Date(), limit: Int = 20) -> [Memo] {
        rank(memos, terms: QueryTerms.extract(query), now: now, limit: limit).map(\.memo)
    }
}
