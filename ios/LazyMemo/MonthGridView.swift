import LazyMemoCore
import SwiftUI

/// 달 격자 — 달력 탭과 날짜 시트가 같은 것을 쓴다 (MOBILE_DESIGN §5·§6).
///
/// 오늘은 포레스트 원, 고른 날은 옅은 원, 일정은 숫자 밑의 **점**이다 — 맥의
/// 달력과 같은 낱말 (§10.4). 앞선 판은 일정 있는 칸을 네모 바탕으로 물들였는데,
/// 그 네모가 「고른 날」과 같은 모양이라 두 칸이 골라진 것처럼 읽혔다.
/// 여섯 주의 높이를 예약해 5주·6주를 오가도 아래가 흔들리지 않는다.
///
/// ## 넘김 — 손가락을 따라간다
///
/// 앞·이번·다음 세 판을 나란히 두고 손가락만큼 민다. 놓으면 **어디까지 갔을지**
/// (`predictedEndTranslation` — 거리에 속도를 더한 값)로 넘길지 되돌릴지 정하고
/// **손가락의 속도를 이어받은** 스프링으로 자리 잡는다 (`Motion.settle(velocity:over:)`) —
/// 속도 0 에서 다시 출발하면 손을 뗀 순간 판이 한 번 멈칫한다. 앞선 판은 손을 뗀
/// 뒤에야 격자가 뚝 바뀌어 넘어갔는지 되돌아왔는지 손이 알 길이 없었다 — "Touch and
/// content should stay together and move as one thing" (WWDC18 803).
///
/// 화살표·「오늘」·이웃 달의 칸을 눌러 달이 바뀔 때도 같은 미끄러짐이다. 넘김을
/// 부르는 쪽은 여전히 `onStep`/`onToday` 만 부르고, **정본 `grid` 가 바뀌는 것을
/// 보고** 판이 그리로 미끄러진다 — 손짓이든 단추든 한 길이라 한 물건으로 보인다.
/// 움직임을 줄인 사람에게는 옆으로 밀지 않고 바꿔 끼운다 (HIG Accessibility —
/// "Replacing transitions in x-, y-, and z-axes with fades").
///
/// ## 손가락마다 다시 그리지 않는다
///
/// 손가락이 움직이는 매 프레임 이 뷰의 `body` 가 다시 돈다. 그때 세 판 126칸을 매번
/// 다시 만들면 — 옆 달 산수 둘, 칸마다 소리 이름표의 날짜 서식 — 한 프레임 예산(120Hz
/// 에서 8ms)을 서식만으로 먹어 **살짝 걸리는 느낌**이 났다. 그래서 판은 `Equatable` 인
/// 자식(`MonthStrip`·`MonthPanel`)이고, 프레임마다 바뀌는 것은 그 바깥의 `offset` 뿐이다
/// — 달·점·고른 날이 그대로면 SwiftUI 가 판의 `body` 를 건너뛴다. 소리 이름표도
/// 문자열이 아니라 `Text(date, format:)` 로 두어 읽힐 때 서식한다.
///
/// ## 넘어가는 순간에도, 다 간 뒤에도 다시 짓지 않는다
///
/// 정본이 바뀌는 프레임에 판이 새 달로 **뛰었다가** 다음 프레임에 옛 달로 돌아와
/// 미끄러지기 시작했다 — `onChange` 는 그 프레임을 다 그린 뒤에 불리기 때문이다.
/// 그 한 프레임에 126칸을 지었고, 돌아오며 84칸을 또 지었고, 다 간 뒤 세 판을 통째로
/// 다시 지었다 (한 번의 넘김에 판 body 여덟 번, 시뮬레이터에서 판 하나가 5ms).
/// 지금은 화면 가운데의 달(`shown`)이 정본과 따로 있어 정본이 먼저 바뀌어도 판은
/// 그대로이고, 세 판은 **달 번호가 정체성**이라(`ForEach`) 다 간 뒤 가운데였던 판이
/// 옆으로 옮겨 앉을 뿐 새로 짓는 것은 새로 보이는 한 판이다. 점과 고른 날도 판마다
/// 제 달의 것만 받아 옆 달의 점이 갱신돼도 이 판은 다시 그리지 않는다.
struct MonthGridView: View {
    let grid: MonthGrid
    let selected: CalendarDate?
    /// 날짜별 점 — 메모의 색, 그 날의 차례로. 점 하나가 메모 하나다 (`WidgetAgenda.monthInks`).
    let marks: [CalendarDate: [MemoColor]]
    let today: CalendarDate
    let onPick: (CalendarDate) -> Void
    let onStep: (Int) -> Void
    let onToday: () -> Void
    /// 줄을 끌어다 칸에 놓았을 때 — 메모 id 문자열들. `nil` 이면 놓을 수 없는 격자(시트).
    let onDrop: ((CalendarDate, [String]) -> Bool)?

    init(
        grid: MonthGrid,
        selected: CalendarDate?,
        marks: [CalendarDate: [MemoColor]] = [:],
        today: CalendarDate = CalendarDate(Date()),
        onPick: @escaping (CalendarDate) -> Void,
        onStep: @escaping (Int) -> Void,
        onToday: @escaping () -> Void,
        onDrop: ((CalendarDate, [String]) -> Bool)? = nil
    ) {
        self.grid = grid
        self.selected = selected
        self.marks = marks
        self.today = today
        self.onPick = onPick
        self.onStep = onStep
        self.onToday = onToday
        self.onDrop = onDrop
        _shown = State(initialValue: grid)
    }

    private static let cell: CGFloat = 44
    /// 여섯 주 — 5주·6주를 오가도 아래가 흔들리지 않는 예약.
    private static let gridHeight: CGFloat = cell * 6 + 4 * 5
    /// 요일 일곱 자와 달 이름 열둘. **`static` 이다** — 인스턴스 속성으로 두면 부모가
    /// 다시 그릴 때마다 `Calendar` 를 뜨고 다시 서식한다 (달 이름은 손가락 프레임마다).
    /// 말은 앱이 도는 동안 바뀌지 않는다.
    private static let weekdays = DateWords.weekdayLetters()
    private static let monthNames = (1...12).map { DateWords.month($0) }

    // MARK: 넘김

    /// 손가락이 붙어 있는 동안의 것 — 떼거나 빼앗기면(시트가 내려가거나 목록이 스크롤을
    /// 가져가면) **스스로** 초기값으로 돌아간다. `active` 가 꺼지는 것을 보고 빼앗긴
    /// 손짓의 판을 제자리로 보낸다 — 그때는 `onEnded` 가 안 온다.
    private struct Touch {
        var active = false
        /// 첫 움직임으로 정한 축. 세로면 이 손짓은 격자의 것이 아니다.
        var axis: Axis?
    }

    /// 화면 가운데 놓인 달. 정본 `grid` 가 먼저 바뀌고, 판은 이것을 붙든 채 미끄러진 뒤
    /// `land` 에서 따라간다 — 정본이 바뀌는 프레임에 판이 새 달로 뛰지 않는다.
    @State private var shown: MonthGrid
    @GestureState private var touch = Touch()
    /// 판의 자리 — 손가락이 민 만큼, 놓은 뒤에는 스프링이 한 판만큼 또는 0 으로.
    @State private var offset: CGFloat = 0
    /// 들어오는 달이 어느 쪽에서 오는가 (+1 오른쪽, −1 왼쪽). `nil` 이면 쉬는 중.
    @State private var incoming: Int?
    /// 판 하나의 폭 — 놓을 때 「반을 넘었는가」 를 재는 자.
    @State private var width: CGFloat = 0
    /// 미끄러짐마다 하나씩. 끝맺음이 제 것인지 확인한다 — 중간에 새 손짓이 끼어들면 앞 것은 버린다.
    @State private var generation = 0
    /// 놓는 순간의 손가락 속도 — 정본이 바뀌어 `slide` 가 부를 때 스프링에 넘기고 비운다.
    @State private var flick: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 손가락이 이 만큼 가야 격자의 손짓이다 — 칸 누르기와 가르는 문턱.
    private static let slack: CGFloat = 12

    var body: some View {
        VStack(spacing: 8) {
            header
            HStack(spacing: 0) {
                ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(weekdayInk(index))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            pages
        }
        // 칸이 단추라 격자의 손짓이 그 밑에 깔리면 안 된다 — 판이 손가락을 따라가면 손 밑의
        // 칸도 함께 가서, 놓는 순간 그 칸이 눌린다. 격자의 손짓이 먼저다; 움직이지 않은
        // 손가락은 이 손짓이 되지 못하고(`slack`) 그때 칸이 눌린다.
        .highPriorityGesture(
            DragGesture(minimumDistance: Self.slack)
                .updating($touch) { value, touch, _ in
                    touch.active = true
                    if touch.axis == nil { touch.axis = Self.axis(of: value) }
                }
                .onChanged(follow)
                .onEnded(release)
        )
        .onChange(of: touch.active) { _, active in
            if !active { settleIfAbandoned() }
        }
        .onChange(of: grid) { old, new in
            guard old.ordinal != new.ordinal else { return }
            slide(from: old, to: new)
        }
        // 달이 넘어간 순간 손끝에 한 번. 판이 미끄러지는 데 0.3초가 걸리므로
        // 눈보다 손이 먼저 «넘어갔다» 를 안다 — HIG Feedback 「Feedback helps us
        // to operate cars confidently」. 튕겨 되돌아온 손짓에는 울리지 않는다:
        // 정본이 안 바뀌었기 때문이다.
        .sensoryFeedback(.selection, trigger: grid.ordinal)
    }

    /// 세 판 — 앞·이번·다음. 화면 가장자리에서 자른다 (안쪽 여백에서 자르면 들어오는
    /// 달이 여백 밖에서 뚝 나타난다).
    private var pages: some View {
        GeometryReader { proxy in
            MonthStrip(
                center: shown, destination: grid, incoming: incoming, wings: !reduceMotion,
                selected: selected, marks: marks, today: today, width: proxy.size.width,
                onPick: onPick, onDrop: onDrop
            )
            .equatable()
            // 프레임마다 바뀌는 것은 이것뿐이다 — 판은 위에서 같다고 보면 다시 그리지 않는다.
            .offset(x: offset)
        }
        .frame(height: Self.gridHeight)
        .clipped()
        // 판 하나의 폭은 이 자리의 폭이다 — 세 판을 이은 줄의 폭(셋 곱)이 아니라.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    // MARK: 손짓

    private static func axis(of value: DragGesture.Value) -> Axis {
        abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
    }

    private func follow(_ value: DragGesture.Value) {
        // 축은 `touch` 가 잠근다. 첫 움직임에서 아직 안 적혔으면 같은 값으로 같은 답이 나온다.
        guard (touch.axis ?? Self.axis(of: value)) == .horizontal else { return }
        // 미끄러지는 도중에 다시 잡으면 앞 것은 그 자리에 놓고 새 손짓을 따른다 —
        // "Allow for constant redirection and interruption" (WWDC18 803).
        if incoming != nil {
            generation += 1
            land(on: grid)
        }
        // 움직임을 줄인 사람에게는 판이 손을 따라가지 않는다. 놓을 때의 판정은 같다.
        guard !reduceMotion else { return }
        offset = min(max(value.translation.width, -width), width)
    }

    private func release(_ value: DragGesture.Value) {
        guard Self.axis(of: value) == .horizontal, width > 0 else { return }
        // 손이 멈춘 자리가 아니라 **흘러갈 자리**로 판정한다 — 짧고 빠른 튕김도 넘어가고,
        // 반 넘게 끌고 되돌아온 손은 되돌아온다 (시스템 페이징과 같은 문턱, 반).
        let predicted = value.predictedEndTranslation.width
        let sameWay = (predicted < 0) == (value.translation.width < 0)
        guard sameWay, abs(predicted) > width / 2 else {
            // 되돌아온다 — 손이 가던 속도 그대로.
            withAnimation(Motion.settle(velocity: value.velocity.width, over: -offset)) { offset = 0 }
            return
        }
        // 정본을 바꾼다 — 판은 `onChange(of: grid)` 에서 지금 자리·지금 속도로 이어 미끄러진다.
        flick = value.velocity.width
        onStep(predicted < 0 ? 1 : -1)
    }

    /// 손짓이 뺏겼다 — `release` 가 안 왔으니 판이 밀린 채 굳는다. 한 틱 뒤에 본다: 제대로
    /// 놓였으면 그때는 이미 되돌아가는 중이거나(`offset` 이 0) 넘어가는 중이다(`incoming`).
    private func settleIfAbandoned() {
        Task { @MainActor in
            guard incoming == nil, offset != 0 else { return }
            withAnimation(Motion.settle) { offset = 0 }
        }
    }

    /// 정본이 바뀌었다 — 옛 달을 붙든 채 새 달을 옆에서 들여온다.
    private func slide(from old: MonthGrid, to new: MonthGrid) {
        // 미끄러지는 중에 또 바뀌었다(화살표 연타) — 앞 것은 그 자리에 놓고 거기서 간다.
        if incoming != nil { land(on: old) }
        generation += 1
        let mine = generation
        let side = new.ordinal > old.ordinal ? 1 : -1
        let velocity = flick
        flick = 0
        if reduceMotion {
            withAnimation(Motion.crossFade) { shown = new }
            return
        }
        incoming = side
        let target = CGFloat(-side) * width
        withAnimation(Motion.settle(velocity: velocity, over: target - offset)) {
            offset = target
        } completion: {
            guard generation == mine else { return }
            land(on: new)
        }
    }

    /// 다 갔다 — `month` 가 가운데에 선다. **움직임 없이** 자리를 바꿔야 한 프레임도 안 튄다:
    /// 옆 칸에 있던 판이 가운데로 옮겨 앉는 것과 줄이 제자리로 돌아오는 것이 서로를 지운다.
    private func land(on month: MonthGrid) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shown = month
            incoming = nil
            offset = 0
        }
    }

    // MARK: 머리

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // 제목은 정본이다 — 넘기기로 한 순간 바뀐다. 「어디로 가는가」를 판보다 먼저 말한다.
            Text(Self.monthNames[grid.month - 1])
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Paper.ink)
                .contentTransition(.opacity)
            Text(String(grid.year))
                .font(.title3)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            Spacer()
            Button { onStep(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("지난달")
            Button { onStep(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("다음달")
            Button("오늘", action: onToday)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .foregroundStyle(Theme.accentInk)
        .padding(.horizontal, 20)
        .animation(Motion.quick(reduceMotion), value: grid.ordinal)
        .accessibilityElement(children: .contain)
    }

    private func weekdayInk(_ index: Int) -> Color {
        switch index {
        case 0: Theme.sundayInk
        case 6: Theme.saturdayInk
        default: .secondary
        }
    }
}

extension MonthGrid {
    /// 달의 번호 — 차례와 정체성. 세 판은 이것으로 서로 구별된다.
    fileprivate var ordinal: Int { year * 12 + month }
}

// MARK: - 세 판

/// 앞·이번·다음 세 판 — 손가락이 미는 동안 **같다고 보이면 다시 그리지 않는** 단위.
///
/// 옆 판의 달은 여기서 셈한다(`neighbor`) — 부모가 프레임마다 셈하면 달 산수 둘이
/// 매 프레임 든다. 들어오는 달이 정해져 있으면 그것이 옆에 선다 — 「오늘」로 멀리 갈
/// 때 그 사이 달을 다 지나지 않고 목적지가 바로 옆에서 들어온다.
///
/// 판은 **달 번호가 정체성**이다. 다 간 뒤 가운데 달이 옆으로 옮겨 앉을 때 SwiftUI 는
/// 그 판을 옮기기만 하고, 새로 짓는 것은 새로 보이는 한 판뿐이다 — 옮겨 앉는 판은 바깥의
/// 숨김 표시만 바뀐다. 자리는 `ZStack` 에서 판마다 제 칸만큼 밀어 놓는다 — `HStack` 이면
/// 움직임을 줄인 사람의 바꿔 끼우기가 옆으로 밀려 나간다(빠지는 판이 자리를 비우기 전까지
/// 새 판이 오른쪽에 선다).
private struct MonthStrip: View, Equatable {
    let center: MonthGrid
    /// 정본 — 미끄러지는 중이면 목적지.
    let destination: MonthGrid
    let incoming: Int?
    /// 옆 판을 세우는가. 움직임을 줄인 사람에게는 가운데 한 판뿐이고, 달이 바뀌면 바꿔 끼운다.
    let wings: Bool
    let selected: CalendarDate?
    let marks: [CalendarDate: [MemoColor]]
    let today: CalendarDate
    let width: CGFloat
    let onPick: (CalendarDate) -> Void
    let onDrop: ((CalendarDate, [String]) -> Bool)?

    /// 닫힘(함수)은 견줄 수 없다 — 부르는 쪽이 매번 새로 만들지만 하는 일은 같다. 값만 견준다.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.center == rhs.center && lhs.destination == rhs.destination && lhs.incoming == rhs.incoming
            && lhs.wings == rhs.wings && lhs.selected == rhs.selected && lhs.marks == rhs.marks
            && lhs.today == rhs.today && lhs.width == rhs.width && (lhs.onDrop == nil) == (rhs.onDrop == nil)
    }

    private struct Slot {
        let month: MonthGrid
        /// 가운데에서 몇 판 옆인가 (−1·0·+1).
        let side: Int
    }

    /// 가운데가 먼저다 — 보조 기술과 UI 시험의 목록 차례. 옆 판은 숨기지만 XCUITest 는 숨긴
    /// 것도 세므로, 「15일」의 첫 짝이 화면 안의 칸이려면 가운데가 앞에 서야 한다. `ZStack` 이라
    /// 차례와 자리가 따로다.
    private var slots: [Slot] {
        guard wings else { return [Slot(month: center, side: 0)] }
        return [Slot(month: center, side: 0), Slot(month: neighbor(-1), side: -1), Slot(month: neighbor(1), side: 1)]
    }

    var body: some View {
        ZStack {
            ForEach(slots, id: \.month.ordinal) { slot in
                panel(slot.month)
                    .frame(width: width)
                    .offset(x: CGFloat(slot.side) * width)
                    // 옆 판은 눈에만 있다. 보조 기술에는 없어야 한다: 화면 밖의 「15일」이 목록에
                    // 서면 VoiceOver 가 거기로 간다. 판을 묶어 숨긴다 — 칸마다 `accessibilityHidden`
                    // 을 주면 옆에서 가운데로 온 판의 칸이 숨김을 벗지 못했다(XCUITest 가 못 누른다).
                    // 판 셋 중 가운데가 먼저 서는 것도 그래서다(`slots`).
                    .accessibilityElement(children: slot.side == 0 ? .contain : .ignore)
                    .accessibilityHidden(slot.side != 0)
                    // 판이 갈릴 때 옆 판은 그냥 바뀐다; 움직임을 줄인 사람의 한 판은 교차 페이드로.
                    .transition(wings ? .identity : .opacity)
            }
        }
        .frame(width: width)
    }

    private func neighbor(_ side: Int) -> MonthGrid {
        incoming == side && destination.ordinal != center.ordinal ? destination : center.advanced(by: side)
    }

    /// 판은 제 달의 점과 고른 날만 받는다 — 옆 달의 점이 갱신되거나 고른 날이 옆 달로 가도
    /// 이 판의 값은 그대로라 다시 그리지 않는다.
    private func panel(_ month: MonthGrid) -> some View {
        let range = month.range
        return MonthPanel(
            month: month,
            selected: selected.flatMap { range?.contains($0) == true ? $0 : nil },
            marks: marks.filter { range?.contains($0.key) == true },
            today: today, onPick: onPick, onDrop: onDrop
        )
        .equatable()
    }
}

// MARK: - 한 판

/// 한 달의 칸들. 달·고른 날·점·오늘이 그대로면 다시 만들지 않는다.
private struct MonthPanel: View, Equatable {
    let month: MonthGrid
    let selected: CalendarDate?
    let marks: [CalendarDate: [MemoColor]]
    let today: CalendarDate
    let onPick: (CalendarDate) -> Void
    let onDrop: ((CalendarDate, [String]) -> Bool)?

    /// 고른 날의 원이 칸에서 칸으로 **미끄러지는** 자리 — 판 하나에 하나. 뚝 옮겨 앉으면 눈이
    /// 새 칸을 다시 찾아야 하고, 미끄러지면 손이 간 곳을 눈이 따라간다 ("Touch and content
    /// should stay together", WWDC18 803). 움직임을 줄인 사람에게는 짧은 페이드 (`Motion.settle(true)`).
    @Namespace private var space

    private static let cell: CGFloat = 44
    /// 소리 이름표의 서식 — 「14일 월요일」 · 「14 Monday」 (`DateWords.dayWeekday` 와 같은 말).
    private static let spokenStyle = Date.FormatStyle(locale: Words.locale, calendar: .current, timeZone: .current)
        .day().weekday(.wide)

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.month == rhs.month && lhs.selected == rhs.selected && lhs.marks == rhs.marks
            && lhs.today == rhs.today && (lhs.onDrop == nil) == (rhs.onDrop == nil)
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(month.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.date) { day in cell(day) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 12)
    }

    private func spoken(_ day: CalendarDate) -> Text {
        guard let date = day.startOfDay() else { return Text(verbatim: day.description) }
        return Text(date, format: Self.spokenStyle)
    }

    @ViewBuilder
    private func cell(_ day: MonthGrid.Day) -> some View {
        if let onDrop {
            cellButton(day).dropDestination(for: String.self) { items, _ in onDrop(day.date, items) }
        } else {
            cellButton(day)
        }
    }

    private func cellButton(_ day: MonthGrid.Day) -> some View {
        let isToday = day.date == today
        let isSelected = day.date == selected
        let inks = marks[day.date] ?? []
        let count = inks.count
        return Button { onPick(day.date) } label: {
            ZStack {
                // 오늘은 채운 원(포레스트 위에 크림 숫자), 고른 날은 옅은 원 — 둘이 같은 칸이면 오늘이 이긴다.
                // 고른 날의 원은 칸 사이를 미끄러진다 (`space`).
                if isToday {
                    Circle().fill(Theme.accent).frame(width: 34, height: 34)
                } else if isSelected {
                    Circle().fill(Theme.accentInk.opacity(0.16))
                        .frame(width: 34, height: 34)
                        .matchedGeometryEffect(id: "picked", in: space)
                }
                Text(String(day.date.day))
                    .font(.body.monospacedDigit().weight(isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(isToday ? Theme.onAccent : Paper.ink)
                    .opacity(day.isOverflow ? 0.4 : 1)
                if count > 0 {
                    // 점 하나가 메모 하나, 색은 그 메모의 것 — 아래 목록의 색 점과 같은 말이라 칸을 누르기
                    // 전에 「무엇이 있는지」가 읽힌다. 셋을 넘으면 셋 — 수를 세게 하지 않는다 (§10.4).
                    // 오늘의 포레스트 원 위에서는 크림 한 색으로 — 색 점이 초록 위에 서면 탁해진다.
                    HStack(spacing: 3) {
                        ForEach(Array(inks.prefix(3).enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(isToday ? Theme.onAccent : color.ink)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .offset(y: 14)
                    .opacity(day.isOverflow ? 0.5 : 1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.cell)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 이름표는 읽힐 때 서식한다 — 126칸의 날짜를 판을 만들 때마다 문자열로 만들면
        // 그것만으로 한 프레임이 넘친다. `Text(date, format:)` 는 값과 서식만 들고 있다.
        .accessibilityLabel(count > 0 ? Text("\(spoken(day.date)), 일정 \(count)") : spoken(day.date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
