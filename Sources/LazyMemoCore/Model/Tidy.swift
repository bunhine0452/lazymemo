import Foundation

/// 끝난 것이 스스로 물러나는 규칙 (철학 3, 플랜 `{#tidy-rule}`).
///
/// 게으른 사람에게 가장 빨리 오는 실패는 **낡은 종이가 쌓이는 것**이다.
/// 다 끝낸 장보기 목록과 지난주 약속이 바탕화면과 메뉴 목록을 차지하고
/// 있으면, 지금 봐야 할 한 장이 그 사이에 묻힌다. 그러면 사람은 정리를
/// 시작하는 대신 앱을 그만 쓴다 — 정리하기 싫어서 이 앱을 쓰기 시작했으므로.
///
/// **치우는 것은 지우는 것이 아니다.** 치워 둔 메모는 파일에 그대로 있고,
/// 검색하면 나오고, 달력에도 그대로 있다. 메뉴가 «치워 둔 N장» 이라고 적고
/// 한 번에 도로 꺼낸다 (`{#tidy-visible-undo}`). 여기서 정하는 것은
/// **바탕화면과 목록에서 물러날 때**뿐이다.
///
/// 규칙을 `LazyMemoUI` 가 아니라 여기 두는 이유는 D6 의 휴지통과 같다 —
/// 무엇이 언제 사라지는지는 화면의 사정이 아니라 데이터의 규칙이고, 화면
/// 없이 시험으로 못 박을 수 있어야 한다.
public enum Tidy {
    /// 왜 물러났는가. 사람에게 말해 줄 때 쓴다 — "사라졌다" 로 읽히면 실패다.
    public enum Reason: String, Sendable, Equatable, CaseIterable {
        /// 목록의 칸을 전부 체크했다.
        case finished
        /// 적힌 날이 지났다.
        case past

        /// 메뉴에 적는 말.
        public var label: String {
            switch self {
            case .finished: "다 체크한 목록"
            case .past: "지난 일정"
            }
        }
    }

    /// 다 체크한 목록이 물러나기까지, 마지막으로 손댄 때로부터.
    ///
    /// **마지막 칸을 체크한 그 순간 사라지면 안 된다.** 방금 끝낸 일이 눈앞에서
    /// 없어지는 것은 성취가 아니라 사고로 보이고, 사람은 "지워졌다" 고 여긴다.
    /// 사흘이면 "아직 거기 있네" 를 몇 번 보고 나서 물러난다.
    public static let finishedGrace: TimeInterval = 3 * 24 * 60 * 60

    /// 지난 일정이 물러나기까지, **그 날이 끝난 때로부터.**
    ///
    /// 그 날 자정에 사라지면 "어제 뭐 했더라" 가 안 된다. 하루를 더 두면
    /// 다음 날 온종일 그 자리에 있다가 그 다음 자정에 물러난다.
    public static let pastGrace: TimeInterval = 1 * 24 * 60 * 60

    /// 이 메모가 지금 물러나야 하는가. 아니면 `nil`.
    ///
    /// 손대지 않는 것 셋:
    /// - **고정한 것** — 사람이 "계속 보겠다" 고 정한 것을 규칙이 이길 수 없다.
    /// - **이미 치운 것** — 두 번 치울 것이 없다.
    /// - **휴지통에 있는 것** — 그쪽은 D6 이 맡는다.
    public static func reason(
        for memo: Memo, now: Date = Date(), calendar: Calendar = .current
    ) -> Reason? {
        guard memo.tidied == nil, memo.deleted == nil, !memo.pinned else { return nil }

        // 시간이 유일한 구조다 (§14.2) — 날짜가 있으면 그것부터 본다.
        if let day = memo.scheduledDate(calendar: calendar),
           let dayEnded = day.adding(days: 1, calendar: calendar).startOfDay(calendar: calendar),
           now.timeIntervalSince(dayEnded) >= pastGrace {
            return .past
        }

        if isFinishedChecklist(memo.body), now.timeIntervalSince(memo.updated) >= finishedGrace {
            return .finished
        }

        return nil
    }

    /// 체크상자가 하나라도 있고 **전부** 체크됐는가.
    ///
    /// 칸이 하나도 없는 메모는 목록이 아니다 — 끝났는지 아닌지를 앱이 알 길이
    /// 없으므로 건드리지 않는다. 그냥 적어 둔 글은 사람이 지울 때까지 남는다.
    public static func isFinishedChecklist(_ body: String) -> Bool {
        let boxes = MarkdownScanner.checkboxes(in: body)
        return !boxes.isEmpty && boxes.allSatisfy { $0 }
    }
}
