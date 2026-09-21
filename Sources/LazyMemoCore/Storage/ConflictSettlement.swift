import Foundation

/// 두 기기가 같은 메모를 따로 고쳤을 때 (iCloud 충돌).
///
/// 맥에서 고치고 폰에서도 고친 채로 둘 다 오프라인이었다가 만나면 iCloud 는
/// 한 파일에 판본을 둘 남긴다. 어느 쪽을 고르든 다른 쪽 글이 사라지는 것이
/// 문제이고, 이 앱에서 글이 사라지는 길은 없어야 한다 (D6).
///
/// 그래서 **고르되 버리지 않는다** — `updated` 가 늦은 판본이 자리를 지키고,
/// 진 판본은 **새 메모가 되어 휴지통에** 간다. 휴지통에서는 되돌리기가 되므로
/// 사용자가 나중에 「어, 그 문장 어디 갔지」 할 때 거기 있다. 같은 내용이면
/// 남길 것이 없으니 아무것도 안 만든다.
///
/// **고른 것은 앱이지 사람이 아니다.** 늦은 시각이 늘 옳은 판은 아니다 — 폰에서 오타 하나
/// 고친 것이 맥에서 한 시간 다듬은 글을 이길 수 있다. 그래서 진 판본에는 어느 메모의
/// 다른 판인지(`Memo.conflictOf`)를 적어 두고, 사람이 휴지통에서 둘을 견주어 **이 판으로**
/// 바꾸거나(`swapped`) **둘 다 남기기**(되돌리기)를 고른다. 어느 쪽을 골라도 글은 안 없어진다.
public enum ConflictSettlement {
    public struct Outcome: Sendable, Equatable {
        /// 자리를 지키는 판본.
        public let keep: Memo
        /// 휴지통으로 갈 판본들 — 새 id, `deleted` 가 채워져 있다.
        public let retired: [Memo]
    }

    /// `current` 는 지금 자리에 있는 것, `others` 는 iCloud 가 남긴 다른 판본들.
    /// 시각이 같으면 자리에 있는 쪽이 이긴다 — 이유 없이 파일을 다시 쓰지 않는다.
    public static func settle(current: Memo, others: [Memo], now: Date = Date()) -> Outcome {
        let keep = others.reduce(current) { best, contender in
            contender.updated > best.updated ? contender : best
        }
        let losers = ([current] + others).filter { $0 != keep && !sameContent($0, keep) }
        let retired = losers.map { loser -> Memo in
            var copy = loser
            copy.id = ULID(timestamp: now)
            copy.created = loser.created
            copy.deleted = now
            // 어느 메모의 다른 판인지 — 이 한 줄이 「지운 메모」와 가른다.
            copy.conflictOf = keep.id
            return copy
        }
        return Outcome(keep: keep, retired: retired)
    }

    /// 사람이 진 판을 골랐다 — **이 판으로.** 자리의 메모는 id 를 지킨 채 진 판의 글을 받고,
    /// 지금까지 자리에 있던 글은 그 자리를 비운 진 판의 id 로 휴지통에 앉는다. 되돌릴 수
    /// 있어야 하므로 밀려난 글도 `conflictOf` 를 달고 남는다 — 한 번 더 바꾸면 원래대로다.
    ///
    /// `kept`·`tidied` 는 자리의 것을 따른다 — 그것은 글이 아니라 그 자리의 상태다.
    public static func swapped(winner: Memo, loser: Memo, now: Date = Date()) -> Outcome {
        var keep = winner
        keep.body = loser.body
        keep.due = loser.due
        keep.at = loser.at
        keep.every = loser.every
        keep.anchor = loser.anchor
        keep.surface = loser.surface
        keep.place = loser.place
        keep.geo = loser.geo
        keep.tags = loser.tags
        keep.color = loser.color
        keep.pinned = loser.pinned
        keep.folder = loser.folder
        keep.preserved = loser.preserved
        keep.updated = now.truncatingSubsecond

        var pushed = winner
        pushed.id = loser.id
        pushed.deleted = now.truncatingSubsecond
        pushed.tidied = nil
        pushed.kept = nil
        pushed.conflictOf = winner.id
        return Outcome(keep: keep, retired: [pushed])
    }

    /// 판본이 둘이어도 글이 같으면 충돌이 아니다 — 시각만 다른 것은 흔하다
    /// (같은 저장이 두 기기에서 되풀이될 때).
    static func sameContent(_ a: Memo, _ b: Memo) -> Bool {
        var x = a, y = b
        x.id = y.id
        x.created = y.created
        x.updated = y.updated
        x.deleted = y.deleted
        x.conflictOf = y.conflictOf
        return x == y
    }
}
