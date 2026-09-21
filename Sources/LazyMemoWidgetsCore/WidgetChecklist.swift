import Foundation
import LazyMemoCore

/// 「지금」 위젯의 체크상자 — 카드의 아직 안 한 칸을 고르고, 눌리면 파일에 적는다.
///
/// 편의성 감사(§3.4)의 셈이다: 체크리스트 한 칸을 끄려고 앱을 열어 종이를 찾으면 셋, 위젯에서
/// 누르면 하나. 「봤어요」(`NowSeen`)와 달리 **파일에 적는다** — 그 칸이 체크됐다는 사실은
/// 이 기기의 기억이 아니라 메모의 것이라서, 맥의 종이도 같은 칸이 체크돼야 한다.
///
/// 확장이 파일을 고치는 첫 자리라 규칙을 좁게 잡는다. 바꾸는 것은 괄호 안 **한 글자**와
/// `updated` 뿐이고(편집기의 `toggleCheckbox` 와 같다) 첨부·되풀이·인덱스·「다 체크한 목록은
/// 물러난다」(`Tidy`)는 그대로 앱이 든다 — 앱은 앞으로 나올 때 파일을 대조한다(`reconcile`).
/// 줄은 자리가 아니라 글로 찾아(`Checklist.toggle`) 그 사이 메모가 바뀌었어도 엉뚱한 줄을
/// 뒤집지 않고, 읽은 본문의 hash 로 쓰기를 걸어 그 사이 파일이 바뀌었으면 손대지 않는다.
public enum WidgetChecklist {
    /// 위젯에 서는 칸 하나 — 어느 메모의 어떤 글인지. 자리는 들지 않는다.
    public struct Item: Identifiable, Equatable, Sendable {
        public let memo: ULID
        public let text: String
        public var id: String { memo.description + "\u{1F}" + text }

        public init(memo: ULID, text: String) {
            self.memo = memo
            self.text = text
        }
    }

    /// 카드들의 아직 안 한 칸 — 앞 카드부터, 카드마다 `perCard` 까지, 다 합쳐 `limit` 까지.
    /// 같은 글이 두 줄이면 첫 줄만 — 어느 줄을 뒤집을지 글로 가르므로 둘을 따로 세울 수 없다.
    public static func openItems(of cards: [Recall.Card], limit: Int = 3, perCard: Int = 3) -> [Item] {
        var items: [Item] = []
        for card in cards {
            var seen: Set<String> = []
            var taken = 0
            for line in Checklist.lines(in: card.memo.body) where !line.done && seen.insert(line.text).inserted {
                guard taken < perCard, items.count < limit else { break }
                items.append(Item(memo: card.id, text: line.text))
                taken += 1
            }
            if items.count >= limit { break }
        }
        return items
    }

    /// 그 칸을 체크해 파일에 적는다. 줄이 없거나 이미 체크됐거나 그 사이 파일이 바뀌었으면 `false` —
    /// 파일은 그대로다.
    @discardableResult
    public static func check(_ text: String, of id: ULID, in paths: AppPaths, now: Date = Date()) async throws -> Bool {
        let vault = MemoVault(paths: paths)
        let memo = try await vault.load(id)
        guard let edit = Checklist.toggle(text, done: false, in: memo.body) else { return false }
        let body = Checklist.applying(edit, to: memo.body)
        // 파일이 담는 정밀도 — 초 아래는 버린다 (`Memo.init` 과 같다).
        let stamp = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        do {
            try await vault.modify(id, expectedHash: memo.contentHash) { memo in
                memo.body = body
                memo.updated = stamp
            }
        } catch MemoVault.Failure.changed {
            return false
        }
        return true
    }
}
