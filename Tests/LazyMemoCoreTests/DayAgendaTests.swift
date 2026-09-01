import Foundation
import Testing
@testable import LazyMemoCore

@Suite("DayAgenda — 우리 종이와 남의 일정이 한 줄기로")
struct DayAgendaTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(_ title: String, minutes: Double, allDay: Bool = false) -> ForeignEvent {
        ForeignEvent(
            id: title, title: title,
            start: base.addingTimeInterval(minutes * 60),
            isAllDay: allDay, calendarName: "직장"
        )
    }

    private func memo(_ body: String, minutes: Double?, updated: Date? = nil) -> Memo {
        Memo(
            updated: updated ?? base,
            at: minutes.map { base.addingTimeInterval($0 * 60) },
            body: body
        )
    }

    @Test("시각이 있는 것부터 시각 순으로 선다")
    func sortsByTime() {
        let rows = DayAgenda.rows(
            memos: [memo("치과", minutes: 120)],
            events: [event("회의", minutes: 60), event("점심", minutes: 180)]
        )
        #expect(rows.map(\.title) == ["회의", "치과", "점심"])
    }

    @Test("시각 없는 것은 뒤에 — 이 앱이 이미 쓰던 규칙 그대로")
    func untimedComeLast() {
        let rows = DayAgenda.rows(
            memos: [memo("장보기", minutes: nil)],
            events: [event("회의", minutes: 60), event("휴가", minutes: 0, allDay: true)]
        )
        #expect(rows.first?.title == "회의")
        #expect(Set(rows.dropFirst().map(\.title)) == ["장보기", "휴가"])
    }

    @Test("같은 시각이면 우리 것이 먼저 — 조작이 붙는 줄이 손에 가깝다")
    func oursFirstOnTies() {
        let rows = DayAgenda.rows(
            memos: [memo("치과", minutes: 60)],
            events: [event("회의", minutes: 60)]
        )
        #expect(rows.map(\.title) == ["치과", "회의"])
    }

    @Test("시각 없는 메모끼리는 최근에 손댄 것부터")
    func untimedMemosByRecency() {
        let older = memo("먼저", minutes: nil, updated: base.addingTimeInterval(-3600))
        let newer = memo("나중", minutes: nil, updated: base)
        #expect(DayAgenda.rows(memos: [older, newer], events: []).map(\.title)
            == ["나중", "먼저"])
    }

    @Test("남의 일정에는 조작을 붙이지 않는다")
    func foreignRowsAreNotOurs() {
        let rows = DayAgenda.rows(memos: [memo("치과", minutes: 60)], events: [event("회의", minutes: 30)])
        #expect(rows.first(where: { !$0.isOurs })?.title == "회의")
        #expect(rows.filter(\.isOurs).count == 1)
    }

    @Test("남의 일정이 없으면 예전과 같은 줄기다")
    func unchangedWithoutEvents() {
        let rows = DayAgenda.rows(memos: [memo("치과", minutes: 60), memo("장보기", minutes: nil)], events: [])
        #expect(rows.map(\.title) == ["치과", "장보기"])
    }

    @Test("읽기만 하는 빈 문이 있다 — 권한이 없을 때 갈래를 뷰에 두지 않는다")
    func emptyFeed() async {
        let feed = EmptyCalendarFeed()
        let events = await feed.events(
            from: CalendarDate(year: 2026, month: 9, day: 1),
            to: CalendarDate(year: 2026, month: 9, day: 30)
        )
        #expect(events.isEmpty)
    }
}
