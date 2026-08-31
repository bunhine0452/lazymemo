import AppKit
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

/// 메뉴 목록의 골라진 줄은 **그 메모의 종이색**으로 깔린다 (`{#menu-highlight}`).
///
/// 시스템 파랑(`selectedContentBackgroundColor`)을 쓰던 자리다. 그 색은 이
/// 목록만 다른 앱에서 잘라 온 부품처럼 보이게 했고, 무엇보다 같은 메모를 두
/// 곳에서 다르게 그렸다 — 빠른 입력에서는 그 메모의 종이색이 옅게 깔린다.
/// 그림을 봐서는 "파란색이네" 까지밖에 말할 수 없어 여기서 잰다.
@MainActor
@Suite("메뉴 줄 — 강조는 종이색이다")
struct MemoRowHighlightTests {
    @Test("강조 색은 그 메모의 색에서 나온다")
    func highlightComesFromTheMemoColor() {
        for color in MemoColor.allCases {
            let fill = MemoRow.highlightFill(color).usingColorSpace(.sRGB)!
            let ink = NSColor(color.tint).usingColorSpace(.sRGB)!
            #expect(abs(fill.redComponent - ink.redComponent) < 0.001)
            #expect(abs(fill.greenComponent - ink.greenComponent) < 0.001)
            #expect(abs(fill.blueComponent - ink.blueComponent) < 0.001)
        }
    }

    @Test("색마다 다른 강조다 — 여덟 줄이 같은 파랑으로 덮이지 않는다")
    func everyColorHighlightsDifferently() {
        let fills = MemoColor.allCases.map { MemoRow.highlightFill($0) }
        for (index, one) in fills.enumerated() {
            for other in fills[(index + 1)...] {
                #expect(one != other)
            }
        }
    }

    @Test("바탕은 옅게 깔린다 — 글자를 덮지 않는다")
    func highlightIsAWashNotAFill() {
        let fill = MemoRow.highlightFill(.blue)
        #expect(fill.alphaComponent > 0.1)
        #expect(fill.alphaComponent < 0.35)
    }
}

/// 그림 하나뿐인 버튼이 소리로는 무엇이 되는가 (`{#swiftui-a11y}`).
@Suite("소리 내어 읽기")
struct SpokenHelpTests {
    @Test("도움말의 앞머리가 이름이고 「—」 뒤가 힌트다")
    func splitsHelpIntoNameAndHint() {
        let said = SpokenHelp.split("지우기 — 메뉴의 되돌리기로 살릴 수 있습니다")
        #expect(said.name == "지우기")
        #expect(said.hint == "메뉴의 되돌리기로 살릴 수 있습니다")
    }

    @Test("한 낱말짜리 도움말은 그대로 이름이 된다")
    func keepsShortHelpAsIs() {
        let said = SpokenHelp.split("고정")
        #expect(said.name == "고정")
        #expect(said.hint.isEmpty)
    }

    @Test("「—」 가 여럿이면 첫 것만 가른다")
    func splitsOnlyAtTheFirstDash() {
        let said = SpokenHelp.split("치우기 — 메모는 지워지지 않습니다 — 메뉴에서 다시 엽니다")
        #expect(said.name == "치우기")
        #expect(said.hint == "메모는 지워지지 않습니다 — 메뉴에서 다시 엽니다")
    }
}
