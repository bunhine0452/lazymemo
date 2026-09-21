import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoWidgetsCore

@Suite("WidgetChecklist — 「지금」 위젯의 체크상자")
struct WidgetChecklistTests {
    private func card(_ body: String, reason: Recall.Reason = .pinned) -> Recall.Card {
        Recall.Card(memo: Memo(pinned: true, body: body), reason: reason, moment: nil, stamp: Date())
    }

    @Test("앞 카드부터 안 한 칸만, 카드마다 셋·다 합쳐 셋")
    func picksOpenItemsInOrder() {
        let groceries = card("장보기\n- [x] 우유\n- [ ] 계란\n- [ ] 두부\n- [ ] 김\n- [ ] 파")
        let plain = card("그냥 메모")
        let chores = card("- [ ] 분리수거")
        let items = WidgetChecklist.openItems(of: [plain, groceries, chores])
        #expect(items.map(\.text) == ["계란", "두부", "김"])
        #expect(items.allSatisfy { $0.memo == groceries.id })
        #expect(WidgetChecklist.openItems(of: [chores, groceries], perCard: 1).map(\.text) == ["분리수거", "계란"])
        #expect(WidgetChecklist.openItems(of: [plain]).isEmpty)
        // 같은 글이 두 줄이면 하나.
        #expect(WidgetChecklist.openItems(of: [card("- [ ] 우유\n- [ ] 우유")]).count == 1)
    }

    @Test("누르면 파일의 괄호 안 한 글자가 바뀌고 updated 가 오른다 — 두 번째는 아무 일도 없다")
    func checksIntoTheFile() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-widget-check-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = MemoVault(paths: paths)
        let yesterday = Date(timeIntervalSinceNow: -86_400)
        let memo = Memo(updated: yesterday, pinned: true, body: "장보기\n- [ ] 우유\n- [ ] 계란")
        try await vault.save(memo)

        let now = Date()
        #expect(try await WidgetChecklist.check("우유", of: memo.id, in: paths, now: now))
        let after = try await vault.load(memo.id)
        #expect(after.body == "장보기\n- [x] 우유\n- [ ] 계란")
        #expect(after.updated > yesterday)
        #expect(after.pinned)   // 다른 것은 손대지 않는다

        #expect(try await WidgetChecklist.check("우유", of: memo.id, in: paths) == false)
        #expect(try await WidgetChecklist.check("없는 줄", of: memo.id, in: paths) == false)
        #expect(try await vault.load(memo.id).body == after.body)
    }
}
