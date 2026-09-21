import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 적힌 시각이 오면 종이가 나오는가 (`DueClock`).
///
/// 설계문서 §7.2 는 "날짜가 붙은 것은 달력이 맡는다 — **그 날이 오면 달력이
/// 꺼내 준다**" 고 적어 두고, 꺼내 주는 쪽을 만들지 않았다. `at` 이 적힌 메모가
/// 그 시각에 하는 일이 아무것도 없었고, 그러면 "적었는데 그냥 지나갔다" 가
/// 남는다 — 그것이 한 번 반복되면 사용자는 중요한 것을 이 앱에 안 맡긴다.
///
/// 시각을 다루는 것은 **화면으로 확인할 수 없다.** 한 시간 뒤에야 틀린 것이
/// 드러나고, 그때는 이미 놓친 뒤다. 그래서 시계를 손으로 돌려 여기서 못 박는다.
@MainActor
@Suite("시각 시계 — 그 날이 오면 꺼내 준다")
struct DueClockTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-due-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    private func seoul() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func at(_ calendar: Calendar, day: Int = 29, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 8, day: day, hour: hour, minute: minute
        ))!
    }

    @Test("시각이 지나면 그 메모를 꺼낸다")
    func firesWhenTheHourArrives() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        let appointment = try await store.create(body: "치과", at: at(calendar, hour: 15))

        var now = at(calendar, hour: 14)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()
        #expect(risen.isEmpty)

        now = at(calendar, hour: 15)
        clock.fire()

        #expect(risen == [appointment.id])
    }

    @Test("같은 것을 두 번 꺼내지 않는다")
    func announcesOnlyOnce() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        _ = try await store.create(body: "치과", at: at(calendar, hour: 15))

        var now = at(calendar, hour: 14)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()

        now = at(calendar, hour: 16)
        clock.fire()
        clock.fire()

        #expect(risen.count == 1)
    }

    @Test("자다 깨어 여러 개가 지나 있으면 시간 순으로 전부 꺼낸다")
    func firesEverythingThatPassed() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        let later = try await store.create(body: "저녁 약속", at: at(calendar, hour: 19))
        let earlier = try await store.create(body: "팀 회의", at: at(calendar, hour: 17))

        var now = at(calendar, hour: 16)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()

        // 뚜껑을 닫아 둔 사이 둘 다 지났다.
        now = at(calendar, hour: 20)
        clock.fire()

        #expect(risen == [earlier.id, later.id])
    }

    @Test("날짜만 있는 메모는 울리지 않는다 — 시각을 적은 적이 없다")
    func ignoresDateOnlyMemos() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        _ = try await store.create(body: "전기요금", due: CalendarDate(year: 2026, month: 8, day: 29))

        var now = at(calendar, hour: 1)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()

        now = at(calendar, hour: 23)
        clock.fire()

        #expect(risen.isEmpty)
    }

    @Test("앱을 켜면 오늘 이미 지나간 것을 꺼낸다 — 가장 가까운 것부터 세 장까지")
    func catchesUpOnLaunch() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        var made: [ULID] = []
        for hour in [9, 11, 13, 15] {
            made.append(try await store.create(body: "일정 \(hour)", at: at(calendar, hour: hour)).id)
        }

        let now = at(calendar, hour: 18)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()

        // 넷이 지났지만 셋만. 하루치가 통째로 바탕화면을 덮으면 그건 알림이
        // 아니라 치울 거리다. 그리고 가장 가까운 것이 마지막에 나와 맨 앞에 선다.
        #expect(risen == [made[1], made[2], made[3]])
    }

    @Test("켤 때 지나 있던 것은 나중에 다시 울리지 않는다")
    func caughtUpItemsDoNotRing() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        _ = try await store.create(body: "아침 회의", at: at(calendar, hour: 9))

        var now = at(calendar, hour: 18)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()
        #expect(risen.count == 1)

        now = at(calendar, hour: 19)
        clock.fire()

        #expect(risen.count == 1)
    }

    @Test("어제 것은 켤 때 꺼내지 않는다 — 지난 일정을 언제까지 세워 둘지는 시계가 정할 일이 아니다")
    func ignoresYesterday() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        _ = try await store.create(body: "어제 회의", at: at(calendar, day: 28, hour: 9))

        let now = at(calendar, day: 29, hour: 10)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()

        #expect(risen.isEmpty)
    }

    @Test("하루가 바뀌면 다시 센다")
    func resetsOnNewDay() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        let daily = try await store.create(body: "치과", at: at(calendar, hour: 15))

        var now = at(calendar, hour: 16)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()
        #expect(risen == [daily.id])

        // 메모를 다음 날로 미뤘다고 치자 — 자정을 넘기면 다시 울릴 수 있어야 한다.
        now = at(calendar, day: 30, hour: 16)
        clock.dayChanged()
        clock.fire()

        #expect(risen == [daily.id, daily.id])
    }

    @Test("치워 둔 것·다 체크한 목록은 시각이 와도 꺼내지 않는다 — 배너가 안 울리는 것은 종이도 안 나온다")
    func skipsWhatTheBannerSkips() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        _ = try await store.create(body: "- [x] 우유\n- [x] 계란", at: at(calendar, hour: 15))
        let open = try await store.create(body: "- [ ] 우유", at: at(calendar, hour: 15))
        // 다른 기기가 치워 둔 것 — 파일에 `tidied:` 가 적혀 온다.
        let tidiedAway = try await store.create(body: "치운 약속", at: at(calendar, hour: 15))
        var onDisk = try await MemoVault(paths: paths).load(tidiedAway.id)
        onDisk.tidied = at(calendar, hour: 1)
        _ = try await MemoVault(paths: paths).save(onDisk)
        await store.reconcile()

        var now = at(calendar, hour: 14)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()

        now = at(calendar, hour: 15)
        clock.fire()

        #expect(risen == [open.id])
        #expect(Recall.reservations(store.memos, now: at(calendar, hour: 14)).map(\.id) == [open.id])
    }

    @Test("같은 날 다시 볼 시각을 미루면 새 시각에 다시 꺼낸다 — 배너와 종이가 같은 답")
    func postponedSameDayRingsAgain() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let calendar = seoul()
        let memo = try await store.create(body: "회의 자료", at: at(calendar, hour: 14))

        var now = at(calendar, hour: 14, minute: 1)
        var risen: [ULID] = []
        let clock = DueClock(store: store, now: { now }, calendar: calendar)
        clock.onDue = { risen.append($0) }
        clock.start()
        #expect(risen == [memo.id])

        // 「한 시간 뒤에 다시」 — 같은 날, 같은 메모, 다른 시각.
        _ = try await store.update(memo.id, surface: .some(at(calendar, hour: 15)))
        now = at(calendar, hour: 15, minute: 1)
        clock.fire()

        #expect(risen == [memo.id, memo.id])
    }
}
