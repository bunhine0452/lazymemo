import Foundation
import Testing
@testable import LazyMemoCore

@Suite("Recall — 무엇을 언제 다시 펼치는가")
struct RecallTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    /// 2026-09-14 (월) 12:00 서울.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))!
    }

    private func at(_ day: Int, _ hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func memo(
        _ body: String = "장보기", at: Date? = nil, due: CalendarDate? = nil, surface: Date? = nil,
        pinned: Bool = false, updated: Date? = nil
    ) -> Memo {
        Memo(updated: updated ?? now, due: due, at: at, surface: surface, pinned: pinned, body: body)
    }

    // MARK: 예약

    @Test("지운 것·치워 둔 것·다 체크한 목록은 걸지 않는다")
    func excludesFinished() {
        var deleted = memo("지운 것", at: at(15, 9)); deleted.deleted = now
        var tidied = memo("치운 것", at: at(15, 9)); tidied.tidied = now
        let finished = memo("- [x] 우유\n- [x] 계란", at: at(15, 9))
        let open = memo("- [x] 우유\n- [ ] 계란", at: at(15, 9))

        #expect(Recall.reservations([deleted, tidied, finished, open], now: now).map(\.title) == ["[x] 우유"])
    }

    @Test("지난 시각과 날짜만 있는 것은 걸지 않는다 — 아침 알림을 지어내지 않는다")
    func futureTimedOnly() {
        let passed = memo("지난 것", at: at(14, 9))
        let dateOnly = memo("날짜만", due: CalendarDate(year: 2026, month: 9, day: 15))
        let coming = memo("올 것", at: at(14, 15))

        #expect(Recall.reservations([passed, dateOnly, coming], now: now).map(\.title) == ["올 것"])
    }

    @Test("따로 정한 시각이 일정 시각을 이긴다")
    func surfaceBeatsEvent() {
        let both = memo("회의", at: at(15, 10), surface: at(15, 9, minute: 30))
        let only = Recall.reservations([both], now: now)
        #expect(only.count == 1)
        #expect(only.first?.date == at(15, 9, minute: 30))
    }

    @Test("가까운 것부터, 같은 시각이면 id 순, 한도만큼")
    func sortedAndLimited() {
        let ids = (0..<3).map { _ in ULID() }.sorted()
        let sameTime = ids.map { Memo(id: $0, at: at(15, 9), body: "같은 시각") }
        let later = memo("나중", at: at(16, 9))
        let sooner = memo("먼저", at: at(14, 13))

        let all = Recall.reservations(sameTime + [later, sooner], now: now)
        #expect(all.map(\.date) == [at(14, 13), at(15, 9), at(15, 9), at(15, 9), at(16, 9)])
        #expect(Array(all[1...3].map(\.id)) == ids)

        let limited = Recall.reservations(sameTime + [later, sooner], now: now, limit: 2)
        #expect(limited.map(\.title) == ["먼저", "같은 시각"])
    }

    @Test("제목은 첫 줄이고 알림에 실릴 만큼만")
    func titleIsTrimmed() {
        let long = memo(String(repeating: "가", count: 400) + "\n둘째 줄", at: at(15, 9))
        #expect(Recall.reservations([long], now: now).first?.title.count == 180)
    }

    // MARK: 지금 세 장

    @Test("오늘 다시 볼 것 → 오늘 일정 → 고정, 최대 셋")
    func nowCardsOrderAndLimit() {
        let revisit = memo("다시 볼 것", surface: at(14, 15))
        let today = memo("오늘 일정", at: at(14, 16))
        let dateOnly = memo("오늘 날짜만", due: CalendarDate(year: 2026, month: 9, day: 14))
        let pinned = memo("고정", pinned: true)
        let tomorrow = memo("내일", at: at(15, 9))

        let cards = Recall.nowCards([tomorrow, pinned, dateOnly, today, revisit], now: now, calendar: calendar)
        #expect(cards.map(\.reason) == [.revisit, .today, .today])
        #expect(cards.map(\.memo.title) == ["다시 볼 것", "오늘 일정", "오늘 날짜만"])
        #expect(cards.map(\.moment) == [at(14, 15), at(14, 16), nil])
    }

    @Test("이유는 첫 것 하나 — 고정한 오늘 일정은 「오늘 일정」이다")
    func reasonIsTheFirstMatch() {
        let pinnedToday = memo("고정한 오늘", at: at(14, 18), pinned: true)
        let cards = Recall.nowCards([pinnedToday], now: now, calendar: calendar)
        #expect(cards.map(\.reason) == [.today])
    }

    @Test("지나간 오늘 시각도 오늘이다 — 놓친 것이 곧 지금 볼 것")
    func passedTodayStillCounts() {
        let missed = memo("아침 회의", surface: at(14, 9))
        let cards = Recall.nowCards([missed], now: now, calendar: calendar)
        #expect(cards.map(\.reason) == [.revisit])
        #expect(cards.first?.moment == at(14, 9))
    }

    @Test("다른 날의 다시 보기는 오늘 일정이면 「오늘 일정」으로 남는다")
    func revisitAnotherDayFallsBackToToday() {
        let memo = memo("오늘 일정, 내일 다시", at: at(14, 18), surface: at(15, 9))
        let cards = Recall.nowCards([memo], now: now, calendar: calendar)
        #expect(cards.map(\.reason) == [.today])
        #expect(cards.first?.moment == at(14, 18))
    }

    @Test("같은 이유 안에서는 가까운 시각, 시각이 없으면 최근에 손댄 것")
    func tieBreaks() {
        let late = memo("늦은 일정", at: at(14, 20))
        let early = memo("이른 일정", at: at(14, 13))
        let oldPin = memo("옛 고정", pinned: true, updated: now.addingTimeInterval(-86_400))
        let newPin = memo("새 고정", pinned: true)

        let cards = Recall.nowCards([oldPin, late, newPin, early], now: now, calendar: calendar, limit: 4)
        #expect(cards.map(\.memo.title) == ["이른 일정", "늦은 일정", "새 고정", "옛 고정"])
    }

    @Test("자정을 넘기면 어제의 것은 빠진다")
    func midnightMovesOn() {
        let yesterday = memo("어제 다시", surface: at(14, 15))
        let afterMidnight = at(15, 0, minute: 30)
        #expect(Recall.nowCards([yesterday], now: afterMidnight, calendar: calendar).isEmpty)
    }

    @Test("지운 것·치워 둔 것·다 체크한 목록은 지금에도 없다")
    func nowExcludesFinished() {
        var deleted = memo("지운 것", pinned: true); deleted.deleted = now
        var tidied = memo("치운 것", surface: at(14, 15)); tidied.tidied = now
        let finished = memo("- [x] 우유", at: at(14, 15))
        #expect(Recall.nowCards([deleted, tidied, finished], now: now, calendar: calendar).isEmpty)
    }
}
