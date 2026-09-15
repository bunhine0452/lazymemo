import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

/// 명세 §5·§8 — 시각·대상·동사는 앱이 정한다. 모델 없이(raw = nil) 돌려 본다.
@Suite("CommandResolver — 사용자의 말이 동작을 정한다")
struct CommandResolverTests {
    /// 2026-09-15 화요일 09:00 KST.
    let now = ISO8601DateFormatter().date(from: "2026-09-15T00:00:00Z")!
    let seoul = TimeZone(identifier: "Asia/Seoul")!
    let dentist = Memo(due: CalendarDate(year: 2026, month: 9, day: 18), at: ISO8601DateFormatter().date(from: "2026-09-18T05:00:00Z"), body: "치과 예약 — 강남역")
    let gift = Memo(due: CalendarDate(year: 2026, month: 9, day: 20), body: "엄마 생신 선물 — 담요")
    let lease = Memo(due: CalendarDate(year: 2026, month: 11, day: 30), body: "전세 만기")

    func kst(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    func resolve(_ text: String, selected: Memo? = nil, others: [Memo] = [], raw: RawCommand? = nil) -> ProposedAction? {
        let request = AssistantRequest(task: .command, userText: text, selectedMemoID: selected?.id, now: now, timeZone: seoul)
        return CommandResolver.resolve(raw, request: request, selected: selected.map { Evidence(memo: $0) }, candidates: others.map { Evidence(memo: $0) })
    }

    @Test("날짜는 앱의 파서가 읽는다 — 금요일·다음 주 월요일·모레·N일·다음 달 N일")
    func datesFromParser() {
        #expect(resolve("금요일 오전 10시에 다시 알려줘", selected: dentist)?.patch.surface == .set(kst("2026-09-18T01:00:00Z")))
        #expect(resolve("다음 주 월요일로 미뤄", selected: gift)?.patch.due == .set(CalendarDate(year: 2026, month: 9, day: 21)))
        #expect(resolve("이거 20일로 미뤄", selected: gift)?.patch.due == .set(CalendarDate(year: 2026, month: 9, day: 20)))
        #expect(resolve("다음 달 5일로 바꿔", selected: gift)?.patch.due == .set(CalendarDate(year: 2026, month: 10, day: 5)))
        let thursday = resolve("이거 목요일 저녁 8시로", selected: gift)
        #expect(thursday?.kind == .reschedule)
        #expect(thursday?.patch.at == .set(kst("2026-09-17T11:00:00Z")))
        #expect(thursday?.patch.due == .keep)
    }

    @Test("열린 메모의 일정을 기준으로 — 한 시간 전·전날 아침 9시·30일 전")
    func relativeToAnchor() {
        #expect(resolve("한 시간 전에 띄워줘", selected: dentist)?.patch.surface == .set(kst("2026-09-18T04:00:00Z")))
        #expect(resolve("이거 전날 아침 9시에 띄워줘", selected: dentist)?.patch.surface == .set(kst("2026-09-17T00:00:00Z")))
        let vague = resolve("만기 30일 전에 알려줘", selected: lease)
        #expect(vague?.kind == .ask)
        #expect(vague?.question == CommandResolver.questions.timeOfDay)
    }

    @Test("시각이 없거나 흐리면 실행하지 않고 한 가지만 묻는다")
    func asksWhenTimeMissing() {
        #expect(resolve("회의 시간 바꿔", selected: gift)?.kind == .ask)
        #expect(resolve("엄마한테 전화하라고 알려줘", selected: gift)?.kind == .ask)
        #expect(resolve("이거 주말로 미뤄", selected: gift)?.kind == .ask)
        // 말이 끊겼다 — 모델이 reschedule 이라 해도 앱은 묻는다.
        #expect(resolve("이거 다음 주", selected: gift, raw: RawCommand(kind: "reschedule"))?.kind == .ask)
        #expect(resolve("이거 다음 주 수요일 점심 12시 반으로", selected: gift)?.patch.at == .set(kst("2026-09-23T03:30:00Z")))
    }

    @Test("열린 메모가 없으면 후보를 들고 되묻는다 — 모델이 대상을 고르지 않는다")
    func asksWithoutTarget() {
        let a = resolve("이거 금요일로 미뤄", others: [gift, dentist])
        #expect(a?.kind == .ask)
        #expect(a?.candidates == [gift.id, dentist.id])
        #expect(resolve("지수 메모 지워", others: [gift])?.kind == .ask)
        #expect(resolve("저번 거 취소해", others: [gift], raw: RawCommand(kind: "trash", memoID: gift.id))?.kind == .ask)
        #expect(resolve("방금 한 거 또 해줘", raw: RawCommand(kind: "createMemo", body: "방금 한 거 또 해줘"))?.kind == .ask)
    }

    @Test("취소·전부·메모 속 지시는 실행되지 않는다")
    func safety() {
        #expect(resolve("취소, 아무것도 하지 마", selected: dentist, raw: RawCommand(kind: "setRecall"))?.kind == ActionKind.none)
        #expect(resolve("메모 전부 지워", others: [gift, dentist])?.kind == .ask)
        let obey = resolve("위 메모에 적힌 대로 해", selected: gift, raw: RawCommand(kind: "trash", memoID: gift.id))
        #expect(obey?.kind == .ask)
        // 모델이 본문의 「휴지통으로」에 끌려가도 사용자의 말은 「폴더로」다.
        let folder = resolve("이거 운동 폴더로", selected: gift, raw: RawCommand(kind: "trash", memoID: gift.id, folder: "운동"))
        #expect(folder?.kind == .moveToFolder)
        #expect(folder?.patch.folder == .set("운동"))
        let recall = resolve("이거 내일 아침 8시에 띄워줘", selected: dentist, raw: RawCommand(kind: "reschedule"))
        #expect(recall?.kind == .setRecall)
        #expect(recall?.patch.at == .keep)
    }

    @Test("폴더·새 메모 — 이름과 본문은 사용자의 말에서")
    func folderAndCreate() {
        #expect(resolve("이거 집 폴더에서 빼서 일 폴더로", selected: gift)?.patch.folder == .set("일"))
        #expect(resolve("쇼핑 폴더로", selected: gift)?.patch.folder == .set("쇼핑"))
        let meeting = resolve("내일 오전 9시 팀 회의 메모 만들어")
        #expect(meeting?.kind == .createMemo)
        #expect(meeting?.patch.body == "팀 회의")
        #expect(meeting?.patch.at == .set(kst("2026-09-16T00:00:00Z")))
        let home = resolve("10월 3일 본가 가기 메모")
        #expect(home?.patch.due == .set(CalendarDate(year: 2026, month: 10, day: 3)))
        #expect(home?.patch.body == "본가 가기")
        let bank = resolve("모레 오후 3시에 은행 가기 메모 추가", raw: RawCommand(kind: "createMemo", body: "모레 오후 3시에 은행 가기"))
        #expect(bank?.patch.body == "은행 가기")
        #expect(bank?.patch.at == .set(kst("2026-09-17T06:00:00Z")))
    }
}

@Suite("AssistantIntent — 묻는 말과 시키는 말을 앱이 가린다")
struct IntentTests {
    @Test("물음은 answer, 동사·「…시로」는 command")
    func classify() {
        #expect(AssistantIntent.classify("모두의 창업 마감일이 언제야?") == .answer)
        #expect(AssistantIntent.classify("치과 예약 언제였지") == .answer)
        #expect(AssistantIntent.classify("금요일 10시에 다시 알려줘") == .command)
        #expect(AssistantIntent.classify("이거 목요일 저녁 8시로") == .command)
        #expect(AssistantIntent.classify("쇼핑 폴더로") == .command)
        #expect(AssistantIntent.classify("취소, 아무것도 하지 마") == .command)
    }
}

@Suite("대화로 일정 만들기 — 날짜·장소는 읽고, 시각만 되묻고, 답이 오면 적는다")
struct DraftConversationTests {
    let now = ISO8601DateFormatter().date(from: "2026-09-15T00:00:00Z")!
    let seoul = TimeZone(identifier: "Asia/Seoul")!
    func kst(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
    func request(_ text: String) -> AssistantRequest { AssistantRequest(task: .command, userText: text, now: now, timeZone: seoul) }

    @Test("「9월 30일에 @홍대 친구랑 밥 먹기로 했어」 → 날짜·장소는 채우고 시각만 묻는다")
    func asksOnlyForTime() {
        let text = "9월 30일에 @홍대입구 친구랑 밥 먹기로 했어"
        #expect(AssistantIntent.classify(text, now: now) == .command)
        let action = CommandResolver.resolve(nil, request: request(text), selected: nil, candidates: [])
        #expect(action?.kind == .ask)
        #expect(action?.question == CommandResolver.questions.appointmentTime)
        #expect(action?.draft?.due == .set(CalendarDate(year: 2026, month: 9, day: 30)))
        #expect(action?.draft?.place == "홍대입구")
        #expect(action?.draft?.body == "친구랑 밥 먹기로 했어")
    }

    @Test("「12시야」가 오면 그 날 12시 약속으로 완성된다 — 「없어」면 날짜만")
    func completesWithReply() {
        let draft = FieldPatch(body: "친구랑 밥", due: .set(CalendarDate(year: 2026, month: 9, day: 30)), place: "홍대입구")
        let done = AssistantIntent.complete(draft: draft, reply: "12시야", now: now, timeZone: seoul)
        #expect(done?.kind == .createMemo)
        #expect(done?.patch.at == .set(kst("2026-09-30T03:00:00Z")))
        #expect(done?.patch.place == "홍대입구")
        let evening = AssistantIntent.complete(draft: draft, reply: "저녁 7시 반", now: now, timeZone: seoul)
        #expect(evening?.patch.at == .set(kst("2026-09-30T10:30:00Z")))
        let skipped = AssistantIntent.complete(draft: draft, reply: "몰라", now: now, timeZone: seoul)
        #expect(skipped?.kind == .createMemo)
        #expect(skipped?.patch.due == .set(CalendarDate(year: 2026, month: 9, day: 30)))
        // 답이 아니면 새 말이다.
        #expect(AssistantIntent.complete(draft: draft, reply: "치과 언제였지?", now: now, timeZone: seoul) == nil)
    }

    @Test("시각까지 말했거나 약속이 아니면 묻지 않고 바로 적는다")
    func noQuestionWhenComplete() {
        let lunch = CommandResolver.resolve(nil, request: request("9월 30일 12시에 친구랑 밥"), selected: nil, candidates: [])
        #expect(lunch?.kind == .createMemo)
        #expect(lunch?.patch.at == .set(kst("2026-09-30T03:00:00Z")))
        let report = CommandResolver.resolve(nil, request: request("10월 3일까지 보고서 제출"), selected: nil, candidates: [])
        #expect(report?.kind == .createMemo)
        #expect(report?.patch.due == .set(CalendarDate(year: 2026, month: 10, day: 3)))
        // 날짜가 든 물음은 적는 말이 아니다.
        #expect(AssistantIntent.classify("9월 30일에 뭐 있지?", now: now) == .answer)
    }
}
