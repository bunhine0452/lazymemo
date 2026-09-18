import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoWidgetsCore

@Suite("WidgetAgenda — 위젯이 보여 주는 것과 바뀌는 순간")
struct WidgetAgendaTests {
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
        _ body: String = "장보기", at: Date? = nil, due: CalendarDate? = nil, surface: Date? = nil, pinned: Bool = false
    ) -> Memo {
        Memo(updated: now, due: due, at: at, surface: surface, pinned: pinned, body: body)
    }

    // MARK: 「지금」

    @Test("띠와 같은 답 — 다가오는 것이 먼저, 셋까지")
    func nowCardsMatchBand() {
        let memos = [
            memo("지난 회의", at: at(14, 9)),
            memo("곧 치과", at: at(14, 15)),
            memo("고정", pinned: true),
            memo("오늘 날짜만", due: CalendarDate(year: 2026, month: 9, day: 14)),
            memo("내일", at: at(15, 9)),
        ]
        let cards = WidgetAgenda.nowCards(memos, now: now, calendar: calendar)
        #expect(cards.map(\.memo.title) == ["곧 치과", "지난 회의", "오늘 날짜만"])
        #expect(cards == Recall.nowCards(memos, now: now, calendar: calendar))
    }

    @Test("「봤어요」로 내려놓은 것은 위젯에서도 빠진다")
    func seenIsShared() {
        let seen = memo("본 것", at: at(14, 15))
        let cards = WidgetAgenda.nowCards([seen, memo("고정", pinned: true)], now: now, calendar: calendar, seen: [seen.id: at(14, 15)])
        #expect(cards.map(\.memo.title) == ["고정"])
    }

    @Test("다음 — 오늘 뒤의 일정만, 가까운 날부터, 같은 날은 시각 순")
    func upcomingAfterToday() {
        let memos = [
            memo("오늘", at: at(14, 15)),
            memo("모레", due: CalendarDate(year: 2026, month: 9, day: 16)),
            memo("내일 오후", at: at(15, 14)),
            memo("내일 날짜만", due: CalendarDate(year: 2026, month: 9, day: 15)),
            memo("내일 아침", at: at(15, 9)),
            memo("지난 것", due: CalendarDate(year: 2026, month: 9, day: 13)),
        ]
        let rows = WidgetAgenda.upcoming(memos, now: now, calendar: calendar, limit: 3)
        #expect(rows.map(\.memo.title) == ["내일 날짜만", "내일 아침", "내일 오후"])
        #expect(rows[0].at == nil)
        #expect(rows[1].at == at(15, 9))
    }

    @Test("오늘부터 세면 오늘 것이 앞에 선다 — 달력 위젯의 아래 절")
    func upcomingIncludingToday() {
        let memos = [
            memo("내일", due: CalendarDate(year: 2026, month: 9, day: 15)),
            memo("오늘 오후", at: at(14, 15)),
            memo("오늘 아침 지남", at: at(14, 9)),
            memo("어제", due: CalendarDate(year: 2026, month: 9, day: 13)),
        ]
        let rows = WidgetAgenda.upcoming(memos, now: now, calendar: calendar, limit: 4, includingToday: true)
        #expect(rows.map(\.memo.title) == ["오늘 아침 지남", "오늘 오후", "내일"])
        #expect(WidgetAgenda.upcoming(memos, now: now, calendar: calendar).map(\.memo.title) == ["내일"])
    }

    // MARK: 달력

    @Test("달의 점 — 날짜별 수, 앞뒤 달에서 넘어온 칸까지, 물러난 것은 세고 지운 것은 안 센다")
    func monthMarks() {
        let grid = MonthGrid.make(year: 2026, month: 9)
        var tidied = memo("물러난 것", due: CalendarDate(year: 2026, month: 9, day: 3)); tidied.tidied = now
        var deleted = memo("지운 것", due: CalendarDate(year: 2026, month: 9, day: 3)); deleted.deleted = now
        let memos = [
            memo("치과", at: at(14, 15)),
            memo("회의", at: at(14, 9)),
            memo("날짜만", due: CalendarDate(year: 2026, month: 9, day: 20)),
            // 9월 격자는 8월 30일(일)부터 10월 3일(토)까지 — 넘어온 칸의 일정도 점이 된다.
            memo("넘어온 칸", due: CalendarDate(year: 2026, month: 10, day: 3)),
            memo("격자 밖", due: CalendarDate(year: 2026, month: 10, day: 4)),
            memo("날 없음"),
            tidied, deleted,
        ]
        let marks = WidgetAgenda.monthMarks(memos, in: grid, calendar: calendar)
        #expect(marks == [
            CalendarDate(year: 2026, month: 9, day: 14): 2,
            CalendarDate(year: 2026, month: 9, day: 20): 1,
            CalendarDate(year: 2026, month: 10, day: 3): 1,
            CalendarDate(year: 2026, month: 9, day: 3): 1,
        ])
    }

    @Test("달력이 바뀌는 순간 — 지금, 그리고 자정 셋")
    func dayChanges() {
        #expect(WidgetAgenda.dayChanges(now: now, calendar: calendar) == [now, at(15, 0), at(16, 0), at(17, 0)])
        // 자정 정각에 물어도 다음 자정으로 간다 — 같은 자정을 두 번 주지 않는다.
        #expect(WidgetAgenda.dayChanges(now: at(15, 0), calendar: calendar, count: 1) == [at(15, 0), at(16, 0)])
    }

    // MARK: 다음 약속

    @Test("다음 약속 — 앞으로 올 시각 중 가장 가까운 것, 날짜만 있는 것은 아니다")
    func nextAppointment() {
        let memos = [
            memo("지난 것", at: at(14, 9)),
            memo("날짜만", due: CalendarDate(year: 2026, month: 9, day: 14)),
            memo("모레", at: at(16, 10)),
            memo("오늘 저녁", at: at(14, 19)),
        ]
        let next = WidgetAgenda.next(memos, now: now, calendar: calendar)
        #expect(next?.memo.title == "오늘 저녁")
        #expect(next?.at == at(14, 19))
        #expect(next?.departure == nil)
    }

    @Test("치워 둔 것·지운 것·다 체크한 것은 약속이 아니다")
    func nextSkipsFinished() {
        var tidied = memo("치운 것", at: at(14, 15)); tidied.tidied = now
        var deleted = memo("지운 것", at: at(14, 16)); deleted.deleted = now
        let finished = memo("- [x] 끝", at: at(14, 17))
        #expect(WidgetAgenda.next([tidied, deleted, finished], now: now, calendar: calendar) == nil)
    }

    @Test("가는 길이 적힌 약속은 출발 시각과 첫 탈것을 든다")
    func departureFromRoute() {
        let route = TransitRoute(
            origin: "석촌고분역", destination: "투파인드피터", minutes: 21, arrive: at(14, 19),
            legs: [
                TransitRoute.Leg(mode: .walk, minutes: 2),
                TransitRoute.Leg(mode: .subway, minutes: 12, line: "2호선", from: "잠실", to: "강남"),
                TransitRoute.Leg(mode: .walk, minutes: 7),
            ]
        )
        let body = RouteNote.append(route, to: "저녁 약속", calendar: calendar)
        let next = WidgetAgenda.next([memo(body, at: at(14, 19))], now: now, calendar: calendar)
        #expect(next?.departure?.at == at(14, 18, minute: 39))
        #expect(next?.departure?.ride == "2호선")

        let bus = TransitRoute(
            origin: "집", destination: "회사", minutes: 30, arrive: at(14, 19),
            legs: [TransitRoute.Leg(mode: .bus, minutes: 30, line: "3314", kind: "지선", from: "잠실여고후문", to: "잠실역")]
        )
        let byBus = WidgetAgenda.departure(memo(RouteNote.append(bus, to: "출근", calendar: calendar), at: at(14, 19)), calendar: calendar)
        #expect(byBus?.ride == "3314 버스")
    }

    // MARK: 시간표

    @Test("바뀌는 순간 — 지금, 각 메모의 시각, 자정 순")
    func momentsInOrder() {
        let memos = [
            memo("곧", at: at(14, 15)),
            memo("지난 것", at: at(14, 9)),
            memo("다시 보기", at: at(15, 10), surface: at(14, 18)),
            memo("멀리", at: at(20, 9)),
        ]
        let moments = WidgetAgenda.moments(memos, now: now, calendar: calendar)
        let midnight = at(15, 0)
        #expect(moments == [now, at(14, 15), at(14, 18), midnight, at(15, 10)])
    }

    @Test("메모가 없어도 지금과 자정은 있다 — 한도는 지킨다")
    func momentsEmptyAndLimited() {
        #expect(WidgetAgenda.moments([], now: now, calendar: calendar) == [now, at(15, 0)])
        let many = (13..<23).map { memo("\($0)시", at: at(14, $0)) }
        let limited = WidgetAgenda.moments(many, now: now, calendar: calendar, limit: 4)
        #expect(limited == [now, at(14, 13), at(14, 14), at(14, 15)])
    }

    @Test("지운 것의 시각은 순간이 아니다")
    func momentsSkipIneligible() {
        var deleted = memo("지운 것", at: at(14, 15)); deleted.deleted = now
        #expect(WidgetAgenda.moments([deleted], now: now, calendar: calendar) == [now, at(15, 0)])
    }
}

@Suite("WidgetLink — 위젯이 두드리는 주소")
struct WidgetLinkTests {
    @Test("메모 주소는 그 id 로 돌아온다")
    func memoRoundTrip() {
        let id = ULID()
        let url = WidgetLink.memo(id)
        #expect(url.absoluteString == "lazymemo://memo/\(id.description)")
        #expect(WidgetLink.destination(of: url) == .memo(id))
        #expect(WidgetLink.destination(of: URL(string: "lazymemo:memo/\(id.description)")!) == .memo(id))
    }

    @Test("적기 주소")
    func write() {
        #expect(WidgetLink.write.absoluteString == "lazymemo://write")
        #expect(WidgetLink.destination(of: WidgetLink.write) == .write)
        #expect(WidgetLink.destination(of: URL(string: "LAZYMEMO://Write/")!) == .write)
    }

    @Test("모르는 주소는 nil — add 는 InboundLink 의 것이고, 깨진 id 도 nil")
    func unknownIsNil() {
        #expect(WidgetLink.destination(of: URL(string: "lazymemo://add?text=hi")!) == nil)
        #expect(WidgetLink.destination(of: URL(string: "lazymemo://memo/not-an-id")!) == nil)
        #expect(WidgetLink.destination(of: URL(string: "lazymemo://memo")!) == nil)
        #expect(WidgetLink.destination(of: URL(string: "https://example.com/memo/01ARZ3NDEKTSV4RRFFQ69G5FAV")!) == nil)
    }

    @Test("달력 주소 — 이번 달, 또는 그 날. 깨진 날은 주소 전체가 모르는 것")
    func calendar() {
        #expect(WidgetLink.calendar().absoluteString == "lazymemo://calendar")
        #expect(WidgetLink.calendarStop(of: WidgetLink.calendar()) == .month)
        let day = CalendarDate(year: 2026, month: 9, day: 17)
        #expect(WidgetLink.calendar(day).absoluteString == "lazymemo://calendar/2026-09-17")
        #expect(WidgetLink.calendarStop(of: WidgetLink.calendar(day)) == .day(day))
        #expect(WidgetLink.calendarStop(of: URL(string: "lazymemo:calendar/2026-09-17")!) == .day(day))
        #expect(WidgetLink.calendarStop(of: URL(string: "lazymemo://calendar/2026-9-1")!) == nil)
        #expect(WidgetLink.calendarStop(of: URL(string: "lazymemo://calendar/2026-09-17/x")!) == nil)
        #expect(WidgetLink.calendarStop(of: WidgetLink.write) == nil)
        // 앱이 아직 모르는 동사라 `destination` 은 nil — InboundLink 도 add 가 아니니 조용히 버린다.
        #expect(WidgetLink.destination(of: WidgetLink.calendar(day)) == nil)
        #expect(InboundLink.note(from: WidgetLink.calendar(day)) == nil)
    }

    @Test("종류의 식별자는 번들 id 아래에 선다")
    func kinds() {
        #expect(WidgetKind.now.identifier == "io.github.bunhine0452.lazymemo.widgets.now")
        #expect(WidgetKind.calendar.identifier == "io.github.bunhine0452.lazymemo.widgets.calendar")
        #expect(WidgetKind.identifiers.count == 4)
    }
}

@Suite("NowSeen — 「봤어요」의 기억")
struct NowSeenTests {
    @Test("오늘 것만 남기고, 읽으면 같은 이름표가 돌아온다")
    func roundTrip() {
        let suite = "lazymemo-widgets-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))!
        let today = ULID(), yesterday = ULID()
        NowSeen.save(
            [today: now.addingTimeInterval(3600), yesterday: now.addingTimeInterval(-86_400)],
            now: now, calendar: calendar, defaults: defaults
        )
        let loaded = NowSeen.load(defaults: defaults)
        #expect(loaded == [today: now.addingTimeInterval(3600)])
    }

    /// 위젯의 「봤어요」 — 앱이 이미 내려놓은 것을 덮지 않는다.
    @Test("한 장을 내려놓아도 먼저 내려놓은 것은 그대로 남는다")
    func putDownKeepsOthers() {
        let suite = "lazymemo-widgets-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))!
        let first = ULID(), second = ULID()

        NowSeen.save([first: now], now: now, calendar: calendar, defaults: defaults)
        NowSeen.putDown(second, stamp: now.addingTimeInterval(3600), now: now, calendar: calendar, defaults: defaults)

        #expect(NowSeen.load(defaults: defaults) == [first: now, second: now.addingTimeInterval(3600)])
    }

    @Test("같은 메모를 다시 내려놓으면 이름표만 바뀐다 — 어제 것은 그때 버려진다")
    func putDownReplacesStamp() {
        let suite = "lazymemo-widgets-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))!
        let card = ULID(), stale = ULID()

        NowSeen.save([card: now, stale: now.addingTimeInterval(-86_400)], now: now, calendar: calendar, defaults: defaults)
        NowSeen.putDown(card, stamp: now.addingTimeInterval(7200), now: now, calendar: calendar, defaults: defaults)

        #expect(NowSeen.load(defaults: defaults) == [card: now.addingTimeInterval(7200)])
    }
}
