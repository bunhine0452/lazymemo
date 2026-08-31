import CoreGraphics
import LazyMemoCore
import SwiftUI
import Testing
@testable import LazyMemoUI

/// 「달력」의 잉크와 손 — **화면만 봐서는 틀린 줄 모르는 것들.**
///
/// 얼룩이 한 단계 진한 것, 마름이 하루씩 밀린 것, 손이 렌더마다 다르게
/// 떨리는 것은 그림에서 구별되지 않는다. `MonthGridGeometry` 를 뷰 밖으로
/// 뺀 이유와 같아서 여기에 못 박는다.
@MainActor
@Suite("달력의 잉크")
struct CalendarInkTests {

    // MARK: 달 이름 띠

    @Test("이웃 달은 해를 넘어서도 이어진다")
    func wrapsAcrossTheYear() {
        #expect(MonthStrip.neighbor(of: 12, by: 1) == 1)
        #expect(MonthStrip.neighbor(of: 1, by: -1) == 12)
        #expect(MonthStrip.neighbor(of: 8, by: -1) == 7)
        #expect(MonthStrip.neighbor(of: 8, by: 1) == 9)
        #expect(MonthStrip.neighbor(of: 8, by: 0) == 8)
    }

    @Test("띠에 적히는 이름은 실제로 넘어가는 달과 같다")
    func stripMatchesTheGridItMovesTo() {
        // 이름만 맞고 실제 이동이 다르면, 누르는 자리가 도착지를 속이게 된다.
        for month in 1...12 {
            let grid = MonthGrid.make(year: 2026, month: month)
            #expect(MonthStrip.neighbor(of: month, by: 1) == grid.advanced(by: 1).month)
            #expect(MonthStrip.neighbor(of: month, by: -1) == grid.advanced(by: -1).month)
        }
    }

    // MARK: 번짐

    @Test("일이 없는 날은 얼룩도 없다")
    func emptyDayHasNoStain() {
        #expect(InkBleed.spread(count: 0) == 0)
    }

    @Test("일이 늘수록 짙어지되 끝내 멎는다")
    func spreadGrowsAndSaturates() {
        let steps = (0...8).map { InkBleed.spread(count: $0) }
        for (before, after) in zip(steps, steps.dropFirst()) {
            #expect(after > before)
            #expect(after < 1)
        }
        // 다섯과 여덟의 차이는 게으른 사람에게 아무 뜻도 없다 — 자라는 폭이
        // 줄어들지 않으면 붐비는 달에서 얼룩이 칸을 삼킨다.
        #expect(steps[5] - steps[4] < steps[2] - steps[1])
    }

    @Test("얼룩은 칸을 넘지 않는다")
    func stainStaysInsideItsCell() {
        let cell = CGSize(width: 38, height: 36)
        let full = InkBleed.radius(cell: cell, spread: InkBleed.spread(count: 99))
        #expect(full < min(cell.width, cell.height) / 2)
        // 붐빌수록 커진다.
        #expect(InkBleed.radius(cell: cell, spread: InkBleed.spread(count: 1))
            < InkBleed.radius(cell: cell, spread: InkBleed.spread(count: 4)))
    }

    /// 한 건과 네 건이 나란히 놓였을 때 **다른 날로 보이는가.**
    ///
    /// 앞선 값에서는 지름이 30%, 세기가 25% 밖에 차이 나지 않아 두 칸이 같아
    /// 보였다. 그러면 얼룩은 "이 날은 붐빈다" 를 말하지 못한 채 종이에 묻은
    /// 자국 — 인쇄 얼룩 — 으로만 남는다. 얼룩은 세지 않는 대신 한눈에 갈려야
    /// 하고, 그 둘 중 하나라도 놓치면 표시가 아니라 잡티다.
    @Test("한 건과 네 건이 한눈에 갈린다 — 폭도 대비도")
    func oneAndFourReadDifferently() {
        let cell = CGSize(width: 38, height: 36)
        let one = InkBleed.spread(count: 1)
        let four = InkBleed.spread(count: 4)

        let widths = (InkBleed.radius(cell: cell, spread: four),
                      InkBleed.radius(cell: cell, spread: one))
        #expect(widths.0 >= widths.1 * InkBleed.legibleSpan)

        let inks = (InkBleed.alpha(spread: four, order: 0),
                    InkBleed.alpha(spread: one, order: 0))
        #expect(inks.0 >= inks.1 * InkBleed.legibleSpan)
    }

    @Test("한 건짜리 얼룩은 칸을 물들이지 않는다")
    func oneStainStaysFaint() {
        // 한 건은 슬쩍 밴 자국이어야 한다. 여기가 진하면 빈 날과 한 건의
        // 차이가 사라지는 것이 아니라, 달 전체가 얼룩덜룩해진다.
        #expect(InkBleed.alpha(spread: InkBleed.spread(count: 1), order: 0) < 0.6)
    }

    @Test("뒤에 겹치는 색일수록 옅다")
    func laterInksAreFainter() {
        let spread = InkBleed.spread(count: 3)
        let layers = (0..<InkBleed.maxInks).map { InkBleed.alpha(spread: spread, order: $0) }
        for (front, back) in zip(layers, layers.dropFirst()) {
            #expect(back < front)
        }
        #expect(layers[0] < 1)
    }

    // MARK: 마름

    @Test("오늘과 앞날은 마르지 않는다")
    func todayAndFutureStayWet() {
        #expect(InkDrying.presence(daysAgo: 0) == 1)
        #expect(InkDrying.presence(daysAgo: -5) == 1)
    }

    @Test("지난 날은 하루씩 마른다")
    func pastDriesOneDayAtATime() {
        #expect(InkDrying.presence(daysAgo: 1) == InkDrying.freshest)
        // 어제와 3주 전이 같은 세기면 그것은 물러남이 아니라 그냥 회색이다.
        #expect(InkDrying.presence(daysAgo: 21) < InkDrying.presence(daysAgo: 1))
        #expect(InkDrying.presence(daysAgo: 5) < InkDrying.presence(daysAgo: 4))
    }

    @Test("아무리 오래돼도 사라지지는 않는다")
    func dryingHasAFloor() {
        #expect(InkDrying.presence(daysAgo: 10_000) == InkDrying.driest)
        #expect(InkDrying.driest > 0.3)
    }

    // MARK: 손

    @Test("같은 씨앗이면 같은 손이다")
    func handRepeatsForTheSameSeed() {
        var left = PenHand(seed: 20_260_829)
        var right = PenHand(seed: 20_260_829)
        for _ in 0..<16 {
            #expect(left.next() == right.next())
        }
    }

    @Test("다른 날은 다른 손이다")
    func handDiffersBetweenDays() {
        var one = PenHand(seed: CalendarDate(year: 2026, month: 8, day: 29).penSeed)
        var two = PenHand(seed: CalendarDate(year: 2026, month: 8, day: 30).penSeed)
        #expect(one.next() != two.next())
    }

    @Test("흔들림은 정해진 폭 안에 있다")
    func jitterStaysBounded() {
        var hand = PenHand(seed: 7)
        for _ in 0..<200 {
            let value = hand.next()
            #expect(value >= 0 && value < 1)
        }
        var other = PenHand(seed: 11)
        for _ in 0..<200 {
            #expect(abs(other.jitter(0.25)) <= 0.25)
        }
    }

    // MARK: 펜 자국

    /// 오늘의 동그라미가 프레임마다 새로 떨리면 그것은 손이 아니라 잡음이다.
    @Test("동그라미는 렌더마다 같은 모양이다")
    func ringIsStableAcrossRenders() {
        let box = CGRect(x: 0, y: 0, width: 26, height: 21)
        let seed = CalendarDate(year: 2026, month: 8, day: 29).penSeed
        #expect(HandRing(seed: seed).path(in: box).boundingRect
            == HandRing(seed: seed).path(in: box).boundingRect)
        #expect(HandUnderline(seed: seed).path(in: box).boundingRect
            == HandUnderline(seed: seed).path(in: box).boundingRect)
    }

    @Test("날이 바뀌면 새로 긋는다")
    func ringIsRedrawnEachDay() {
        let box = CGRect(x: 0, y: 0, width: 26, height: 21)
        let today = HandRing(seed: CalendarDate(year: 2026, month: 8, day: 29).penSeed)
        let tomorrow = HandRing(seed: CalendarDate(year: 2026, month: 8, day: 30).penSeed)
        #expect(today.path(in: box).boundingRect != tomorrow.path(in: box).boundingRect)
    }

    /// 손으로 그린 티를 내려고 흔들다가 옆 칸을 침범하면 격자가 무너진다.
    @Test("펜 자국은 제 칸 안에 머문다")
    func marksStayWithinTheirBox() {
        let box = CGRect(x: 6, y: 8, width: 26, height: 21)
        let room = box.insetBy(dx: -4, dy: -4)
        for day in 1...31 {
            let seed = CalendarDate(year: 2026, month: 8, day: day).penSeed
            #expect(room.contains(HandRing(seed: seed).path(in: box).boundingRect))
            #expect(room.contains(HandUnderline(seed: seed).path(in: box).boundingRect))
        }
    }

    // MARK: 방금 한 일

    /// 되돌리기 줄은 **무엇을 되돌리는지**를 말해야 한다. 자리를 옮기는 길이
    /// 셋이 되면서(달력 안에서 옮기기 · 종이에서 건너오기 · 종이로 내려가기)
    /// "옮겼습니다" 하나로는 방금 무엇이 어디로 갔는지 알 수 없게 됐다.
    @Test("달력 안에서 날을 바꾸면 「옮겼습니다」")
    func namesAMoveWithinTheCalendar() {
        let note = MoveNote.text(
            from: Schedule(due: CalendarDate(year: 2026, month: 8, day: 28)),
            to: CalendarDate(year: 2026, month: 8, day: 31)
        )
        #expect(note == "8월 31일로 옮겼습니다")
    }

    @Test("종이에서 건너온 것은 옮긴 것이 아니라 처음 놓은 것이다")
    func namesAPlacementFromPaper() {
        let note = MoveNote.text(from: Schedule(), to: CalendarDate(year: 2026, month: 9, day: 1))
        #expect(note == "9월 1일에 놓았습니다")
    }

    @Test("날짜를 떼면 간 곳이 날이 아니라 종이다")
    func namesADetachToPaper() {
        let note = MoveNote.text(
            from: Schedule(due: CalendarDate(year: 2026, month: 9, day: 1)), to: nil
        )
        #expect(note == "종이로 보냈습니다")
    }

    @Test("자리가 없으면 아무것도 긋지 않는다")
    func drawsNothingWithoutRoom() {
        #expect(HandRing(seed: 1).path(in: .zero).isEmpty)
        #expect(HandUnderline(seed: 1).path(in: .zero).isEmpty)
        #expect(!HandRing(seed: 1).path(in: CGRect(x: 0, y: 0, width: 26, height: 21)).isEmpty)
    }
}
