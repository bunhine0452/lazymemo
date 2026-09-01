import Foundation
import Testing
@testable import LazyMemoCore

@Suite("GeofenceRule — 어느 자리를 지켜볼 것인가")
struct GeofenceRuleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12))!
    }

    private func memo(
        _ body: String = "장보기", geo: String? = "37.4979,127.0276",
        due: CalendarDate? = nil, pinned: Bool = false, updated: Date? = nil
    ) -> Memo {
        Memo(
            updated: updated ?? now, due: due,
            geo: geo.flatMap(Coordinate.init), pinned: pinned, body: body
        )
    }

    private func select(_ memos: [Memo]) -> GeofenceRule.Selection {
        GeofenceRule.select(memos, now: now, calendar: calendar)
    }

    @Test("좌표가 있는 메모만 지켜본다 — 이름만 적힌 장소는 보내지 않는다")
    func onlyWithCoordinates() {
        let named = Memo(place: "강남역", body: "커피")
        #expect(select([memo(), named]).watched.count == 1)
    }

    @Test("갈 일이 없는 것은 지켜보지 않는다")
    func skipsWhatIsDone() {
        var deleted = memo("지운 것"); deleted.deleted = now
        var tidied = memo("치운 것"); tidied.tidied = now
        let finished = memo("- [x] 우유\n- [x] 계란")
        let past = memo("지난 일정", due: CalendarDate(year: 2026, month: 8, day: 20))

        #expect(select([deleted, tidied, finished, past]).watched.isEmpty)
    }

    @Test("오늘 일정과 다가오는 일정은 남는다")
    func keepsUpcoming() {
        let today = memo("오늘", due: CalendarDate(year: 2026, month: 8, day: 31))
        let soon = memo("다음 주", due: CalendarDate(year: 2026, month: 9, day: 7))
        #expect(select([today, soon]).watched.count == 2)
    }

    @Test("고정한 것이 먼저, 그 다음 최근에 손댄 순")
    func ordersByPinThenRecency() {
        let old = memo("옛것", updated: now.addingTimeInterval(-86_400))
        let fresh = memo("새것")
        let stuck = memo("고정", pinned: true, updated: now.addingTimeInterval(-864_000))

        #expect(select([old, fresh, stuck]).watched.map(\.title) == ["고정", "새것", "옛것"])
    }

    @Test("스무 개까지만 — 그리고 몇 장이 빠졌는지 센다")
    func capsAndCounts() {
        let many = (0..<25).map { memo("메모\($0)", updated: now.addingTimeInterval(Double(-$0))) }
        let selection = select(many)

        #expect(selection.watched.count == GeofenceRule.limit)
        // **조용히 자르지 않는다** — 「거기 갔는데 안 떴다」가 이 기능을 못 믿게 만든다.
        #expect(selection.dropped == 5)
    }

    @Test("스무 개 아래면 빠진 것이 없다")
    func nothingDroppedWhenFew() {
        #expect(select([memo(), memo("둘")]).dropped == 0)
    }
}
