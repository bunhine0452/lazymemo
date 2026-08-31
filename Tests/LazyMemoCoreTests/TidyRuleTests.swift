import Foundation
import Testing
@testable import LazyMemoCore

/// 무엇이 며칠 뒤 스스로 물러나는가 (`{#tidy-rule}`).
///
/// 이 규칙은 **사람이 적어 둔 것을 화면에서 치우는** 규칙이라, 틀리면 그
/// 즉시 "메모가 없어졌다" 가 된다. 그래서 경계 하나하나를 못 박는다 —
/// 하루 이르게 치우는 것도, 영영 안 치우는 것도 똑같이 실패다.
@Suite("스스로 물러나기 — 규칙")
struct TidyRuleTests {
    /// 시험이 흔들리지 않게 시각을 고정한다. 자정 경계를 넘나드는 규칙이라
    /// "지금" 을 쓰면 자정에만 깨지는 시험이 된다.
    private let calendar = Calendar(identifier: .gregorian)

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func days(_ count: Double) -> TimeInterval { count * 24 * 60 * 60 }

    // MARK: 다 체크한 목록

    @Test("다 체크한 목록은 사흘이 지나야 물러난다")
    func finishedChecklistWaitsThreeDays() {
        let body = "장보기\n- [x] 우유\n- [x] 계란"
        let touched = at(2026, 8, 1)
        let memo = Memo(created: touched, updated: touched, body: body)

        // 마지막 칸을 체크한 그 순간 사라지면 성취가 아니라 사고로 보인다.
        #expect(Tidy.reason(for: memo, now: touched, calendar: calendar) == nil)
        #expect(Tidy.reason(for: memo, now: touched + days(2.9), calendar: calendar) == nil)
        #expect(Tidy.reason(for: memo, now: touched + days(3), calendar: calendar) == .finished)
    }

    @Test("한 칸이라도 남아 있으면 물러나지 않는다 — 그것이 아직 할 일이다")
    func unfinishedChecklistStays() {
        let touched = at(2026, 8, 1)
        let memo = Memo(created: touched, updated: touched, body: "- [x] 우유\n- [ ] 계란")

        #expect(Tidy.reason(for: memo, now: touched + days(30), calendar: calendar) == nil)
    }

    @Test("체크상자가 없는 메모는 건드리지 않는다 — 끝났는지 앱이 알 길이 없다")
    func plainMemoStaysForever() {
        let touched = at(2026, 8, 1)
        let memo = Memo(created: touched, updated: touched, body: "비밀번호 힌트: 강아지 이름")

        #expect(Tidy.reason(for: memo, now: touched + days(365), calendar: calendar) == nil)
    }

    // MARK: 지난 일정

    @Test("지난 일정은 그 다음 날이 끝나야 물러난다")
    func pastScheduleWaitsOutTheNextDay() {
        let memo = Memo(
            created: at(2026, 8, 1), updated: at(2026, 8, 1),
            due: CalendarDate(year: 2026, month: 8, day: 10), body: "치과"
        )

        // 당일에는 물론 남아 있다.
        #expect(Tidy.reason(for: memo, now: at(2026, 8, 10, 23), calendar: calendar) == nil)
        // 다음 날 온종일 남아 있는다 — "어제 뭐 했더라" 가 되어야 한다.
        #expect(Tidy.reason(for: memo, now: at(2026, 8, 11, 23), calendar: calendar) == nil)
        // 그 다음 자정에 물러난다.
        #expect(Tidy.reason(for: memo, now: at(2026, 8, 12, 0), calendar: calendar) == .past)
    }

    @Test("아직 오지 않은 일정은 물러나지 않는다")
    func futureScheduleStays() {
        let memo = Memo(
            created: at(2026, 8, 1), updated: at(2026, 8, 1),
            due: CalendarDate(year: 2026, month: 9, day: 1), body: "여행"
        )

        #expect(Tidy.reason(for: memo, now: at(2026, 8, 20), calendar: calendar) == nil)
    }

    @Test("시각까지 적힌 약속도 그 날을 기준으로 센다")
    func timedScheduleUsesItsDay() {
        let memo = Memo(
            created: at(2026, 8, 1), updated: at(2026, 8, 1),
            at: at(2026, 8, 10, 9), body: "회의"
        )

        #expect(Tidy.reason(for: memo, now: at(2026, 8, 11, 23), calendar: calendar) == nil)
        #expect(Tidy.reason(for: memo, now: at(2026, 8, 12, 0), calendar: calendar) == .past)
    }

    // MARK: 손대지 않는 것

    @Test("고정한 것은 규칙이 이기지 못한다 — 사람이 계속 보겠다고 정한 것이다")
    func pinnedNeverTidies() {
        let touched = at(2026, 8, 1)
        let checklist = Memo(created: touched, updated: touched, pinned: true, body: "- [x] 끝")
        let past = Memo(
            created: touched, updated: touched,
            due: CalendarDate(year: 2026, month: 8, day: 1), pinned: true, body: "지난 일정"
        )

        #expect(Tidy.reason(for: checklist, now: touched + days(365), calendar: calendar) == nil)
        #expect(Tidy.reason(for: past, now: touched + days(365), calendar: calendar) == nil)
    }

    @Test("이미 치운 것과 휴지통에 있는 것은 두 번 치우지 않는다")
    func alreadyGoneStaysGone() {
        let touched = at(2026, 8, 1)
        let later = touched + days(30)
        let tidied = Memo(created: touched, updated: touched, body: "- [x] 끝", tidied: touched)
        let trashed = Memo(created: touched, updated: touched, body: "- [x] 끝", deleted: touched)

        #expect(Tidy.reason(for: tidied, now: later, calendar: calendar) == nil)
        #expect(Tidy.reason(for: trashed, now: later, calendar: calendar) == nil)
    }

    // MARK: 체크상자 세기

    @Test("체크상자는 줄 차례대로 세어진다", arguments: [
        ("- [x] 하나\n- [x] 둘", true),
        ("- [X] 대문자도 체크다", true),
        ("* [x] 별표 목록", true),
        ("  - [x] 들여쓴 것", true),
        ("- [ ] 아직", false),
        ("그냥 글", false),
    ])
    func countsCheckboxes(body: String, finished: Bool) {
        #expect(Tidy.isFinishedChecklist(body) == finished)
    }
}
