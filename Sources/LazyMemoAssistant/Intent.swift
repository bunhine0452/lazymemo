import Foundation

/// 사용자의 한 줄이 묻는 말인지 시키는 말인지 — 화면이 「묻기/시키기」를 고르게 하지 않는다.
///
/// 시키는 말에는 동사(알려줘·미뤄·폴더로·지워·메모 만들어)나 「…8시로」가 있다. 그것이 없으면 묻는 말이다 —
/// 「모두의 창업 마감일이 언제야?」를 시키기 칸에 넣어도 답을 받아야 한다 (2026-09-15 맥에서 봤다).
public enum AssistantIntent {
    public static func classify(_ text: String) -> AssistantTask {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if CommandResolver.mentions(CommandResolver.abortWords, in: text) { return .command }
        if !CommandResolver.verbs(in: text).isEmpty { return .command }
        if CommandResolver.timeWithDirection(text) { return .command }
        return .answer
    }
}
