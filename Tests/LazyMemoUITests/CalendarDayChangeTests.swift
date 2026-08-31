import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 자정을 넘긴 달력 (`DayClock` → `CalendarModel.dayChanged`).
///
/// `today` 는 오랫동안 `let` 이었다. 창을 만들 때 한 번 잡고 앱이 꺼질 때까지
/// 그대로였는데, 이 앱은 바탕화면에 상주하므로 며칠씩 안 꺼진다. 그러면
/// **동시에 다섯 가지가 틀린다** — 손그림 동그라미가 어제 칸에 남고,
/// 「오늘」 버튼이 어제로 가고, 「오늘 · 8월 29일」이 거짓말이 되고,
/// 마름의 기준점이 하루 어긋나고, 무엇보다 **「미루기」가 어제를 기준으로
/// 세어 오늘로 미룬다.** 마지막 것이 달력에서 가장 자주 쓰는 동사다.
@MainActor
@Suite("달력 — 자정을 넘긴다")
struct CalendarDayChangeTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-dayflip-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    private func makeModel(_ store: MemoStore, on day: Int) -> CalendarModel {
        let calendar = seoul()
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 10))!
        return CalendarModel(store: store, now: now, calendar: calendar)
    }

    @Test("오늘이 넘어가고, 오늘을 보고 있었으면 고른 날도 따라간다")
    func followsWhenSittingOnToday() throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let model = makeModel(store, on: 29)
        #expect(model.selected == CalendarDate(year: 2026, month: 8, day: 29))

        model.dayChanged(to: CalendarDate(year: 2026, month: 8, day: 30))

        #expect(model.today == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(model.selected == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(model.isOnToday)
    }

    @Test("일부러 다른 날을 골라 뒀으면 건드리지 않는다 — 사람이 정한 것이 이긴다")
    func keepsADeliberateChoice() throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let model = makeModel(store, on: 29)
        model.select(CalendarDate(year: 2026, month: 8, day: 15))

        model.dayChanged(to: CalendarDate(year: 2026, month: 8, day: 30))

        #expect(model.today == CalendarDate(year: 2026, month: 8, day: 30))
        #expect(model.selected == CalendarDate(year: 2026, month: 8, day: 15))
    }

    @Test("자정을 넘기면 「미루기」가 새 오늘을 기준으로 센다")
    func postponeFollowsTheNewToday() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        // 이미 지나간 일정. 「미루기」는 +1일이 아니라 max(다음 날, 내일) 이다.
        let stale = try await store.create(body: "치과", due: CalendarDate(year: 2026, month: 8, day: 10))

        let model = makeModel(store, on: 29)
        #expect(model.postponeTarget(stale) == CalendarDate(year: 2026, month: 8, day: 30))

        model.dayChanged(to: CalendarDate(year: 2026, month: 8, day: 30))

        // 어제를 기준으로 세면 "오늘로 미루기" 가 되어 아무것도 안 달라진다.
        #expect(model.postponeTarget(stale) == CalendarDate(year: 2026, month: 8, day: 31))
    }

    @Test("같은 날이 다시 오면 아무 일도 안 한다")
    func ignoresTheSameDay() throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let model = makeModel(store, on: 29)
        model.select(CalendarDate(year: 2026, month: 8, day: 15))

        model.dayChanged(to: CalendarDate(year: 2026, month: 8, day: 29))

        #expect(model.selected == CalendarDate(year: 2026, month: 8, day: 15))
    }

    @Test("달을 넘기면 격자도 함께 넘어간다")
    func crossesMonth() throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let model = makeModel(store, on: 31)

        model.dayChanged(to: CalendarDate(year: 2026, month: 9, day: 1))

        #expect(model.grid.month == 9)
        #expect(model.selected == CalendarDate(year: 2026, month: 9, day: 1))
    }
}
