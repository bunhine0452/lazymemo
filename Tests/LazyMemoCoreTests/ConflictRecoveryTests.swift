import Foundation
import Testing
@testable import LazyMemoCore

/// 충돌을 **사람이 복구할 수 있는가** (인계서 묶음 5 · `#conflict-recovery`).
///
/// `ConflictSettlementTests` 는 「진 판본이 없어지지 않는다」를 잰다. 여기서 재는 것은 그 다음이다 —
/// 진 판본이 지운 메모와 **구별되는가**, 사람이 두 판을 견주어 **이 판으로** 바꾸거나 **둘 다
/// 남길** 수 있는가, 어느 길로 가도 글과 사진이 안 없어지는가. 앱이 고른 판이 늘 옳지는 않다:
/// 폰의 오타 하나가 맥의 한 시간을 이긴다.
@Suite("충돌 복구 — 진 판을 사람이 고른다")
struct ConflictRecoveryTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func memo(_ body: String, updatedBy seconds: TimeInterval, id: ULID? = nil) -> Memo {
        Memo(id: id ?? ULID(timestamp: base), created: base, updated: base.addingTimeInterval(seconds), body: body)
    }

    private func makePaths() throws -> AppPaths {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-conflict-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return paths
    }

    private func remove(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    // MARK: 표시

    @Test("진 판본은 어느 메모의 다른 판인지 적는다 — 파일만 봐도 지운 메모와 갈린다")
    func loserNamesItsWinner() {
        let onDisk = memo("맥에서 적음", updatedBy: 10)
        let fromPhone = memo("폰에서 적음", updatedBy: 60)
        let outcome = ConflictSettlement.settle(current: onDisk, others: [fromPhone], now: base)

        let loser = outcome.retired[0]
        #expect(loser.conflictOf == outcome.keep.id)
        #expect(MemoFile.encode(loser).contains("conflict: \(outcome.keep.id.stringValue)"))
    }

    @Test("`conflict:` 는 파일을 왕복해도 남고, 없으면 줄도 없다")
    func conflictMarkerRoundTrips() throws {
        let winner = ULID()
        let decoded = try MemoFile.decode(MemoFile.encode(Memo(body: "다른 판", deleted: base, conflictOf: winner)))
        #expect(decoded.conflictOf == winner)
        #expect(!MemoFile.encode(Memo(body: "보통")).contains("conflict:"))
    }

    // MARK: 이 판으로 — 규칙

    @Test("이 판으로: 자리의 id 는 지키고 글만 바뀌며, 밀려난 글은 되돌릴 수 있게 남는다")
    func swappedKeepsIdentityAndIsReversible() {
        let winner = memo("폰의 오타 수정", updatedBy: 60)
        var loser = memo("맥에서 한 시간 다듬은 글", updatedBy: 10, id: ULID(timestamp: base.addingTimeInterval(100)))
        loser.deleted = base
        loser.conflictOf = winner.id
        let now = base.addingTimeInterval(3600)

        let first = ConflictSettlement.swapped(winner: winner, loser: loser, now: now)
        #expect(first.keep.id == winner.id)
        #expect(first.keep.body == "맥에서 한 시간 다듬은 글")
        #expect(first.keep.updated == now.truncatingSubsecond)
        #expect(first.keep.deleted == nil)
        #expect(first.keep.conflictOf == nil)
        let pushed = try! #require(first.retired.first)
        #expect(pushed.id == loser.id, "휴지통의 같은 자리에 앉는다 — 파일이 늘지 않는다")
        #expect(pushed.body == "폰의 오타 수정")
        #expect(pushed.deleted == now.truncatingSubsecond)
        #expect(pushed.conflictOf == winner.id)

        // 한 번 더 바꾸면 원래대로 — 어느 쪽도 없어지지 않았다.
        let second = ConflictSettlement.swapped(winner: first.keep, loser: pushed, now: now.addingTimeInterval(60))
        #expect(second.keep.body == "폰의 오타 수정")
        #expect(second.retired.first?.body == "맥에서 한 시간 다듬은 글")
    }

    @Test("이 판으로: 날짜·자리·색·체크까지 글과 함께 오고, 그 자리의 상태(고정 해제·도로 꺼냄)는 자리를 따른다")
    func swappedCarriesContentNotPlaceState() {
        var winner = memo("폰", updatedBy: 60)
        winner.kept = base
        var loser = memo("맥\n- [x] 서류", updatedBy: 10, id: ULID(timestamp: base.addingTimeInterval(1)))
        loser.due = CalendarDate(year: 2026, month: 10, day: 1)
        loser.place = "강남역"
        loser.color = .blue
        loser.conflictOf = winner.id
        loser.deleted = base

        let outcome = ConflictSettlement.swapped(winner: winner, loser: loser, now: base)
        #expect(outcome.keep.due == loser.due)
        #expect(outcome.keep.place == "강남역")
        #expect(outcome.keep.color == .blue)
        #expect(outcome.keep.kept == base, "도로 꺼낸 뜻은 글이 아니라 그 자리의 것")
        #expect(outcome.retired.first?.kept == nil)
    }

    // MARK: 파일

    @Test("이 판으로: 파일 둘이 글을 맞바꾸고, 한 번 더 하면 원래대로다")
    func adoptConflictSwapsFiles() async throws {
        let paths = try makePaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)
        let winner = memo("폰", updatedBy: 60)
        try await vault.save(winner)
        let loser = ConflictSettlement.settle(current: memo("맥", updatedBy: 10, id: winner.id), others: [winner], now: base).retired[0]
        try await vault.retire(loser)

        try await vault.adoptConflict(loser.id, now: base.addingTimeInterval(10))

        #expect(try await vault.load(winner.id).body == "맥")
        let trashed = try await vault.trashedMemos()
        #expect(trashed.map(\.body) == ["폰"])
        #expect(trashed.first?.id == loser.id)
        #expect(trashed.first?.conflictOf == winner.id)
        #expect(try await vault.loadAll().count == 1, "자리의 파일은 하나뿐이다")

        try await vault.adoptConflict(loser.id, now: base.addingTimeInterval(20))
        #expect(try await vault.load(winner.id).body == "폰")
        #expect(try await vault.trashedMemos().map(\.body) == ["맥"])
    }

    @Test("둘 다 남기기: 되돌리면 다른 판 표시를 떼고 제 메모로 선다 — 자리의 메모도 그대로")
    func restoreKeepsBoth() async throws {
        let paths = try makePaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)
        let winner = memo("폰", updatedBy: 60)
        try await vault.save(winner)
        let loser = ConflictSettlement.settle(current: memo("맥", updatedBy: 10, id: winner.id), others: [winner], now: base).retired[0]
        try await vault.retire(loser)

        let restored = try await vault.restore(loser.id).memo

        #expect(restored.conflictOf == nil)
        #expect(restored.deleted == nil)
        #expect(Set(try await vault.loadAll().map(\.memo.body)) == ["폰", "맥"])
        #expect(try await vault.trashedMemos().isEmpty)
    }

    @Test("자리의 메모가 그 사이 지워졌으면 「이 판으로」는 되돌리기와 같다")
    func adoptWithoutWinnerRestores() async throws {
        let paths = try makePaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)
        var loser = memo("맥", updatedBy: 10)
        loser.deleted = base
        loser.conflictOf = ULID()
        try await vault.retire(loser)

        let back = try await vault.adoptConflict(loser.id, now: base).memo

        #expect(back.id == loser.id)
        #expect(back.conflictOf == nil)
        #expect(try await vault.loadAll().map(\.memo.body) == ["맥"])
    }
}

/// 화면이 보는 것 — 저장소가 다른 판을 지운 메모와 따로 세고, 두 손이 둘 다 통한다.
@MainActor
@Suite("충돌 복구 — 저장소와 화면")
struct ConflictRecoveryStoreTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-conflict-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoStore(paths: paths), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    /// 다른 기기의 판이 휴지통에 앉은 상태를 만든다 — iCloud 의 판본은 시험에서 못 만드니
    /// 정리가 끝난 뒤의 모습(`retire`)을 그대로 놓는다.
    private func plantConflict(_ store: MemoStore, paths: AppPaths, winner: Memo, loserBody: String) async throws -> Memo {
        var other = winner
        other.body = loserBody
        other.updated = winner.updated.addingTimeInterval(-60)
        let loser = ConflictSettlement.settle(current: other, others: [winner]).retired[0]
        try await MemoVault(paths: paths).retire(loser)
        await store.reconcile()
        return loser
    }

    @Test("다른 판은 지운 메모와 따로 센다 — 자리의 메모가 살아 있는 동안만")
    func conflictsAreCountedApartFromDeleted() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let winner = try await store.create(body: "폰")
        let plain = try await store.create(body: "그냥 지운 것")
        try await store.delete(plain.id)
        let loser = try await plantConflict(store, paths: paths, winner: winner, loserBody: "맥")

        #expect(store.trash.map(\.id).sorted() == [plain.id, loser.id].sorted())
        #expect(store.conflicts.map(\.id) == [loser.id])

        // 자리의 메모를 지우면 그것은 그냥 지운 메모다.
        try await store.delete(winner.id)
        #expect(store.conflicts.isEmpty)
    }

    @Test("이 판으로 — 목록의 메모가 그 글을 받고 휴지통에는 밀려난 글이 다른 판으로 남는다")
    func adoptThroughStore() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let winner = try await store.create(body: "폰")
        let loser = try await plantConflict(store, paths: paths, winner: winner, loserBody: "맥")

        try await store.adoptConflict(loser.id)

        #expect(store.memo(winner.id)?.body == "맥")
        #expect(store.conflicts.map(\.body) == ["폰"])
        #expect(store.trouble == nil)
    }

    @Test("둘 다 남기기 — 되돌리면 목록에 둘이 서고 휴지통의 다른 판은 없다")
    func keepBothThroughStore() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let winner = try await store.create(body: "폰")
        let loser = try await plantConflict(store, paths: paths, winner: winner, loserBody: "맥")

        try await store.restore(loser.id)

        #expect(Set(store.active.map(\.body)) == ["폰", "맥"])
        #expect(store.conflicts.isEmpty)
        #expect(store.memo(loser.id)?.conflictOf == nil)
    }

    @Test("진 판만 물고 있는 사진은 정리가 지나가도 그대로다 — 이 판으로 바꿨는데 사진만 없으면 안 된다")
    func attachmentsOfTheLoserSurvive() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let path = try store.attachments.save(Data("사진".utf8), fileExtension: "png")
        let url = try #require(store.attachments.url(for: path))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-400 * 24 * 60 * 60)], ofItemAtPath: url.path(percentEncoded: false)
        )
        let winner = try await store.create(body: "폰 — 사진 뺌")
        let loser = try await plantConflict(store, paths: paths, winner: winner, loserBody: "맥\n\n![](\(path))")

        await store.tidy()
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))

        try await store.adoptConflict(loser.id)
        await store.tidy()
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        #expect(store.memo(winner.id)?.photoCount == 1)
    }
}
