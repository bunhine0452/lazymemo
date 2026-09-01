import CoreGraphics
import Testing
@testable import LazyMemoUI

/// 「달력」의 판형 — **그림 한 장으로는 확인되지 않는 것들.**
///
/// 판형이 둘이 되면서 확인해야 할 것도 둘이 됐다. 넓은 창에서 격자가 창 밖으로
/// 밀려나는 것은 좁은 창의 렌더에 아무 흔적도 남기지 않고, 그 반대도 같다.
/// 실제로 한 번 그렇게 됐다 — 620×360 창에서 머리가 통째로 잘려 나갔는데
/// 기본 창의 그림은 멀쩡했다. 그래서 산수를 뷰 밖에 두고 여기서 못 박는다.
@Suite("달력의 판형")
struct CalendarLayoutTests {

    /// 창을 훑는 표본. 실제로 쓸 만한 크기부터 최소 크기까지.
    private static let windows: [CGSize] = [
        CGSize(width: 320, height: 470),   // 기본
        CGSize(width: 288, height: 356),   // 최소 (`CalendarWindowController.minimumSize`)
        CGSize(width: 300, height: 440),   // 예전 기본 — 저장된 창은 그대로 열린다
        CGSize(width: 340, height: 620),   // 세로로 길게
        CGSize(width: 430, height: 320),   // 눕는 문턱
        CGSize(width: 620, height: 360),   // 가로로 넓게
        CGSize(width: 900, height: 500),
        CGSize(width: 1200, height: 700),
        CGSize(width: 500, height: 500),   // 정사각형
    ]

    // MARK: 어느 쪽으로 눕는가

    @Test("가로로 충분히 넓으면 두 면을 나란히 놓는다")
    func wideWindowsLieDown() {
        #expect(CalendarLayout.resolve(size: CGSize(width: 620, height: 360), rows: 6).shape == .wide)
        #expect(CalendarLayout.resolve(size: CGSize(width: 900, height: 500), rows: 5).shape == .wide)
    }

    @Test("세로로 서 있거나 정사각형에 가까우면 위아래로 쌓는다")
    func tallWindowsStandUp() {
        #expect(CalendarLayout.resolve(size: CGSize(width: 300, height: 440), rows: 6).shape == .tall)
        // 정사각형 근처에서 두 면을 나란히 놓으면 둘 다 못 쓰게 된다.
        #expect(CalendarLayout.resolve(size: CGSize(width: 500, height: 500), rows: 6).shape == .tall)
        #expect(CalendarLayout.resolve(size: CGSize(width: 540, height: 500), rows: 6).shape == .tall)
    }

    @Test("좁은 창은 아무리 납작해도 위아래로 쌓는다")
    func narrowWindowsNeverSplit() {
        // 400×200 은 비율로는 눕지만, 나눠 가질 폭 자체가 없다.
        #expect(CalendarLayout.resolve(size: CGSize(width: 400, height: 200), rows: 6).shape == .tall)
        #expect(CalendarLayout.resolve(size: CGSize(width: 429, height: 300), rows: 6).shape == .tall)
        #expect(CalendarLayout.resolve(size: CGSize(width: 430, height: 300), rows: 6).shape == .wide)
    }

    @Test("창을 아직 재지 못했으면 기본 창으로 친다")
    func unmeasuredWindowFallsBackToTheDefault() {
        // 0 을 그대로 풀면 첫 프레임만 다른 눈금으로 그려지고, 화면 밖
        // 렌더에서는 그 한 프레임이 곧 결과다.
        #expect(CalendarLayout.resolve(size: .zero, rows: 6)
            == CalendarLayout.resolve(size: CalendarLayout.defaultWindow, rows: 6))
    }

    // MARK: 창을 넘지 않는다

    /// 창보다 큰 내용은 잘리는 것으로 끝나지 않는다 — 잘린 쪽이 머리이면
    /// 달 이름과 이동 버튼이 통째로 사라진다. 실제로 그렇게 됐었다.
    @Test("격자는 어떤 창에서도 창을 넘지 않는다")
    func gridNeverOutgrowsTheWindow() {
        for size in Self.windows {
            for rows in 4...6 {
                let plan = CalendarLayout.resolve(size: size, rows: rows)
                let chrome = CalendarLayout.headerHeight + CalendarLayout.weekdayHeight
                let stacked = plan.shape == .tall ? CalendarLayout.creaseBlock : 0
                #expect(chrome + stacked + plan.gridHeight(rows: rows) <= size.height)
            }
        }
    }

    @Test("세로 판형에서는 아래 면에도 자리가 남는다")
    func standingLayoutKeepsRoomForTheDay() {
        for size in Self.windows {
            let plan = CalendarLayout.resolve(size: size, rows: 6)
            guard plan.shape == .tall else { continue }
            let used = CalendarLayout.headerHeight + CalendarLayout.weekdayHeight
                + CalendarLayout.creaseBlock + plan.gridHeight(rows: 6)
            // 제목 한 줄과 적는 줄이 들어갈 만큼은 남아야 한다. 이보다 좁으면
            // 아래 면은 조작하는 자리가 아니라 잘린 띠가 된다.
            #expect(size.height - used >= 44)
        }
    }

    @Test("가로 판형에서 두 면이 폭을 나눠 갖는다")
    func lyingLayoutSharesTheWidth() {
        for size in Self.windows {
            let plan = CalendarLayout.resolve(size: size, rows: 6)
            guard plan.shape == .wide else { continue }
            // 칸이 좁아지면 끌어다 놓기가 조준 게임이 된다.
            #expect(plan.gridWidth(in: size) / 7 >= 30)
            // `09:30 팀 회의` 한 줄이 안 잘릴 만큼은 오른쪽 면이 가져간다.
            #expect(plan.panelWidth >= 168)
            #expect(plan.gridWidth(in: size) + plan.panelWidth <= size.width)
        }
    }

    // MARK: 창을 따라 자란다

    @Test("창이 커지면 칸도 커진다")
    func cellsGrowWithTheWindow() {
        let small = CalendarLayout.resolve(size: CGSize(width: 300, height: 380), rows: 6)
        let medium = CalendarLayout.resolve(size: CGSize(width: 300, height: 480), rows: 6)
        let large = CalendarLayout.resolve(size: CGSize(width: 340, height: 620), rows: 6)
        #expect(small.weekHeight < medium.weekHeight)
        #expect(medium.weekHeight < large.weekHeight)
        #expect(small.numeralSize < large.numeralSize)
    }

    /// 칸 하나가 `Theme.touch` 보다 작으면, 이 창에서 가장 자주 누르는 과녁
    /// 마흔둘이 전부 최소치 아래라는 뜻이다. 끌어다 놓기의 착지 판정도 이
    /// 칸이라(`MonthGridGeometry`) 좁아지는 만큼 그대로 조준 게임이 된다.
    @Test("주 높이는 겨냥할 수 있는 범위 안에 머문다")
    func weekHeightStaysAimable() {
        for size in Self.windows {
            for rows in 4...6 {
                let plan = CalendarLayout.resolve(size: size, rows: rows)
                #expect(plan.weekHeight >= Theme.touch)
                #expect(plan.weekHeight <= 64)
            }
        }
        // 아주 큰 창에서도 달이 성기게 퍼지지는 않는다.
        let huge = CalendarLayout.resolve(size: CGSize(width: 1600, height: 1200), rows: 6)
        #expect(huge.weekHeight <= 64)
    }

    /// 손으로 그린 동그라미는 지름의 1.44배까지 벌어진다 (`HandRing` 을 쓰는
    /// 자리의 프레임). 그것이 칸을 넘으면 격자가 무너진다.
    @Test("펜 자국은 어떤 판형에서도 제 칸 안에 머문다")
    func marksStayInsideTheirCell() {
        for size in Self.windows {
            for rows in 4...6 {
                let plan = CalendarLayout.resolve(size: size, rows: rows)
                #expect(plan.markSize * 1.44 <= plan.gridWidth(in: size) / 7)
                #expect(plan.markSize * 1.17 <= plan.weekHeight)
                // 숫자는 동그라미 안에 앉는다.
                #expect(plan.numeralSize < plan.markSize)
            }
        }
    }

    @Test("주 수가 달라져도 격자는 창 안에 있다")
    func fiveAndSixWeekMonthsBothFit() {
        // 5주 달과 6주 달은 같은 창에서 격자 높이가 같다 — 달을 넘길 때
        // 아래 면의 높이가 출렁이면 목록이 매달 다른 자리에서 시작한다.
        let size = CGSize(width: 300, height: 440)
        let five = CalendarLayout.resolve(size: size, rows: 5)
        let six = CalendarLayout.resolve(size: size, rows: 6)
        #expect(abs(five.gridHeight(rows: 5) - six.gridHeight(rows: 6)) < 0.5)
        #expect(five.weekHeight > six.weekHeight)
    }
}
