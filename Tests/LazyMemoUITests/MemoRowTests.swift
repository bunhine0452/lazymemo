import CoreGraphics
import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 메뉴 줄의 휴지통이 몇 픽셀 어긋나 있으면 "눌렀는데 안 지워진다" 가 된다.
/// 화면을 봐서는 알 수 없는 종류의 고장이라 좌표를 못 박는다.
@Suite("MemoRowGeometry")
struct MemoRowGeometryTests {
    private let geometry = MemoRowGeometry(timeWidth: 40)

    @Test("휴지통은 오른쪽 끝에서 여백만큼 안쪽에 있다")
    func placesTrashAtTrailingEdge() {
        let trash = geometry.trash
        #expect(trash.maxX == MemoRowGeometry.width - 9)
        #expect(trash.width == MemoRowGeometry.trashSide)
        #expect(trash.midY == MemoRowGeometry.height / 2)
    }

    @Test("시간은 휴지통 왼쪽에 자기 폭만큼 앉는다")
    func placesTimeLeftOfTrash() {
        #expect(geometry.time.maxX == geometry.trash.minX - 9)
        #expect(geometry.time.width == 40)
    }

    @Test("제목은 점과 시간 사이의 남은 자리를 전부 쓴다")
    func titleTakesRemainingWidth() {
        let title = geometry.title
        #expect(title.minX == geometry.dot.maxX + 9)
        #expect(title.maxX == geometry.time.minX - 9)
        #expect(title.width > 100)
    }

    @Test("시간이 없으면 제목이 휴지통 앞까지 늘어난다")
    func titleGrowsWithoutTime() {
        let bare = MemoRowGeometry(timeWidth: 0)
        #expect(bare.title.maxX == bare.trash.minX - 9)
        #expect(bare.title.width > geometry.title.width)
    }

    @Test("휴지통을 누르는 자리는 그림보다 넉넉하다")
    func trashHitAreaIsForgiving() {
        let trash = geometry.trash
        #expect(geometry.hitsTrash(CGPoint(x: trash.midX, y: trash.midY)))
        // 그림 밖 3pt 까지는 지우기로 친다 — 게으른 손은 조준하지 않는다.
        #expect(geometry.hitsTrash(CGPoint(x: trash.minX - 3, y: trash.midY)))
        #expect(geometry.hitsTrash(CGPoint(x: trash.maxX + 3, y: trash.midY)))
    }

    @Test("제목 자리를 누르면 지우기가 아니라 열기다")
    func titleAreaIsNotTrash() {
        #expect(!geometry.hitsTrash(CGPoint(x: geometry.title.midX, y: geometry.title.midY)))
        #expect(!geometry.hitsTrash(CGPoint(x: geometry.time.midX, y: geometry.time.midY)))
        #expect(!geometry.hitsTrash(CGPoint(x: geometry.trash.minX - 8, y: geometry.trash.midY)))
    }
}

/// 목록에서 메모를 알아보는 유일한 단서다. 하루가 밀리면 "그때 그거" 를
/// 영영 못 찾는다.
@Suite("MemoTimeLabel")
struct MemoTimeLabelTests {
    private let now = Date(timeIntervalSince1970: 1_787_000_000)  // 2026-08-29 (KST)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    private var today: CalendarDate { CalendarDate(now, calendar: calendar) }

    private func memo(due: CalendarDate? = nil, at: Date? = nil, updated: Date? = nil) -> Memo {
        Memo(updated: updated ?? now, due: due, at: at, body: "무엇")
    }

    @Test("일정이 오늘·내일이면 낱말로 적는다")
    func namesNearbyDays() {
        #expect(MemoTimeLabel.text(for: memo(due: today), now: now, calendar: calendar) == "오늘")
        #expect(
            MemoTimeLabel.text(for: memo(due: today.adding(days: 1, calendar: calendar)),
                               now: now, calendar: calendar) == "내일"
        )
        #expect(
            MemoTimeLabel.text(for: memo(due: today.adding(days: 3, calendar: calendar)),
                               now: now, calendar: calendar) == "3일 뒤"
        )
    }

    @Test("먼 날은 월/일로 줄인다 — 목록 오른쪽 끝은 좁다")
    func shortensDistantDays() {
        let far = today.adding(days: 30, calendar: calendar)
        #expect(
            MemoTimeLabel.text(for: memo(due: far), now: now, calendar: calendar)
                == "\(far.month)/\(far.day)"
        )
    }

    @Test("시각이 있으면 날 뒤에 24시로 붙인다")
    func appendsClockToDay() {
        let at = calendar.date(byAdding: .hour, value: 30, to: now)!
        let text = MemoTimeLabel.text(for: memo(at: at), now: now, calendar: calendar)
        #expect(text.hasPrefix("내일 "))
        #expect(text.contains(":"))
    }

    @Test("일정이 없으면 마지막으로 손댄 때를 보인다")
    func fallsBackToLastEdit() {
        #expect(MemoTimeLabel.text(for: memo(), now: now, calendar: calendar) == "오늘")
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        #expect(
            MemoTimeLabel.text(for: memo(updated: twoDaysAgo), now: now, calendar: calendar)
                == "2일 전"
        )
    }

    @Test("일정이 지나갔어도 그 날을 그대로 적는다 — 재촉하지 않는다 (철학 1)")
    func keepsPastSchedule() {
        let yesterday = today.adding(days: -1, calendar: calendar)
        #expect(MemoTimeLabel.text(for: memo(due: yesterday), now: now, calendar: calendar) == "어제")
    }
}
