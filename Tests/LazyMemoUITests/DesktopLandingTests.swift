import CoreGraphics
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 무엇이 바탕화면에 종이로 남는가 (설계문서 §7.2).
///
/// 사용자가 겪은 결함: 달력에서 「이 날에 적기」로 일정을 넣을 때마다 바탕화면에
/// 종이가 한 장씩 생겼다. 일정 열 개를 넣으면 종이가 열 장이고, 그러면 창 상한
/// (§7 — 24장)이 일정으로 채워져 정작 눈에 밟혀야 할 메모가 밀려난다.
///
/// 원인은 달력이 아니라 창 관리자의 기본값이었다 — **새 메모는 무조건 바탕화면**
/// 이었고, 그래서 빠른 입력도 MCP 도 같은 결과였다. 고칠 자리가 한 곳이라는 뜻이고,
/// 그 한 곳을 화면 없이 확인할 수 있게 순수 함수로 떼어 여기서 못 박는다.
@Suite("종이가 되는 것과 달력이 맡는 것")
struct DesktopLandingTests {
    private func record(hidden: Bool) -> WindowLayout {
        WindowLayout(frame: CGRect(x: 0, y: 0, width: 240, height: 200), hidden: hidden)
    }

    @Test("날짜가 없으면 종이가 된다 — 언제 볼지 정해지지 않은 것은 눈에 밟혀야 한다")
    func undatedMemoBecomesPaper() {
        #expect(NoteWindowManager.staysOnDesktop(isScheduled: false, layout: nil))
    }

    @Test("날짜가 붙으면 달력이 맡는다 — 종이는 생기지 않는다")
    func scheduledMemoGoesToTheCalendar() {
        #expect(!NoteWindowManager.staysOnDesktop(isScheduled: true, layout: nil))
    }

    @Test("사람이 꺼내 둔 일정은 종이로 남는다 — 정한 것이 규칙을 이긴다")
    func explicitlyOpenedScheduleStays() {
        #expect(NoteWindowManager.staysOnDesktop(isScheduled: true, layout: record(hidden: false)))
    }

    @Test("사람이 치운 메모는 날짜가 없어도 돌아오지 않는다")
    func hiddenMemoStaysHidden() {
        #expect(!NoteWindowManager.staysOnDesktop(isScheduled: false, layout: record(hidden: true)))
    }

    // MARK: 자리를 옮긴다

    /// 앞선 판은 §7.2 를 **태어나는 순간에만** 적용했다. 날짜를 나중에 붙이거나
    /// 떼는 길이 없었고, 있었더라도 `layout.json` 의 기록이 규칙을 이기므로
    /// 한 번 종이가 된 메모는 일정이 되어도 종이로 남았다 — 자리를 나눠 놓고
    /// 옮길 수 없게 해 둔 셈이다.
    @Test("날짜를 얻으면 종이는 물러난다 — 달력이 맡는다")
    func gainingAScheduleHidesThePaper() {
        #expect(NoteWindowManager.handover(was: false, now: true) == true)
    }

    @Test("날짜를 떼면 종이가 돌아온다 — 언제 볼지 다시 모르게 됐으므로")
    func losingAScheduleBringsThePaperBack() {
        #expect(NoteWindowManager.handover(was: true, now: false) == false)
    }

    @Test("자리가 그대로면 기록을 건드리지 않는다 — 사람이 정한 것이 남는다")
    func unchangedPlaceLeavesTheRecordAlone() {
        #expect(NoteWindowManager.handover(was: true, now: true) == nil)
        #expect(NoteWindowManager.handover(was: false, now: false) == nil)
    }

    /// 기동 직후 모든 일정을 한꺼번에 숨김으로 적으면, 사람이 일부러 꺼내 둔
    /// 일정(§7.2 의 예외)이 껐다 켜는 것만으로 통째로 사라진다.
    @Test("처음 본 메모는 자리가 바뀐 것이 아니다")
    func firstSightIsNotAHandover() {
        #expect(NoteWindowManager.handover(was: nil, now: true) == nil)
        #expect(NoteWindowManager.handover(was: nil, now: false) == nil)
    }

    @Test("달력에서 적은 것은 언제나 일정이다 — 그래서 종이가 되지 않는다")
    func writingOnADayNeverMakesPaper() {
        let day = CalendarDate(year: 2026, month: 9, day: 1)
        for text in ["치과", "오후 3시 치과", "내일 치과"] {
            let draft = QuickSchedule.make(from: text, on: day)
            #expect(!draft.schedule.isEmpty, "「\(text)」 가 날짜 없이 만들어졌다")
            #expect(!NoteWindowManager.staysOnDesktop(isScheduled: true, layout: nil))
        }
    }
}
