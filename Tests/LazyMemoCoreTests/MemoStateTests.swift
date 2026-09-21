import Foundation
import Testing
@testable import LazyMemoCore

/// 처리 상태의 계약 (인계서 §4 · 묶음 4 `#memo-state-contract`).
///
/// | 상태 | 뜻 | 파일 | 알림·「지금」 | 목록 |
/// |---|---|---|---|---|
/// | `done` | 사람이 끝냈다 | `done:` | 빠진다 | 남았다가 사흘 뒤 물러난다 |
/// | `archived` | 당장 안 볼 기록 | `archived:` | 빠진다 | 빠진다 — 검색은 된다 |
/// | 「봤어요」 | 이 등장·이 기기의 표시 억제 | 파일 아님 (`NowSeen`) | 그 등장만 | 그대로 |
/// | `kept` | 도로 꺼냈다 | `kept:` | 그대로 | 규칙이 못 치운다 |
///
/// 날짜 경과는 완료가 아니고, 다 체크한 목록도 사람의 완료가 아니다 — 다만 알림은 걸지 않는다(끝난 일의 알림은 방해다).
@Suite("처리 상태 — 완료·보관·회차")
struct MemoStateTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test("`done:`·`archived:` 는 파일을 왕복하고, 없으면 줄도 없다 — 옛 판은 모르는 키로 되쓴다")
    func fieldsRoundTrip() throws {
        let stamp = Date(timeIntervalSince1970: 1_777_000_000)
        let memo = Memo(body: "견적 보내기", done: stamp, archived: stamp.addingTimeInterval(60))
        let encoded = MemoFile.encode(memo)
        #expect(encoded.contains("done: "))
        #expect(encoded.contains("archived: "))
        let decoded = try MemoFile.decode(encoded)
        #expect(decoded.done?.timeIntervalSince1970 == stamp.truncatingSubsecond.timeIntervalSince1970)
        #expect(decoded.archived?.timeIntervalSince1970 == stamp.addingTimeInterval(60).truncatingSubsecond.timeIntervalSince1970)

        let plain = MemoFile.encode(Memo(body: "그냥 글"))
        #expect(!plain.contains("done:") && !plain.contains("archived:"))

        // 구형 파일 — 모르는 키·사진·날짜가 그대로 돌아온다.
        let legacy = """
            ---
            id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
            created: 2026-08-28T16:29:50+09:00
            due: 2026-09-01
            mood: 초조함
            ---
            치과 예약
            ![](attachments/a.png)
            """
        let old = try MemoFile.decode(legacy)
        #expect(old.done == nil && old.archived == nil && old.kept == nil)
        let again = try MemoFile.decode(MemoFile.encode(old))
        #expect(again.preserved.map(\.key) == ["mood"])
        #expect(again.due == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(again.body.contains("attachments/a.png"))
    }

    @Test("끝낸 것·보관한 것은 예약·「지금」·자리 알림에서 빠지고, 다 체크한 목록은 여전히 알림만 없다")
    func doneAndArchivedLeaveRecall() {
        let now = at(9, 22, 12)
        let open = Memo(at: at(9, 22, 15), body: "회의")
        let done = Memo(at: at(9, 22, 15), body: "끝낸 회의", done: now)
        let archived = Memo(at: at(9, 22, 15), body: "넣어 둔 회의", archived: now)
        let all = [open, done, archived]
        #expect(all.map(Recall.eligible) == [true, false, false])
        #expect(Recall.reservations(all, now: now).map(\.title) == ["회의"])
        #expect(Recall.nowCards(all, now: now, calendar: calendar).map(\.memo.title) == ["회의"])
    }

    @Test("완료는 사람의 뜻이다 — 날짜가 지나도, 다 체크해도 `done` 이 아니고, 끝낼 것이 있는 메모만 「완료」를 든다")
    func doneIsExplicit() {
        let passed = Memo(at: at(9, 20, 15), body: "지난 회의")
        let checked = Memo(body: "- [x] 우유")
        #expect(passed.done == nil && checked.done == nil)
        #expect(passed.isActionable, "시각이 적힌 것은 끝낼 수 있다")
        #expect(!checked.isActionable, "다 체크한 목록은 더 끝낼 것이 없다")
        #expect(Memo(body: "- [ ] 우유").isActionable)
        #expect(Memo(surface: at(9, 25, 9), body: "읽을 글").isActionable)
        #expect(!Memo(body: "비밀번호 힌트").isActionable, "그냥 글에 완료 단추는 없다")
        #expect(!Memo(at: at(9, 20, 15), body: "회의", done: at(9, 20, 16)).isActionable)
    }

    @Test("끝낸 것은 사흘 뒤 물러난다 — 끝낸 순간 없어지면 사고다. 보관한 것은 규칙이 건드리지 않는다")
    func doneRetreatsAfterGrace() {
        let done = Memo(created: at(9, 1), updated: at(9, 22), due: CalendarDate(year: 2026, month: 9, day: 10), body: "치과", done: at(9, 22))
        #expect(Tidy.reason(for: done, now: at(9, 23), calendar: calendar) == nil)
        #expect(Tidy.reason(for: done, now: at(9, 25, 12), calendar: calendar) == .finished)
        let archived = Memo(created: at(9, 1), updated: at(9, 1), due: CalendarDate(year: 2026, month: 9, day: 10), body: "치과", archived: at(9, 22))
        #expect(Tidy.reason(for: archived, now: at(12, 31), calendar: calendar) == nil)
    }

    @Test("R06 · 되풀이하는 일의 완료는 이 회차까지다 — 다음 회차로 걸어가면 `done` 과 체크가 비고 알림이 다시 선다")
    func recurringDoneIsPerRound() {
        let memo = Memo(
            created: at(9, 1), updated: at(9, 15),
            at: at(9, 15, 8), every: Recurrence("매주"), body: "분리수거\n- [x] 플라스틱\n- [x] 종이", done: at(9, 15, 9)
        )
        #expect(!Recall.eligible(memo), "이번 회차는 끝났다")
        // 22일 새벽 — 15일 회차는 지났고 22일 8시 회차가 다음이다.
        let rolled = try? #require(Tidy.rolled(memo, now: at(9, 22, 7), calendar: calendar))
        #expect(rolled?.at == at(9, 22, 8))
        #expect(rolled?.done == nil)
        #expect(rolled?.body == "분리수거\n- [ ] 플라스틱\n- [ ] 종이")
        #expect(rolled.map(Recall.eligible) == true, "다음 회차는 다시 산 것이다")
        #expect(Recall.reservations([rolled!], now: at(9, 22, 7)).map(\.date) == [at(9, 22, 8)])
    }

    @Test("체크 비우기는 칸만 건드린다")
    func uncheckingTouchesOnlyBoxes() {
        #expect(Checklist.uncheckingAll(in: "- [x] 하나\n- [X] 둘\n- [ ] 셋\n그냥 [x] 글") == "- [ ] 하나\n- [ ] 둘\n- [ ] 셋\n그냥 [x] 글")
        #expect(Checklist.uncheckingAll(in: "칸 없음") == "칸 없음")
    }

    // MARK: 놓친 것·오늘·나중에

    @Test("요약 — 놓친 것은 지난 날의 다시 보기·시각과 마감 지난 칸 남은 목록, 「봤어요」한 등장은 빠지고, 미래 다시 보기의 지난 일정은 놓친 것이 아니다")
    func summaryCounts() {
        let now = at(9, 22, 12)
        let missedRevisit = Memo(updated: at(9, 19), surface: at(9, 21, 9), body: "읽을 글")
        let missedTimed = Memo(updated: at(9, 19), at: at(9, 20, 15), body: "지난 회의")
        let missedList = Memo(updated: at(9, 19), due: CalendarDate(year: 2026, month: 9, day: 20), body: "- [ ] 서류")
        let pastPlain = Memo(updated: at(9, 19), due: CalendarDate(year: 2026, month: 9, day: 20), body: "지난 날짜만")
        let seenRevisit = Memo(updated: at(9, 19), surface: at(9, 21, 10), body: "봤어요 한 것")
        let futureRevisit = Memo(updated: at(9, 19), at: at(9, 20, 15), surface: at(9, 25, 9), body: "25일에 다시")
        let today = Memo(updated: at(9, 19), at: at(9, 22, 15), body: "오늘 회의")
        let later = Memo(updated: at(9, 19), due: CalendarDate(year: 2026, month: 9, day: 30), body: "나중")
        let done = Memo(updated: at(9, 19), at: at(9, 20, 15), body: "끝낸 회의", done: at(9, 20, 16))
        let all = [missedRevisit, missedTimed, missedList, pastPlain, seenRevisit, futureRevisit, today, later, done]

        let summary = Recall.summary(all, now: now, calendar: calendar, seen: [seenRevisit.id: at(9, 21, 10)])
        #expect(summary.missed.map(\.title) == ["읽을 글", "지난 회의", "서류"], "방금 지난 것이 먼저(마감만 있는 목록은 그 날의 시작); 날짜만 있는 그냥 글은 놓친 것이 아니다")
        #expect(summary.today.map(\.title) == ["오늘 회의"])
        #expect(summary.later.map(\.title) == ["25일에 다시", "나중"])
    }

    @Test("요약은 세 장으로 줄이기 전의 오늘을 센다")
    func summaryTodayIsNotCapped() {
        let now = at(9, 22, 12)
        let memos = (13...17).map { Memo(at: at(9, 22, $0), body: "일정 \($0)") }
        #expect(Recall.nowCards(memos, now: now, calendar: calendar).count == 3)
        #expect(Recall.summary(memos, now: now, calendar: calendar).today.count == 5)
    }
}

/// 서비스가 상태를 파일에 적고 되돌리는가 — 두 기기가 같은 답을 내려면 파일이 정답이어야 한다.
@MainActor
@Suite("처리 상태 — 파일과 목록")
struct MemoStateSweepTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-state-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    @Test("완료 → 파일에 적히고 알림에서 빠지고 되돌릴 수 있다; 사흘 뒤 물러나고 되돌리면 도로 나온다")
    func doneRoundTrip() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "견적 보내기", at: now.addingTimeInterval(days(1)))
        #expect(Recall.reservations(store.memos, now: now).count == 1)

        try await store.markDone(memo.id)
        let onDisk = try await MemoVault(paths: paths).load(memo.id)
        #expect(onDisk.done != nil)
        #expect(Recall.reservations(store.memos, now: now).isEmpty)
        #expect(store.active.map(\.id) == [memo.id], "끝낸 것은 바로 사라지지 않는다")

        await store.tidy(now: now.addingTimeInterval(days(4)))
        #expect(store.active.isEmpty)
        try await store.markUndone(memo.id)
        #expect(store.active.map(\.id) == [memo.id])
        #expect(store.memo(memo.id)?.done == nil)
        #expect(Recall.reservations(store.memos, now: now).count == 1)
    }

    @Test("보관 → 목록·알림에서 빠지되 검색은 되고, 꺼내면 규칙이 다시 치우지 않는다")
    func archiveRoundTrip() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "읽을 글 — 게으른 사람", due: CalendarDate(now.addingTimeInterval(-days(10))))

        try await store.archive(memo.id)
        #expect(store.active.isEmpty)
        #expect(store.archivedMemos.map(\.id) == [memo.id])
        #expect(store.tidiedMemos.isEmpty, "보관은 치운 것과 섞이지 않는다")
        #expect(await store.search("게으른").map(\.id) == [memo.id])
        await store.tidy(now: now.addingTimeInterval(days(30)))
        #expect(store.memo(memo.id)?.tidied == nil, "보관한 것은 규칙이 건드리지 않는다")

        try await store.unarchive(memo.id)
        #expect(store.active.map(\.id) == [memo.id])
        await store.tidy(now: now.addingTimeInterval(days(31)))
        #expect(store.active.map(\.id) == [memo.id], "꺼낸 뜻은 규칙이 이기지 못한다")
    }

    @Test("때를 옮기면 완료는 풀린다 — 새 회차다")
    func reschedulingClearsDone() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "치과", due: CalendarDate(now))
        try await store.markDone(memo.id)
        _ = try await store.update(memo.id, due: .some(CalendarDate(now.addingTimeInterval(days(7)))))
        #expect(store.memo(memo.id)?.done == nil)
    }

    @Test("되풀이하는 일을 끝내고 회차가 지나면 정리가 다음 회차로 옮기며 완료를 푼다")
    func recurringRollsPastDone() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let now = Date()
        let memo = try await store.create(body: "분리수거\n- [x] 플라스틱", at: now.addingTimeInterval(-days(1)), every: Recurrence("매주"))
        try await store.markDone(memo.id)
        await store.tidy(now: now)
        let rolled = try #require(store.memo(memo.id))
        #expect(rolled.done == nil)
        #expect(rolled.body == "분리수거\n- [ ] 플라스틱")
        #expect(rolled.at! > now)
    }
}
