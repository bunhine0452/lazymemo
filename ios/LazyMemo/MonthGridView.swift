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
/// 스프링으로 자리 잡는다. 앞선 판은 손을 뗀 뒤에야 격자가 뚝 바뀌어 넘어갔는지
/// 되돌아왔는지 손이 알 길이 없었다 — "Touch and content should stay together
/// and move as one thing" (WWDC18 803).
///
/// 화살표·「오늘」·이웃 달의 칸을 눌러 달이 바뀔 때도 같은 미끄러짐이다. 넘김을
/// 부르는 쪽은 여전히 `onStep`/`onToday` 만 부르고, **정본 `grid` 가 바뀌는 것을
/// 보고** 판이 그리로 미끄러진다 — 손짓이든 단추든 한 길이라 한 물건으로 보인다.
/// 움직임을 줄인 사람에게는 옆으로 밀지 않고 바꿔 끼운다 (HIG Accessibility —
/// "Replacing transitions in x-, y-, and z-axes with fades").
///
/// ## 손가락마다 다시 그리지 않는다
///
/// 손가락이 움직이는 매 프레임 이 뷰의 `body` 가 다시 돈다 (`@GestureState`). 그때
/// 세 판 126칸을 매번 다시 만들면 — 옆 달 산수 둘, 칸마다 소리 이름표의 날짜 서식 —
/// 한 프레임 예산(120Hz 에서 8ms)을 서식만으로 먹어 **살짝 걸리는 느낌**이 났다.
/// 그래서 판은 `Equatable` 인 자식(`MonthStrip`·`MonthPanel`)이고, 프레임마다 바뀌는
/// 것은 그 바깥의 `offset` 뿐이다 — 달·점·고른 날이 그대로면 SwiftUI 가 판의 `body`
/// 를 건너뛴다. 소리 이름표도 문자열이 아니라 `Text(date, format:)` 로 두어
/// 읽힐 때 서식한다.
struct MonthGridView: View {
    let grid: MonthGrid
    let selected: CalendarDate?
    /// 날짜별 일정 수 — 잉크의 세기.
    var marks: [CalendarDate: Int] = [:]
    var today: CalendarDate = CalendarDate(Date())
    var onPick: (CalendarDate) -> Void
    var onStep: (Int) -> Void
    var onToday: () -> Void
    /// 줄을 끌어다 칸에 놓았을 때 — 메모 id 문자열들. `nil` 이면 놓을 수 없는 격자(시트).
    var onDrop: ((CalendarDate, [String]) -> Bool)?

    private static let cell: CGFloat = 44
    /// 여섯 주 — 5주·6주를 오가도 아래가 흔들리지 않는 예약.
    private static let gridHeight: CGFloat = cell * 6 + 4 * 5
    /// 요일 일곱 자. **`static` 이다** — 인스턴스 속성으로 두면 부모가 다시
    /// 그릴 때마다 `Calendar` 를 뜨고 일곱 자를 다시 서식한다. 말은 앱이 도는
    /// 동안 바뀌지 않는다.
    private static let weekdays = DateWords.weekdayLetters()

    // MARK: 넘김

    /// 손가락이 붙어 있는 동안의 것 — 떼거나 빼앗기면(시트가 내려가거나 목록이 스크롤을
    /// 가져가면) **스스로 제자리로** 돌아간다. `@State` 로 두면 빼앗긴 손짓은 `onEnded` 가
    /// 안 와서 판이 옆으로 밀린 채 굳는다.
    private struct Touch {
        /// 첫 움직임으로 정한 축. 세로면 이 손짓은 격자의 것이 아니다.
        var axis: Axis?
        /// 손가락이 민 거리.
        var offset: CGFloat = 0
    }

    /// 아직 화면에 놓인 달. 정본 `grid` 와 다르면 그리로 미끄러지는 중이다 — 다 가면 비운다.
    @State private var shown: MonthGrid?
    /// 손가락. 놓으면 `settle` 로 0 으로 돌아온다 — 되돌아오는 움직임은 그것으로 족하다.
    @GestureState(initialValue: Touch(), reset: { _, transaction in transaction.animation = Self.settle })
    private var touch
    /// 미끄러지는 판의 자리. 손가락 몫(`touch.offset`)과 더해 그린다 — 넘길 때 둘이 같은
    /// 곡선으로 하나는 0 으로, 하나는 한 판만큼으로 가서 합은 손이 놓은 자리에서 이어진다.
    @State private var drag: CGFloat = 0
    /// 들어오는 달이 어느 쪽에서 오는가 (+1 오른쪽, −1 왼쪽). `nil` 이면 쉬는 중.
    @State private var incoming: Int?
    /// 판 하나의 폭 — 놓을 때 「반을 넘었는가」 를 재는 자.
    @State private var width: CGFloat = 0
    /// 미끄러짐마다 하나씩. 끝맺음이 제 것인지 확인한다 — 중간에 새 손짓이 끼어들면 앞 것은 버린다.
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 놓은 뒤 자리 잡는 속도. 튕기지 않는다 — 판 셋 너머는 빈 자리라 넘치면 흰 띠가 비친다.
    /// 값은 앱이 함께 쓰는 낱말에서 온다 (`Motion.settle`).
    private static let settle: Animation = Motion.settle
    /// 손가락이 이 만큼 가야 격자의 손짓이다 — 칸 누르기와 가르는 문턱.
    private static let slack: CGFloat = 12

    private var current: MonthGrid { shown ?? grid }

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
                .updating($touch, body: follow)
                .onEnded(release)
        )
        .onChange(of: grid) { old, new in
            guard Self.ordinal(old) != Self.ordinal(new) else { return }
            slide(from: old, to: new)
        }
        // 달이 넘어간 순간 손끝에 한 번. 판이 미끄러지는 데 0.3초가 걸리므로
        // 눈보다 손이 먼저 «넘어갔다» 를 안다 — HIG Feedback 「Feedback helps us
        // to operate cars confidently」. 튕겨 되돌아온 손짓에는 울리지 않는다:
        // 정본이 안 바뀌었기 때문이다.
        .sensoryFeedback(.selection, trigger: Self.ordinal(grid))
    }

    /// 세 판 — 앞·이번·다음. 화면 가장자리에서 자른다 (안쪽 여백에서 자르면 들어오는
    /// 달이 여백 밖에서 뚝 나타난다).
    private var pages: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            MonthStrip(
                current: current, destination: grid, incoming: incoming,
                selected: selected, marks: marks, today: today, width: width,
                onPick: onPick, onDrop: onDrop
            )
            .equatable()
            // 프레임마다 바뀌는 것은 이것뿐이다 — 판은 위에서 같다고 보면 다시 그리지 않는다.
            .offset(x: -width + touch.offset + drag)
        }
        .frame(height: Self.gridHeight)
        .clipped()
        // 판 하나의 폭은 이 자리의 폭이다 — 세 판을 이은 줄의 폭(셋 곱)이 아니라.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    // MARK: 손짓

    private func follow(_ value: DragGesture.Value, touch: inout Touch, _: inout Transaction) {
        if touch.axis == nil {
            touch.axis = Self.isSideways(value) ? .horizontal : .vertical
        }
        guard touch.axis == .horizontal else { return }
        // 미끄러지는 도중에 다시 잡으면 앞 것은 그 자리에 놓고 새 손짓을 따른다 —
        // "Allow for constant redirection and interruption" (WWDC18 803).
        if incoming != nil {
            generation += 1
            land()
        }
        // 움직임을 줄인 사람에게는 판이 손을 따라가지 않는다. 놓을 때의 판정은 같다.
        guard !reduceMotion else { return }
        touch.offset = min(max(value.translation.width, -width), width)
    }

    private static func isSideways(_ value: DragGesture.Value) -> Bool {
        abs(value.translation.width) > abs(value.translation.height)
    }

    private func release(_ value: DragGesture.Value) {
        // 손가락은 여기서 이미 돌아가는 중이다 (`touch` 의 reset). 넘기지 않으면 그것으로 끝.
        guard Self.isSideways(value), width > 0 else { return }
        // 손이 멈춘 자리가 아니라 **흘러갈 자리**로 판정한다 — 짧고 빠른 튕김도 넘어가고,
        // 반 넘게 끌고 되돌아온 손은 되돌아온다 (시스템 페이징과 같은 문턱, 반).
        let predicted = value.predictedEndTranslation.width
        let sameWay = (predicted < 0) == (value.translation.width < 0)
        guard sameWay, abs(predicted) > width / 2 else { return }
        // 정본을 바꾼다 — 판은 `onChange(of: grid)` 에서 지금 자리에서 이어 미끄러진다.
        onStep(predicted < 0 ? 1 : -1)
    }

    /// 정본이 바뀌었다 — 옛 달을 붙든 채 새 달을 옆에서 들여온다.
    private func slide(from old: MonthGrid, to new: MonthGrid) {
        generation += 1
        let mine = generation
        let side = Self.ordinal(new) > Self.ordinal(old) ? 1 : -1
        shown = old
        if reduceMotion {
            // 다음 틱에 바꿔 끼운다 — 같은 갱신 안에서 갈아 끼우면 옛 달이 한 번도 안 그려져 바뀔 것이 없다.
            Task { @MainActor in
                guard generation == mine else { return }
                withAnimation(Motion.crossFade) { shown = nil }
                incoming = nil
                drag = 0
            }
            return
        }
        incoming = side
        withAnimation(Self.settle) {
            drag = CGFloat(-side) * width
        } completion: {
            guard generation == mine else { return }
            land()
        }
    }

    /// 다 갔다 — 정본이 가운데에 선다. **움직임 없이** 자리를 바꿔야 한 프레임도 안 튄다:
    /// 옆 칸에 있던 새 달이 가운데 칸으로 옮겨 앉는 것과 판이 제자리로 돌아오는 것이 서로를 지운다.
    private func land() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shown = nil
            incoming = nil
            drag = 0
        }
    }

    private static func ordinal(_ grid: MonthGrid) -> Int { grid.year * 12 + grid.month }

    // MARK: 머리

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // 제목은 정본이다 — 넘기기로 한 순간 바뀐다. 「어디로 가는가」를 판보다 먼저 말한다.
            Text(DateWords.month(grid.month))
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
        .animation(Motion.quick(reduceMotion), value: Self.ordinal(grid))
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

// MARK: - 세 판

/// 앞·이번·다음 세 판 — 손가락이 미는 동안 **같다고 보이면 다시 그리지 않는** 단위.
///
/// 옆 판의 달은 여기서 셈한다(`neighbor`) — 부모가 프레임마다 셈하면 달 산수 둘이
/// 매 프레임 든다. 들어오는 달이 정해져 있으면 그것이 옆에 선다 — 「오늘」로 멀리 갈
/// 때 그 사이 달을 다 지나지 않고 목적지가 바로 옆에서 들어온다.
private struct MonthStrip: View, Equatable {
    let current: MonthGrid
    /// 정본 — 미끄러지는 중이면 목적지.
    let destination: MonthGrid
    let incoming: Int?
    let selected: CalendarDate?
    let marks: [CalendarDate: Int]
    let today: CalendarDate
    let width: CGFloat
    let onPick: (CalendarDate) -> Void
    let onDrop: ((CalendarDate, [String]) -> Bool)?

    /// 닫힘(함수)은 견줄 수 없다 — 부르는 쪽이 매번 새로 만들지만 하는 일은 같다. 값만 견준다.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.current == rhs.current && lhs.destination == rhs.destination && lhs.incoming == rhs.incoming
            && lhs.selected == rhs.selected && lhs.marks == rhs.marks && lhs.today == rhs.today
            && lhs.width == rhs.width && (lhs.onDrop == nil) == (rhs.onDrop == nil)
    }

    var body: some View {
        HStack(spacing: 0) {
            wing(neighbor(-1))
            ZStack {
                panel(current)
                    .id(current.year * 12 + current.month)
                    .transition(.opacity)
            }
            .frame(width: width)
            wing(neighbor(1))
        }
    }

    private func neighbor(_ side: Int) -> MonthGrid {
        incoming == side ? destination : current.advanced(by: side)
    }

    /// 옆 판 — 눈에만 있다. 보조 기술과 UI 시험에는 없어야 한다: 화면 밖의 「15일」이 목록에
    /// 서면 VoiceOver 가 거기로 가고, 시험은 그것을 먼저 집어 누르지 못한다 (`accessibilityHidden`
    /// 만으로는 칸들이 남았다 — 묶어서 지운다).
    private func wing(_ month: MonthGrid) -> some View {
        panel(month)
            .frame(width: width)
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(true)
    }

    private func panel(_ month: MonthGrid) -> some View {
        MonthPanel(month: month, selected: selected, marks: marks, today: today, onPick: onPick, onDrop: onDrop)
            .equatable()
    }
}

// MARK: - 한 판

/// 한 달의 칸들. 달·고른 날·점·오늘이 그대로면 다시 만들지 않는다.
private struct MonthPanel: View, Equatable {
    let month: MonthGrid
    let selected: CalendarDate?
    let marks: [CalendarDate: Int]
    let today: CalendarDate
    let onPick: (CalendarDate) -> Void
    let onDrop: ((CalendarDate, [String]) -> Bool)?

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
                    ForEach(week) { day in cell(day) }
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
        let count = marks[day.date] ?? 0
        return Button { onPick(day.date) } label: {
            ZStack {
                if isToday {
                    Circle().fill(Theme.accent).frame(width: 34, height: 34)
                } else if isSelected {
                    Circle().fill(Theme.accentInk.opacity(0.16)).frame(width: 34, height: 34)
                }
                Text(String(day.date.day))
                    .font(.body.monospacedDigit().weight(isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(isToday ? Theme.onAccent : Paper.ink)
                    .opacity(day.isOverflow ? 0.4 : 1)
                if count > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(count, 3), id: \.self) { _ in
                            Circle().fill(isToday ? Theme.onAccent : Theme.highlightInk).frame(width: 4, height: 4)
                        }
                    }
                    .offset(y: 13)
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
