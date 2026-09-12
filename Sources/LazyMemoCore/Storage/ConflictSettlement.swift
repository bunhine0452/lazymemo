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
            return copy
        }
        return Outcome(keep: keep, retired: retired)
    }

    /// 판본이 둘이어도 글이 같으면 충돌이 아니다 — 시각만 다른 것은 흔하다
    /// (같은 저장이 두 기기에서 되풀이될 때).
    static func sameContent(_ a: Memo, _ b: Memo) -> Bool {
        var x = a, y = b
        x.id = y.id
        x.created = y.created
        x.updated = y.updated
        x.deleted = y.deleted
        return x == y
    }
}
