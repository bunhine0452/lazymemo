import Foundation
import Testing
@testable import LazyMemoCore

/// 「나올 때」(`surface`)는 «일이 언제인가» 와 다른 것을 말한다.
@Suite("메모의 나올 때")
struct MemoSurfaceTests {
    private let sample = """
        ---
        id: 01K3ZQ8F7N2R4M6X8B0V5T9WQY
        created: 2026-08-28T16:29:50+09:00
        updated: 2026-08-28T16:31:00+09:00
        at: 2026-09-01T15:00:00+09:00
        surface: 2026-09-01T14:30:00+09:00
        color: yellow
        pinned: false
        ---
        치과 예약
        """

    @Test("surface 를 읽고 왕복해도 변하지 않는다")
    func roundTrips() throws {
        let memo = try MemoFile.decode(sample)
        #expect(memo.surface == Timestamp.date(from: "2026-09-01T14:30:00+09:00"))

        let again = try MemoFile.decode(
            MemoFile.encode(memo, timeZone: TimeZone(identifier: "Asia/Seoul")!)
        )
        #expect(again.surface == memo.surface)
        #expect(again.at == memo.at)
    }

    @Test("나올 때는 자리를 바꾸지 않는다 — 달력이 맡는 것은 여전히 날짜뿐이다")
    func doesNotSchedule() {
        let memo = Memo(surface: Date(), body: "금요일에 다시 보기")
        #expect(!memo.isScheduled)
        #expect(memo.scheduledDate() == nil)
    }

    @Test("시계가 보는 값은 하나다 — 적혀 있으면 그것, 없으면 일정 시각")
    func surfacesAtPrefersSurface() {
        let event = Date(timeIntervalSince1970: 1_800_000_000)
        let early = event.addingTimeInterval(-1800)

        #expect(Memo(at: event).surfacesAt == event)
        #expect(Memo(at: event, surface: early).surfacesAt == early)
        #expect(Memo(surface: early).surfacesAt == early)
        #expect(Memo(body: "그냥 메모").surfacesAt == nil)
    }

    @Test("일정 옆에 붙는 말을 메모가 스스로 안다")
    func tellsItsLead() {
        let event = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(Memo(at: event, surface: event.addingTimeInterval(-1800)).surfaceLead == "30분 전")
        // 일정이 없으면 견줄 것이 없다 — 그때는 홀로 선다.
        #expect(Memo(surface: event).surfaceLead == nil)
        #expect(Memo(at: event).surfaceLead == nil)
    }

    @Test("날짜만 있는 일정에도 붙는다 — 그 날 0시를 기준으로 센다")
    func leadsFromDueDate() {
        let due = CalendarDate(year: 2026, month: 9, day: 1)
        guard let midnight = due.startOfDay() else { Issue.record("자정을 못 구했다"); return }
        let memo = Memo(due: due, surface: midnight.addingTimeInterval(-86_400))
        #expect(memo.surfaceLead == "1일 전")
    }
}
