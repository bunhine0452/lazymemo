import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

@Suite("검색 — 질문을 낱말로, 메모를 점수로")
struct RetrievalTests {
    @Test("조사·물음말을 떼고 낱말만 남긴다")
    func terms() {
        let t = QueryTerms.extract("치과 예약 언제였지?").map(\.text)
        #expect(t == ["치과", "예약"])
        #expect(QueryTerms.extract("지훈이 계좌번호 뭐였지?").map(\.text).prefix(2) == ["지훈", "계좌번호"])
        #expect(QueryTerms.extract("수현이가 추천해 준 책 제목").map(\.text).contains("수현"))
        #expect(QueryTerms.extract("집 와이파이 비밀번호").map(\.text).contains("비번"))
    }

    @Test("fixture 143장에서 답변 문항의 정답 메모가 상위 6 안에 든다 — Recall@6 ≥ 90% (명세 §8)")
    func recallAtSix() throws {
        let (vault, questions) = try AssistantFixtures.load()
        let memos = AssistantFixtures.memos(vault)
        let now = AssistantFixtures.iso(vault.now) ?? Date()
        var total = 0, hit = 0
        var misses: [String] = []
        for q in questions.items where q.kind == "answer" {
            guard let expected = q.expect.evidence, !expected.isEmpty else { continue }
            total += 1
            let top = MemoRanker.search(q.text, in: memos.filter(Recall.eligible), now: now, limit: 6).map(\.id.stringValue)
            if expected.allSatisfy(top.contains) { hit += 1 } else { misses.append("\(q.id) \(q.text) → \(top.prefix(3))") }
        }
        let recall = Double(hit) / Double(max(total, 1))
        #expect(recall >= 0.9, "Recall@6 \(hit)/\(total)\n\(misses.joined(separator: "\n"))")
    }
}
