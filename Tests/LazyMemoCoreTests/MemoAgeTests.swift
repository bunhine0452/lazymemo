import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MemoAge — 바램")
struct MemoAgeTests {
    private let now = Date(timeIntervalSince1970: 1_787_000_000)   // 2026-08-18

    private func memo(daysAgo: Int, pinned: Bool = false, due: CalendarDate? = nil) -> Memo {
        let updated = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        return Memo(updated: updated, due: due, pinned: pinned, body: "본문")
    }

    @Test("오늘 손댄 메모는 또렷하다")
    func todayIsFresh() {
        #expect(MemoAge.of(memo(daysAgo: 0), now: now) == .fresh)
    }

    @Test("시간이 지날수록 물러난다")
    func fadesOverTime() {
        #expect(MemoAge.of(memo(daysAgo: 3), now: now) == .recent)
        #expect(MemoAge.of(memo(daysAgo: 20), now: now) == .settled)
        #expect(MemoAge.of(memo(daysAgo: 200), now: now) == .faded)
    }

    @Test("고정한 메모는 바래지 않는다 — 사용자가 직접 앞에 두라고 말한 것이다")
    func pinnedNeverFades() {
        #expect(MemoAge.of(memo(daysAgo: 500, pinned: true), now: now) == .fresh)
    }

    @Test("다가오는 일정은 언제 적었든 또렷하다")
    func upcomingScheduleStaysFresh() {
        let future = CalendarDate(Calendar.current.date(byAdding: .day, value: 10, to: now)!)
        #expect(MemoAge.of(memo(daysAgo: 300, due: future), now: now) == .fresh)
    }

    @Test("지난 일정은 다른 메모와 똑같이 물러난다")
    func pastScheduleFadesLikeAnythingElse() {
        let past = CalendarDate(Calendar.current.date(byAdding: .day, value: -60, to: now)!)
        #expect(MemoAge.of(memo(daysAgo: 60, due: past), now: now) == .faded)
    }

    @Test("물러날수록 드러남이 줄어든다")
    func presenceDecreasesMonotonically() {
        let values = MemoAge.allCases.map(\.presence)
        #expect(values == values.sorted(by: >))
        #expect(MemoAge.fresh.presence == 1.0)
    }
}
