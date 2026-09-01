import CoreGraphics

/// 「달력」의 **판형** — 세로로 선 창과 가로로 누운 창은 다른 물건이다.
///
/// 앞선 판은 판형이 하나였다. 위에 달 격자, 아래에 그 날의 일. 창을 어떻게
/// 바꾸든 그 배치는 그대로여서 두 방향 모두에서 무너졌다.
///
/// - 세로로 늘리면 **격자는 그대로인 채 아래만 텅 빈다.** 주 높이가 36pt 로
///   못 박혀 있어 창을 두 배로 키워도 달은 창 위쪽에 붙은 작은 표로 남았다.
/// - 가로로 넓히면 **칸만 옆으로 늘어난다.** 칸이 납작해져 날짜가 넓은 여백
///   가운데 떠 있고, 정작 조작하는 면(그 날의 일)은 여전히 창 아래에 눌린
///   띠였다 — 폭은 남아도는데 목록은 좁은 그대로다.
///
/// **창을 키운 만큼 달력이 커지지 않으면 창 크기는 장식이다.** 그래서 두 가지를
/// 값으로 뽑았다.
///
/// 1. **판형** — 넓으면 두 면을 나란히(`wide`), 아니면 위아래로(`tall`).
/// 2. **눈금** — 주 높이·펜 자국·숫자 크기가 창을 따라 자란다.
///
/// 뷰 밖의 순수 값인 이유는 `MonthGridGeometry` 와 같다. 한 판형에서 맞고 다른
/// 판형에서 어긋나는 것은 그림 한 장만 봐서는 드러나지 않는다 — 넓은 창에서
/// 격자가 창 밖으로 8pt 밀려나는 것은 좁은 창의 렌더에 아무 흔적도 남기지
/// 않는다. 그래서 산수는 여기 두고 테스트로 못 박는다.
struct CalendarLayout: Equatable {

    /// 두 면을 놓는 방향.
    enum Shape: Equatable {
        /// 위는 달, 아래는 그 날. 접힌 자리는 가로로 눕는다.
        case tall
        /// 왼쪽은 달, 오른쪽은 그 날. 접힌 자리가 세로로 선다.
        case wide
    }

    var shape: Shape
    /// 한 주의 높이. 격자의 모든 좌표가 여기서 나온다.
    var weekHeight: CGFloat
    /// 날짜에 얹히는 펜 자국의 지름 — 오늘 동그라미와 밑줄이 이것을 따른다.
    var markSize: CGFloat
    var numeralSize: CGFloat
    /// 가로 판형에서 오른쪽 면이 갖는 폭. 세로 판형에서는 0.
    var panelWidth: CGFloat

    // MARK: 자리를 먹는 것들

    /// 머리(달 이름 줄)의 높이. **어림이 아니라 약속이다** — 화면도 이 높이를
    /// 그대로 쓴다 (`CalendarView.header`).
    ///
    /// 어림으로 두었다가 한 번 크게 틀렸다. 셈이 실제보다 몇 pt 라도 적게
    /// 잡으면 격자가 창보다 커지고, 창보다 커진 내용은 잘리는 것으로 끝나지
    /// 않는다 — 창을 재던 `onGeometryChange` 가 **내용의 크기**를 도로 물어와
    /// 격자가 한 번 더 자랐다. 지금은 창을 `GeometryReader` 로 받고 자리를 먹는
    /// 것들의 높이를 여기서 못 박는다.
    ///
    /// 36pt 였다. 달 이름과 이웃 달과 「오늘」과 치우기가 그 안에서 서로
    /// 밀치고 있었고, 누르는 자리는 글자만 했다 — 「9월」을 누르려다 「8월」의
    /// 여백을 누르는 일이 잦았다. 조작 하나가 `Theme.touch` 를 지키려면
    /// 머리도 그만큼은 있어야 한다.
    static let headerHeight: CGFloat = 42
    /// 요일 줄의 높이 (아래 여백까지 포함).
    ///
    /// 9.5pt 짜리 요일은 격자가 커질수록 잔글씨로 남았다. 이 줄은 달을
    /// 읽는 눈금이라 숫자만큼은 아니어도 **읽히기는 해야 한다.**
    static let weekdayHeight: CGFloat = 19
    /// 접힌 자리의 두께.
    static let creaseThickness: CGFloat = 13
    /// 접힌 자리가 통째로 먹는 자리 — 두께에 사이 여백을 더한 것.
    static let creaseBlock: CGFloat = creaseThickness + Theme.tight

    /// 아직 창을 재지 못했을 때 대신 쓰는 크기 — 새 창이 열리는 크기와 같다
    /// (`CalendarWindowController.defaultSize`). 둘이 어긋나면 첫 프레임만
    /// 다른 눈금으로 그려진다.
    static let defaultWindow = CGSize(width: 320, height: 470)

    /// 가로로 눕는 문턱.
    ///
    /// 정사각형 근처에서는 세로 판형이 낫다. 두 면을 나란히 놓으려면 각 면이
    /// 제 몫의 폭을 가져야 하는데, 어중간한 창에서는 **둘 다 못 쓰게 된다** —
    /// 격자는 칸이 좁아 겨냥이 어려워지고 목록은 제목이 잘린다.
    static let wideThreshold: CGFloat = 1.15
    /// 두 면을 나란히 놓을 수 있는 최소 폭. 이보다 좁으면 아무리 납작해도
    /// 위아래로 쌓는다.
    static let wideMinimumWidth: CGFloat = 430

    /// 세로 판형에서 격자가 가져가는 몫. 나머지는 그 날의 일이 쓴다.
    ///
    /// 절반을 조금 넘긴다. 달을 보는 것이 이 창의 첫 일이지만, 아래가 서너 줄
    /// 밖에 못 들어가면 조작하는 면이 아니라 미리보기가 된다.
    private static let gridShare: CGFloat = 0.58
    /// 세로 판형의 주 높이 범위. 아래쪽은 겨냥의 한계(끌어다 놓기가 조준
    /// 게임이 되는 높이), 위쪽은 달이 성겨 보이기 시작하는 높이다.
    ///
    /// 아래쪽을 30 에서 올렸다. 한 칸이 30pt 이면 **칸 하나가 `Theme.touch`
    /// 보다 크지 않다** — 이 창에서 가장 자주 누르는 과녁 마흔둘이 전부
    /// 최소치 언저리였다는 뜻이다. 최소 창도 함께 키웠다
    /// (`CalendarWindowController.minimumSize`).
    private static let weekRange: ClosedRange<CGFloat> = 32...58
    /// 가로 판형은 세로로 남는 높이를 격자가 거의 다 쓴다. 아래로 더 갈 수
    /// 있고(짧고 넓은 창) 위로도 더 갈 수 있다(정사각형에 가까운 큰 창).
    private static let wideWeekRange: ClosedRange<CGFloat> = 28...64
    private static let panelShare: CGFloat = 0.38
    /// 오른쪽 면의 폭. 아래쪽은 `09:30 팀 회의` 한 줄이 안 잘리는 폭,
    /// 위쪽은 더 넓어져도 읽는 속도가 나아지지 않는 폭이다.
    private static let panelRange: ClosedRange<CGFloat> = 190...300
    private static let markRange: ClosedRange<CGFloat> = 16...30
    private static let numeralRange: ClosedRange<CGFloat> = 11.5...19
    /// 칸의 최소 폭. 격자가 이보다 좁아지면 오른쪽 면을 줄여서라도 지킨다.
    private static let minimumCell: CGFloat = 30

    private static let columns = CGFloat(MonthGridGeometry.columns)

    /// 창 크기와 그 달의 주 수에서 판형을 정한다.
    static func resolve(size: CGSize, rows: Int) -> CalendarLayout {
        // 아직 창을 재지 못했으면 기본 창 크기로 친다. 0 을 그대로 풀면 첫
        // 프레임만 다른 눈금으로 그려지고, 그것이 화면 밖 렌더에서는 결과가 된다.
        guard size.width > 0, size.height > 0 else {
            return resolve(size: CalendarLayout.defaultWindow, rows: rows)
        }
        let weeks = CGFloat(max(rows, 1))
        let lyingDown = size.width >= size.height * wideThreshold && size.width >= wideMinimumWidth
        return lyingDown ? lying(size: size, weeks: weeks) : standing(size: size, weeks: weeks)
    }

    /// 세로 판형 — 위아래로 쌓는다.
    ///
    /// 격자는 남은 높이의 정해진 몫만 가져간다. 주 수로 나누므로 **5주 달과
    /// 6주 달의 격자 높이가 같다** — 달을 넘길 때 아래 면의 높이가 출렁이지
    /// 않고, 대신 5주 달의 칸이 조금 넉넉해진다.
    private static func standing(size: CGSize, weeks: CGFloat) -> CalendarLayout {
        let free = max(
            size.height - headerHeight - weekdayHeight - creaseBlock,
            weeks * weekRange.lowerBound
        )
        let week = clamp(free * gridShare / weeks, to: weekRange)
        return CalendarLayout(shape: .tall, weekHeight: week, panelWidth: 0, in: size)
    }

    /// 가로 판형 — 나란히 놓는다.
    ///
    /// 여기서는 격자가 **높이를 거의 다 쓴다.** 접힌 자리가 세로로 서므로
    /// 아래에 자리를 비워 둘 이유가 없고, 넓은 창에서 칸이 납작해지는 것이
    /// 앞선 판의 가장 큰 결함이었다.
    private static func lying(size: CGSize, weeks: CGFloat) -> CalendarLayout {
        // 격자의 최소 폭을 먼저 떼어 놓고 남은 것을 오른쪽 면에 준다. 넓은
        // 창에서는 비율이 이기고, 아슬아슬한 창에서는 칸의 최소 폭이 이긴다.
        let room = max(size.width - wideMargins - columns * minimumCell, 0)
        let panel = min(clamp(size.width * panelShare, to: panelRange), room)
        let free = max(
            size.height - headerHeight - weekdayHeight - Theme.snug,
            weeks * wideWeekRange.lowerBound
        )
        let week = clamp(free / weeks, to: wideWeekRange)
        return CalendarLayout(shape: .wide, weekHeight: week, panelWidth: panel, in: size)
    }

    /// 판형과 주 높이가 정해지면 나머지 눈금은 **칸의 크기에서 나온다.**
    ///
    /// 칸의 폭을 여기서 다시 세지 않고 `gridWidth(in:)` 을 부르는 것은, 셈이
    /// 두 군데 있으면 한쪽만 고쳐질 것이기 때문이다 — 그러면 펜 자국이 칸을
    /// 넘는 판형이 하나 생기고, 그것은 그 판형의 그림을 봐야만 드러난다.
    private init(shape: Shape, weekHeight: CGFloat, panelWidth: CGFloat, in size: CGSize) {
        self.shape = shape
        self.weekHeight = weekHeight
        self.panelWidth = panelWidth
        let cell = max(Self.gridWidth(shape: shape, panelWidth: panelWidth, in: size), 1) / Self.columns
        markSize = Self.clamp(min(weekHeight * 0.52, cell * 0.56), to: Self.markRange)
        // 숫자가 동그라미 안에서 차지하는 몫. 0.64 였을 때는 큰 창에서
        // 마흔둘이 넓은 여백 가운데 떠 있는 것으로 보였다 — 칸만 자라고
        // 글자는 안 자란 셈이다.
        numeralSize = Self.clamp(markSize * 0.68, to: Self.numeralRange)
    }

    /// 격자가 갖는 폭. 가로 판형에서는 오른쪽 면과 접힌 자리를 뺀 나머지다.
    func gridWidth(in size: CGSize) -> CGFloat {
        Self.gridWidth(shape: shape, panelWidth: panelWidth, in: size)
    }

    private static func gridWidth(shape: Shape, panelWidth: CGFloat, in size: CGSize) -> CGFloat {
        switch shape {
        case .tall: max(size.width - Theme.normal * 2, 0)
        case .wide: max(size.width - wideMargins - panelWidth, 0)
        }
    }

    /// 가로 판형에서 격자와 오른쪽 면 밖으로 나가는 자리 — 왼쪽 여백과 접힌
    /// 자리. 오른쪽 여백은 `panelWidth` 안에 들어 있다.
    private static let wideMargins: CGFloat = Theme.normal + creaseBlock

    /// 격자가 실제로 차지할 높이. 창에 들어가는지 견주는 데 쓴다.
    func gridHeight(rows: Int) -> CGFloat {
        weekHeight * CGFloat(max(rows, 1))
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
