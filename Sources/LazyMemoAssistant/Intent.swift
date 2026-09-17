import Foundation
import LazyMemoCore

/// 사용자의 한 줄이 묻는 말인지 시키는 말인지 — 화면이 「묻기/시키기」를 고르게 하지 않는다.
///
/// 시키는 말에는 동사(알려줘·미뤄·폴더로·지워·메모 만들어)나 「…8시로」가 있다. 그것이 없으면 묻는 말이다 —
/// 「모두의 창업 마감일이 언제야?」를 시키기 칸에 넣어도 답을 받아야 한다 (2026-09-15 맥에서 봤다).
public enum AssistantIntent {
    public static func classify(_ text: String, now: Date = Date()) -> AssistantTask {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 「웹에서 …」·「… 검색해줘」는 메모를 거치지 않고 바로 웹이다 — 「알려줘」가 시키는 동사라도 이것이 먼저.
        if wantsWeb(text) { return .webAnswer }
        if CommandResolver.mentions(CommandResolver.abortWords, in: text) { return .command }
        if CommandResolver.looksLikeQuestion(text) { return .answer }
        if !CommandResolver.verbs(in: text).isEmpty { return .command }
        if CommandResolver.timeWithDirection(text) { return .command }
        // 「9월 30일에 @홍대 친구랑 밥 먹기로 했어」— 날짜나 장소가 든 서술은 적으라는 말이다.
        let note = NoteReader.read(text, now: now)
        if note.due != nil || note.at != nil || note.place != nil || note.geo != nil { return .command }
        return .answer
    }

    /// 웹을 찾으라는 말인가 — 「웹에서 서울 날씨 검색해줘」. 메모 질문이 아니라 검색이다.
    public static func wantsWeb(_ text: String) -> Bool {
        WebQuery.mentionsWeb(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 물음말·물음표가 있는가 — 「치과 언제였지?」. 빠른 입력 상자가 「적기」와 「묻기」를 가르는 기준.
    public static func isQuestion(_ text: String) -> Bool {
        CommandResolver.looksLikeQuestion(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 시키는 동사(알려줘·미뤄·폴더로·지워…)나 「…8시로」가 있는가. 날짜만 있는 서술은 여기 들지 않는다 — 그건 적는 말이다.
    public static func hasCommandVerb(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return CommandResolver.mentions(CommandResolver.abortWords, in: text)
            || !CommandResolver.verbs(in: text).isEmpty || CommandResolver.timeWithDirection(text)
    }

    /// 서술을 새 메모 초안으로 — 날짜·시각·@장소·지도 링크를 읽고, 약속인데 시각이 없으면 `ask` + `draft` 를 돌려준다.
    /// 읽을 것이 없으면 nil — 그때는 그냥 글이다.
    public static func compose(_ text: String, now: Date = Date(), timeZone: TimeZone = .current) -> ProposedAction? {
        let request = AssistantRequest(task: .command, userText: text, now: now, timeZone: timeZone)
        guard let action = CommandResolver.resolve(nil, request: request, selected: nil, candidates: []),
              action.kind == .createMemo || (action.kind == .ask && action.draft != nil) else { return nil }
        return action
    }

    /// 「어느 메모를 말하는지 골라 주세요」인가 — 대상이 빈 시키기. 화면은 이때 목록을 후보로 바꾼다 (D10 「목록이 곧 후보」).
    public static func asksWhichMemo(_ action: ProposedAction) -> Bool {
        action.kind == .ask && action.question == CommandResolver.questions.noTarget
    }

    /// 되물음(「약속 시간이 언제인가요?」)에 온 답을 초안에 잇는다. 답이 아니면 nil.
    public static func complete(draft: FieldPatch, reply: String, now: Date = Date(), timeZone: TimeZone = .current) -> ProposedAction? {
        CommandResolver.complete(draft: draft, reply: reply, request: AssistantRequest(task: .command, userText: reply, now: now, timeZone: timeZone))
    }
}
