import Foundation
import Testing
@testable import LazyMemoCore

/// 자동 정리가 **사람의 뜻을 덮지 못하게** (인계서 묶음 1 · `#tidy-recall-safety`).
///
/// 「지난 일정은 물러난다」는 철학 3 의 규칙이지, 「날짜가 지나면 끝난 것」이라는 뜻이
/// 아니다. 사람이 남긴 세 가지 뜻은 규칙보다 앞선다 — 미래에 다시 보겠다는 시각,
/// 아직 체크하지 않은 칸, 치워 둔 것을 도로 꺼낸 손. 이 셋을 규칙이 이기면 앱은
/// 「적었는데 없어졌다」가 되고, 그 한 번으로 사람은 중요한 것을 여기 맡기지 않는다.
///
/// 회귀 번호(R01…)는 `docs/PRODUCT_IMPLEMENTATION_HANDOFF.md` §5 묶음 1 의 표와 같다.
@Suite("스스로 물러나기 — 사람의 뜻이 이긴다")
struct TidySafetyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: 규칙

    @Test("R01 · 미래에 다시 보기로 한 지난 일정은 물러나지 않는다 — 예약이 그대로 걸려 있어야 한다")
    func futureRevisitOutranksPastSchedule() {
        // 9월 20일 15시 약속, 25일 9시에 다시 보기. 지금은 22일 정오.
        let memo = Memo(
            created: at(9, 19), updated: at(9, 19),
            at: at(9, 20, 15), surface: at(9, 25, 9), body: "견적 보내기"
        )
        let now = at(9, 22, 12)

        #expect(Tidy.reason(for: memo, now: now, calendar: calendar) == nil)
        #expect(Recall.reservations([memo], now: now).map(\.date) == [at(9, 25, 9)])
    }

    @Test("R01 · 다시 볼 날이 지나면 그 날을 기준으로 물러난다 — 일정 날이 아니라")
    func pastRevisitRetreatsFromItsOwnDay() {
        // 20일 약속, 21일 9시에 다시 보기. 22일 온종일 남아 있고 23일 자정에 물러난다.
        let memo = Memo(
            created: at(9, 19), updated: at(9, 19),
            at: at(9, 20, 15), surface: at(9, 21, 9), body: "견적 보내기"
        )

        #expect(Tidy.reason(for: memo, now: at(9, 22, 23), calendar: calendar) == nil)
        #expect(Tidy.reason(for: memo, now: at(9, 23, 0), calendar: calendar) == .past)
    }

    @Test("다시 볼 시각만 있는 메모는 그 날이 지나도 물러나지 않는다 — 날짜 없는 글은 사람이 지울 때까지 남는다")
    func revisitOnlyMemoIsStillAPlainMemo() {
        let memo = Memo(created: at(9, 19), updated: at(9, 19), surface: at(9, 21, 9), body: "읽을 글")
        #expect(Tidy.reason(for: memo, now: at(10, 21, 9), calendar: calendar) == nil)
    }

    @Test("R02 · 칸이 남은 목록은 마감이 지나도 물러나지 않는다 — 날짜 경과는 완료가 아니다")
    func unfinishedChecklistOutranksPastDue() {
        let memo = Memo(
            created: at(9, 19), updated: at(9, 19),
            due: CalendarDate(year: 2026, month: 9, day: 20), body: "- [ ] 서류 제출"
        )

        #expect(Tidy.reason(for: memo, now: at(9, 22, 12), calendar: calendar) == nil)
        #expect(Tidy.reason(for: memo, now: at(10, 22, 12), calendar: calendar) == nil)
        // 다 체크하면 그때부터 규칙이 센다 — 손댄 지 사흘 뒤. 마감이 지난 지 오래라고 그 밤에
        // 치우면, 밀린 일을 끝낸 순간 없어지는 것이라 사고로 보인다.
        var done = memo
        done.body = "- [x] 서류 제출"
        done.updated = at(9, 22, 12)
        #expect(Tidy.reason(for: done, now: at(9, 23, 0), calendar: calendar) == nil)
        #expect(Tidy.reason(for: done, now: at(9, 25, 12), calendar: calendar) == .finished)
    }

    @Test("R03 · 도로 꺼낸 것은 규칙이 다시 치우지 않는다 — 사람의 뜻이 규칙을 이긴다")
    func keptOutranksEveryReason() {
        let past = Memo(
            created: at(9, 1), updated: at(9, 22),
            due: CalendarDate(year: 2026, month: 9, day: 10), body: "치과", kept: at(9, 22)
        )
        let finished = Memo(
            created: at(9, 1), updated: at(9, 1), body: "- [x] 우유", kept: at(9, 22)
        )

        for later in [at(9, 22, 13), at(9, 23, 0), at(10, 22), at(12, 31)] {
            #expect(Tidy.reason(for: past, now: later, calendar: calendar) == nil)
            #expect(Tidy.reason(for: finished, now: later, calendar: calendar) == nil)
        }
    }

    @Test("R05 · 지운 것·치워 둔 것·다 체크한 목록은 예약·지금·자리 알림이 한 규칙으로 뺀다")
    func oneEligibilityRuleEverywhere() {
        let geo = Coordinate(latitude: 37.5, longitude: 127.0)!
        var deleted = Memo(updated: at(9, 22, 9), at: at(9, 23, 9), geo: geo, body: "지운 것"); deleted.deleted = at(9, 22)
        var tidied = Memo(updated: at(9, 22, 9), at: at(9, 23, 9), geo: geo, body: "치운 것"); tidied.tidied = at(9, 22)
        let finished = Memo(updated: at(9, 22, 9), at: at(9, 23, 9), geo: geo, body: "- [x] 우유")
        let open = Memo(updated: at(9, 22, 11), at: at(9, 23, 9), geo: geo, body: "- [ ] 우유")
        let kept = Memo(updated: at(9, 22, 10), at: at(9, 23, 9), geo: geo, body: "꺼낸 것", kept: at(9, 22))
        let all = [deleted, tidied, finished, open, kept]
        let now = at(9, 22, 12)

        #expect(all.map(Recall.eligible) == [false, false, false, true, true])
        // 같은 시각의 예약은 id 순이라 차례는 묻지 않는다 — 누가 남는지만.
        #expect(Recall.reservations(all, now: now).map(\.title).sorted() == ["꺼낸 것", "우유"])
        #expect(Recall.nowCards(all, now: at(9, 23, 8), calendar: calendar).map(\.memo.title) == ["우유", "꺼낸 것"])
        #expect(GeofenceRule.select(all, now: now, calendar: calendar).watched.map(\.title) == ["우유", "꺼낸 것"])
    }

    @Test("`kept:` 는 파일을 왕복해도 남는다")
    func keptSurvivesRoundTrip() throws {
        let stamped = Date(timeIntervalSince1970: 1_777_000_000)
        let memo = Memo(body: "치과", kept: stamped)

        let encoded = MemoFile.encode(memo)
        #expect(encoded.contains("kept: "))
        let decoded = try MemoFile.decode(encoded)
        #expect(decoded.kept?.timeIntervalSince1970 == stamped.truncatingSubsecond.timeIntervalSince1970)

        // 없으면 줄도 없다.
        #expect(!MemoFile.encode(Memo(body: "치과")).contains("kept:"))
    }
}

/// 규칙이 파일과 목록에 닿았을 때도 같은 답인가 — 복원 → 정리 → 예약의 왕복.
@MainActor
@Suite("스스로 물러나기 — 복원과 예약의 왕복")
struct TidySafetySweepTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-tidy-safety-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    private func days(_ count: Double) -> TimeInterval { count * 24 * 60 * 60 }

    @Test("R01 · 정리를 돌려도 미래 다시 보기의 예약은 살아 있다")
    func sweepKeepsFutureRevisitReserved() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(
            body: "견적 보내기", at: now.addingTimeInterval(-days(2)), surface: now.addingTimeInterval(days(3))
        )

        await store.tidy(now: now)

        #expect(store.active.map(\.id) == [memo.id])
        #expect(Recall.reservations(store.memos, now: now).map(\.id) == [memo.id])
    }

    @Test("R02 · 마감이 지난 미완료 목록은 정리 뒤에도 목록에 있다")
    func sweepKeepsUnfinishedChecklist() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(
            body: "- [ ] 서류 제출", due: CalendarDate(now.addingTimeInterval(-days(10)))
        )

        await store.tidy(now: now)

        #expect(store.active.map(\.id) == [memo.id])
    }

    @Test("R03 · 치워진 지난 일정을 도로 꺼내면 같은 날에도, 다음 날에도, 한 달 뒤에도 그대로 있다")
    func restoredPastScheduleStaysRestored() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "치과", due: CalendarDate(now.addingTimeInterval(-days(10))))

        await store.tidy(now: now)
        #expect(store.active.isEmpty)

        await store.untidy(memo.id)
        #expect(store.active.map(\.id) == [memo.id])

        for later in [days(0.01), days(1), days(30)] {
            await store.tidy(now: now.addingTimeInterval(later))
            #expect(store.active.map(\.id) == [memo.id], "\(later / 86_400)일 뒤")
        }
        // 파일에도 그 뜻이 적혀 있다 — 다른 기기의 정리도 같은 답을 낸다.
        let onDisk = try await MemoVault(paths: paths).load(memo.id)
        #expect(onDisk.kept != nil)
        #expect(onDisk.tidied == nil)
    }

    @Test("R03 · 「도로 꺼내기」로 한꺼번에 꺼낸 것도 마찬가지다")
    func restoreAllStaysRestored() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        _ = try await store.create(body: "치과", due: CalendarDate(now.addingTimeInterval(-days(10))))
        _ = try await store.create(body: "장보기\n- [x] 우유")

        await store.tidy(now: now.addingTimeInterval(days(4)))
        #expect(store.active.isEmpty)

        await store.untidyAll()
        await store.tidy(now: now.addingTimeInterval(days(40)))

        #expect(store.active.count == 2)
    }

    @Test("이 필드를 모르는 판이 도로 치웠어도 다음 정리가 다시 세운다 — 파일의 뜻이 기기의 규칙보다 앞선다")
    func sweepHealsKeptButTidied() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "치과", due: CalendarDate(now.addingTimeInterval(-days(10))))
        await store.tidy(now: now)
        await store.untidy(memo.id)

        // 옛 판의 앱이 `kept` 를 모른 채 `tidied:` 를 도로 적었다고 치자.
        let vault = MemoVault(paths: paths)
        var stale = try await vault.load(memo.id)
        stale.tidied = now
        _ = try await vault.save(stale)
        await store.reconcile()
        #expect(store.active.isEmpty)

        await store.tidy(now: now.addingTimeInterval(days(1)))
        await store.reconcile()

        #expect(store.active.map(\.id) == [memo.id])
    }

    @Test("날을 옮기면 새 회차다 — 그 날이 지나면 다시 물러날 수 있다")
    func movingTheDateStartsOver() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "치과", due: CalendarDate(now.addingTimeInterval(-days(10))))

        await store.tidy(now: now)
        await store.untidy(memo.id)
        // 다음 주로 옮겼다. 그 날이 지나고 하루 더 지나면 규칙이 다시 센다.
        _ = try await store.update(memo.id, due: .some(CalendarDate(now.addingTimeInterval(days(7)))))
        #expect(store.memo(memo.id)?.kept == nil)

        await store.tidy(now: now.addingTimeInterval(days(7)))
        #expect(store.active.map(\.id) == [memo.id])
        await store.tidy(now: now.addingTimeInterval(days(10)))
        #expect(store.active.isEmpty)
    }
}
