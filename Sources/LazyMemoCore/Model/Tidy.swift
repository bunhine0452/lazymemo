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
            case .finished: L("다 체크한 목록")
            case .past: L("지난 일정")
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
    /// 손대지 않는 것 넷:
    /// - **고정한 것** — 사람이 "계속 보겠다" 고 정한 것을 규칙이 이길 수 없다.
    /// - **도로 꺼낸 것**(`kept`) — 치운 것을 사람이 꺼냈으면 그 손이 규칙보다 앞선다.
    ///   안 그러면 꺼낸 그 날 저녁에 도로 없어지고, 사람 눈에 그것은 고장이다.
    /// - **이미 치운 것** — 두 번 치울 것이 없다.
    /// - **휴지통에 있는 것** — 그쪽은 D6 이 맡는다.
    ///
    /// **날짜가 지났다고 끝난 것이 아니다** (인계서 §4). 칸이 남은 목록은 마감이 지나도
    /// 아직 할 일이고, 미래에 다시 보기로 한 것은 그때까지 살아 있어야 한다 — 지난 일정이라
    /// 치워 버리면 그 다시 보기의 알림은 걸리지 않고, 「적었는데 없어졌다」가 된다.
    public static func reason(
        for memo: Memo, now: Date = Date(), calendar: Calendar = .current
    ) -> Reason? {
        guard memo.tidied == nil, memo.deleted == nil, memo.archived == nil, !memo.pinned, memo.kept == nil else { return nil }
        // **되풀이하는 일은 지나가지 않는다.** 지난 회차라서 물러나야 할 것처럼
        // 보이지만, 그 자리는 물러남이 아니라 다음 회차로 걸어감이다 (`rolled`).
        // 여기서 치우면 분리수거는 딱 한 번 하고 영영 사라진다.
        guard memo.every == nil else { return nil }

        // **사람이 끝냈다고 한 것**은 그때부터 사흘 뒤에 물러난다 — 다 체크한 목록과 같은 셈. 끝낸 순간 없어지면 사고다.
        if let done = memo.done {
            return now.timeIntervalSince(done) >= finishedGrace ? .finished : nil
        }

        // **목록은 칸이 말한다** — 마감이 지났어도. 칸이 남았으면 아직 할 일이고(날짜 경과는
        // 완료가 아니다), 다 체크했으면 마지막으로 손댄 지 사흘 뒤에 물러난다. 지난 마감으로
        // 먼저 재면 밀린 목록의 마지막 칸을 체크한 그 밤에 사라진다 — 성취가 아니라 사고다.
        let boxes = MarkdownScanner.checkboxes(in: memo.body)
        if !boxes.isEmpty {
            guard boxes.allSatisfy({ $0 }), now.timeIntervalSince(memo.updated) >= finishedGrace else { return nil }
            return .finished
        }

        // 칸이 없는 글은 날짜가 말한다 (§14.2 — 시간이 유일한 구조). 다시 볼 날이 따로
        // 있으면 **둘 중 늦은 날**이 지나야 지난 것이다: 미래에 다시 보기로 했으면 그날까지
        // 살아 있고, 다시 본 뒤에는 그 날을 기준으로 물러난다.
        if let day = lastDay(of: memo, calendar: calendar),
           let dayEnded = day.adding(days: 1, calendar: calendar).startOfDay(calendar: calendar),
           now.timeIntervalSince(dayEnded) >= pastGrace {
            return .past
        }

        return nil
    }

    /// 일정의 마지막 날 — 일정 날과 다시 볼 날 중 늦은 쪽. 일정이 없으면 `nil`.
    ///
    /// 다시 볼 시각만 있고 일정이 없는 메모는 그냥 메모다 — 다시 본 뒤에도 날짜 없는 글이고,
    /// 날짜 없는 글은 사람이 지울 때까지 남는다. 그래서 다시 볼 날은 일정을 **늘릴 뿐** 만들지 않는다.
    private static func lastDay(of memo: Memo, calendar: Calendar) -> CalendarDate? {
        guard let scheduled = memo.scheduledDate(calendar: calendar) else { return nil }
        guard let surface = memo.surface else { return scheduled }
        return max(scheduled, CalendarDate(surface, calendar: calendar))
    }

    /// 되풀이하는 일정이 지났으면 **다음 회차로 걸어간 메모**를, 아니면 `nil`.
    ///
    /// 「지난 일정은 물러난다」의 짝이다 — 물러나는 대신 앞으로 간다. 밀린 만큼
    /// 한 번에 걸어가는 이유는 앱을 몇 주 안 켰을 수 있기 때문이다
    /// (`Recurrence.walk`).
    ///
    /// **나올 때도 함께 옮긴다.** 안 그러면 다음 회차에 종이가 안 나온다 —
    /// 「30분 전」이 지난 회차의 30분 전에 그대로 남는다.
    ///
    /// **달·해 걸음은 처음 적힌 날에서 잰다** (`Memo.anchor`). 안 그러면 「매월 31일」이
    /// 2월을 지나며 28일이 되고 영영 돌아오지 않는다. 처음 날이 안 적혀 있으면 지금 날이
    /// 처음이고, 적혀 있어도 지금 날을 설명하지 못하면(사람이 옮겼다) 지금 날이 처음이다.
    public static func rolled(
        _ memo: Memo, now: Date = Date(), calendar: Calendar = .current
    ) -> Memo? {
        guard let every = memo.every, memo.deleted == nil else { return nil }
        var moved = memo

        if let at = memo.at {
            let anchor = anchor(of: memo, on: CalendarDate(at, calendar: calendar), calendar: calendar)
            guard let next = every.walk(at, past: now, anchor: anchor, calendar: calendar) else { return nil }
            let shift = next.timeIntervalSince(at)
            moved.at = next
            moved.anchor = anchor
            if memo.due != nil { moved.due = CalendarDate(next, calendar: calendar) }
            if let surface = memo.surface { moved.surface = surface.addingTimeInterval(shift) }
        } else if let due = memo.due {
            // 날짜만 있는 것은 **그 날이 끝나야** 지난 것이다 (`pastGrace` 와 같은 셈).
            let anchor = anchor(of: memo, on: due, calendar: calendar)
            guard let midnight = due.startOfDay(calendar: calendar),
                  let today = CalendarDate(now, calendar: calendar).startOfDay(calendar: calendar),
                  midnight < today,
                  let next = every.walk(
                      midnight, past: today.addingTimeInterval(-1), anchor: anchor, calendar: calendar
                  )
            else { return nil }
            moved.due = CalendarDate(next, calendar: calendar)
            moved.anchor = anchor
            if let surface = memo.surface {
                moved.surface = surface.addingTimeInterval(next.timeIntervalSince(midnight))
            }
        } else {
            // 날짜 없는 되풀이는 걸어갈 자리가 없다. 규칙만 적어 두고 둔다.
            return nil
        }

        // 걸어간 것은 다시 산 것이다 — 치워 뒀더라도 도로 나온다. **이번 회차의 완료는 이번 회차까지다**:
        // 끝냈다는 표시와 체크한 칸을 비운다. 안 그러면 「매주 분리수거」를 한 번 끝낸 사람의 다음 회차에
        // 알림이 영영 없다 (인계서 R06).
        moved.tidied = nil
        moved.done = nil
        moved.body = Checklist.uncheckingAll(in: memo.body)
        return moved
    }

    /// 이 회차의 처음 날. 잘리지 않는 주기(매일·매주)는 없다 — 적어 둘 것이 없다.
    private static func anchor(of memo: Memo, on day: CalendarDate, calendar: Calendar) -> CalendarDate? {
        guard let every = memo.every, every.clips else { return nil }
        if let known = memo.anchor, every.explains(known, day, calendar: calendar) { return known }
        return day
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
