import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 명세 §4 — 모델의 답 위에 앱이 원문을 세운다. 인용은 보여 준 것만, 지어낸 근거는 버린다.
@Suite("답변 검증 — 원문 인용과 되살리기")
struct AnswerValidatorTests {
    let wifi = Memo(body: "집 와이파이\nSSID: home_5g\n비번: sunny-day-2026")
    let dentist = Memo(at: Date(), body: "치과 예약 — 강남역 서울밝은치과. 18일 오후 2시.")
    let dentist2 = Memo(body: "치과 예약 잡음. 18일 오후 3시 반이라고 들었는데 확인 필요.")
    let gift = Memo(body: "엄마 생신 선물 — 담요")

    func answer(_ json: String, question: String, memos: [Memo]) -> AssistantAnswer? {
        OutputValidator.answer(json, allowed: memos.map { Evidence(memo: $0) }, question: question)
    }

    @Test("답 밑에 인용한 메모의 원문 줄이 선다")
    func quotesFollowAnswer() {
        let a = answer(#"{"found": true, "answer": "sunny-day-2026", "evidence": ["\#(wifi.id)"]}"#, question: "집 와이파이 비밀번호", memos: [wifi, gift])
        #expect(a?.found == true)
        #expect(a?.evidence == [wifi.id])
        #expect(a?.quotes == ["집 와이파이 · SSID: home_5g · 비번: sunny-day-2026"])
    }

    @Test("answer 가 비어도 근거를 맞게 댔으면 그 원문이 답이다")
    func emptyAnswerWithCitation() {
        let a = answer(#"{"found": true, "answer": ": ", "evidence": ["\#(wifi.id)"]}"#, question: "집 와이파이 비밀번호", memos: [wifi, gift])
        #expect(a?.found == true)
        #expect(a?.quotes.first?.contains("와이파이") == true)
    }

    @Test("모델이 못 찾아도 질문의 개념을 둘 이상 담은 메모는 답으로 보여 준다 — 하나만 겹치면 아니다")
    func strongMatchFallback() {
        let found = answer(#"{"found": false, "answer": "", "evidence": []}"#, question: "치과 예약 언제였지?", memos: [dentist, gift])
        #expect(found?.found == true)
        #expect(found?.evidence == [dentist.id])
        let weak = answer(#"{"found": false, "answer": "", "evidence": []}"#, question: "엄마 주소 뭐야?", memos: [dentist, gift])
        #expect(weak?.found == false)
    }

    @Test("질문과 낱말이 하나도 안 겹치는 인용은 지어낸 근거다")
    func fabricatedCitationDropped() {
        let a = answer(#"{"found": true, "answer": "작년에 스키장에 갔다", "evidence": ["\#(gift.id)"]}"#, question: "작년 크리스마스에 뭐 했지?", memos: [gift, wifi])
        #expect(a?.found == false)
    }

    @Test("같은 만큼 맞는 다른 메모가 있으면 함께 보여 준다 — 근거가 갈리면 확정하지 않는다")
    func rivalShownOnTie() {
        let a = answer(#"{"found": true, "answer": "18일 오후 2시", "evidence": ["\#(dentist.id)"]}"#, question: "치과 몇 시였지?", memos: [dentist, dentist2, gift])
        #expect(a?.evidence == [dentist.id, dentist2.id])
        #expect(a?.quotes.count == 2)
    }

    @Test("잘린 브리핑 JSON 에서 온전한 항목만 건진다")
    func salvagesTruncatedBrief() {
        let text = #"{"items": [{"memoID": "\#(gift.id)", "reason": "오늘 마감"}, {"memoID": "\#(wifi.id)", "rea"#
        let request = AssistantRequest(task: .brief, userText: "")
        let items = OutputValidator.brief(text, allowed: [gift, wifi].map { Evidence(memo: $0) }, request: request)
        #expect(items?.map(\.memoID) == [gift.id])
    }
}
