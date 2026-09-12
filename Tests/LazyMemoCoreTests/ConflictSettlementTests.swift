import Foundation
import Testing
@testable import LazyMemoCore

/// 두 기기가 같은 메모를 따로 고쳤을 때 — 고르되 버리지 않는다.
@Suite("ConflictSettlement — iCloud 충돌")
struct ConflictSettlementTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func memo(_ body: String, updatedBy seconds: TimeInterval) -> Memo {
        Memo(id: ULID(timestamp: base), created: base, updated: base.addingTimeInterval(seconds), body: body)
    }

    @Test("늦게 고친 판본이 자리를 지킨다")
    func laterEditWins() {
        let onDisk = memo("맥에서 적음", updatedBy: 10)
        let fromPhone = memo("폰에서 적음", updatedBy: 60)

        let outcome = ConflictSettlement.settle(current: onDisk, others: [fromPhone], now: base)

        #expect(outcome.keep == fromPhone)
        #expect(outcome.retired.count == 1)
    }

    @Test("진 판본은 새 id 로, deleted 가 찍힌 채, 글은 그대로 휴지통으로 간다")
    func loserIsRetiredNotLost() {
        let onDisk = memo("맥에서 적음", updatedBy: 10)
        let fromPhone = memo("폰에서 적음", updatedBy: 60)
        let now = base.addingTimeInterval(3600)

        let retired = ConflictSettlement.settle(current: onDisk, others: [fromPhone], now: now).retired

        let loser = try! #require(retired.first)
        #expect(loser.body == "맥에서 적음")
        #expect(loser.id != onDisk.id)
        #expect(loser.deleted == now.truncatingSubsecond)
        #expect(loser.created == onDisk.created)
    }

    @Test("시각이 같으면 자리에 있는 쪽이 이긴다 — 이유 없이 파일을 다시 쓰지 않는다")
    func tieKeepsCurrent() {
        let onDisk = memo("하나", updatedBy: 10)
        let other = memo("둘", updatedBy: 10)

        let outcome = ConflictSettlement.settle(current: onDisk, others: [other], now: base)

        #expect(outcome.keep == onDisk)
        #expect(outcome.retired.map(\.body) == ["둘"])
    }

    @Test("글이 같으면 충돌이 아니다 — 시각만 다른 판본은 버린다")
    func identicalContentRetiresNothing() {
        let onDisk = memo("같은 글", updatedBy: 10)
        let echo = memo("같은 글", updatedBy: 60)

        let outcome = ConflictSettlement.settle(current: onDisk, others: [echo], now: base)

        #expect(outcome.keep == echo)
        #expect(outcome.retired.isEmpty)
    }

    @Test("판본이 셋이어도 진 것은 전부 남는다")
    func everyLoserSurvives() {
        let a = memo("a", updatedBy: 1)
        let b = memo("b", updatedBy: 2)
        let c = memo("c", updatedBy: 3)

        let outcome = ConflictSettlement.settle(current: a, others: [b, c], now: base)

        #expect(outcome.keep == c)
        #expect(Set(outcome.retired.map(\.body)) == ["a", "b"])
        #expect(Set(outcome.retired.map(\.id)).count == 2, "휴지통의 두 장이 같은 파일로 겹치면 안 된다")
    }

    @Test("휴지통에 바로 앉힌 판본은 되돌리기 목록에 보인다")
    func retiredMemoLandsInTrash() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = MemoVault(paths: paths)

        let loser = ConflictSettlement.settle(
            current: memo("맥", updatedBy: 1), others: [memo("폰", updatedBy: 2)], now: base
        ).retired[0]
        try await vault.retire(loser)

        let trashed = try await vault.trashedMemos()
        #expect(trashed.map(\.body) == ["맥"])
        #expect(trashed[0].deleted != nil)
        #expect(try await vault.loadAll().isEmpty, "바탕화면을 거치지 않는다")
    }

    @Test("판본이 하나뿐인 보통 파일은 정리할 것이 없다")
    func plainFilesAreLeftAlone() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = MemoVault(paths: paths)
        try await vault.save(Memo(body: "그냥 메모"))

        #expect(try await vault.settleConflicts().isEmpty)
        #expect(try await vault.loadAll().count == 1)
        #expect(try await vault.trashedMemos().isEmpty)
    }
}
