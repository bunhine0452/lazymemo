import LazyMemoCore
import SwiftUI

/// 「달력」 — 바탕화면에 놓인, **손으로 만지는** 달 (설계문서 §10).
///
/// 앞선 판은 아래로 흐르는 목록이었고 조작이 하나도 없었다. 게으른 사람이
/// 달력에 하는 일은 셋뿐인데 — **보고, 옮기고, 미룬다** — 그 셋 중 어느 것도
/// 할 수 없는 화면이었다는 뜻이다. 그래서 통째로 바꿨다.
///
/// 화면은 두 층이다. 위는 **조망**(어느 날이 붐비는가), 아래는 **조작**(그 날의
/// 일을 집어 옮긴다). 두 층이 한 창에 있어야 "31일로 옮기기" 가 한 동작이 된다 —
/// 목록만 있으면 날짜를 글자로 쳐야 하고, 격자만 있으면 무엇을 옮기는지 알 수 없다.
///
/// 격자가 빈칸을 보여주는 것은 철학 1("완성을 요구하지 않는다")과 부딪히지
/// 않는다. **빈칸이 아니라 바탕이다** — 15일이 무슨 요일인지는 그 사이 빈 칸들이
/// 말해 준다. 채우라고 말하는 것은 빈 칸이 아니라 "일정 없음" 같은 글자와
/// 칸마다 붙은 ＋ 표시이고, 그런 것은 여기에 하나도 없다.
///
/// ## 생김새를 다시 지었다 — 부품이 아니라 펜 자국
///
/// 동사는 맞게 서 있었는데 **생김새가 남의 것이었다.** 채운 원(오늘), 테두리
/// 원(고른 날), 캡슐 점(밀도), `‹ ›`(달 이동), 1px 실선(두 층의 경계) — 전부
/// 맞는 표시였고 전부 **어느 앱에나 있는 표시**였다. 이 앱은 재질이 하나(좋은
/// 종이)인데 그 위에 놓인 표시만 UI 부품이면 달력만 남의 물건으로 읽힌다.
///
/// 그래서 달력이 쓰는 낱말을 종이 위의 몸짓으로 다시 적었다 (`PenMarks`).
///
/// | 뜻 | 버린 것 | 지금 |
/// |---|---|---|
/// | 오늘 | 채운 노란 원 + 검은 숫자 | 손으로 그린 동그라미 + 안쪽에 스민 호박색 |
/// | 고른 날 | 회색 원 + 테두리 | 밑줄 |
/// | 놓을 자리 | 작은 파란 고리 | 칸 전체가 눌린다 (착지 판정 범위와 같다) |
/// | 붐비는 날 | 캡슐 점 셋, 넷부터는 막대 | 숫자 아래에 번진 잉크 |
/// | 달 이동 | `‹ ›` | 이웃 달의 **이름** (`MonthStrip`) |
/// | 두 층의 경계 | 1px 실선 | 접힌 자리 (`PaperCrease`) — 한 장임을 말한다 |
/// | 다음 한 줄 | `＋ 이 날에 적기` | 비워 둔 줄 |
/// | 지난 날 | 일괄 55% | 하루씩 마른다 (`InkDrying`) |
///
/// ## 판형이 둘이다 — 세로로 선 창, 가로로 누운 창
///
/// 배치가 하나뿐이면 **창 크기가 장식이 된다.** 세로로 늘려도 격자는 창 위에
/// 붙은 작은 표로 남았고(주 높이가 36pt 로 못 박혀 있었다), 가로로 넓히면
/// 칸만 납작하게 늘어나면서 정작 조작하는 면은 창 아래 눌린 띠였다 — 폭은
/// 남아도는데 목록은 좁은 그대로다.
///
/// 그래서 창이 충분히 넓으면 **두 면을 나란히** 놓는다. 왼쪽은 달, 오른쪽은
/// 그 날이고, 접힌 자리도 함께 세로로 선다 — 종이를 반으로 접을 때 긴 쪽을
/// 따라 접는 것과 같다. 주 높이·펜 자국·숫자 크기는 두 판형 모두에서 창을
/// 따라 자란다 (`CalendarLayout`).
///
/// 값이 싸진 것도 있다. 얼룩은 칸마다 도형을 두지 않고 격자 전체에 `Canvas`
/// 한 장으로 그리므로(`InkBleedLayer`) 앞선 판의 캡슐 점보다 **레이어가 적다**
/// (설계문서 §14.8).
struct CalendarView: View {
    @Bindable var model: CalendarModel
    var onClose: () -> Void
    var onSelectMemo: (ULID) -> Void
    /// 화면 밖 렌더에서만 채운다 (`PreviewRenderer`).
    ///
    /// 끌고 있는 모습·포인터가 올라온 줄·적는 중인 상자는 **포인터가 있어야만**
    /// 나타난다. 화면 기록 권한 없이 UI 를 확인하는 이 저장소에서는 그 상태들이
    /// 영영 눈에 띄지 않고, 그러면 이 화면에서 새로 만든 조작이 통째로
    /// 미확인으로 남는다 (설계문서 §8.1 의 세 번 틀린 이야기와 같은 함정).
    var staged: Staged?

    /// 집어 든 일정. 격자 위로 끌고 가는 동안만 존재한다.
    private struct Grip: Equatable {
        let memo: Memo
        var point: CGPoint
        var cell: Int?
        /// 손이 실제로 움직였는가. 안 움직였으면 그것은 끌기가 아니라 누르기다.
        var isDragging: Bool
    }

    /// 좌표 이름. `onGeometryChange` 의 클로저가 격리 밖이라 nonisolated 여야 한다.
    private nonisolated static let space = "calendar"
    private static let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    // 주 높이(36pt)와 펜 자국의 지름(18pt)은 여기 못 박혀 있었다. 기본 창에서는
    // 맞았지만 창을 키워도 그대로 남아서 큰 창일수록 달이 작아 보였다. 지금은
    // 창이 정한다 (`CalendarLayout`) — 다만 아래쪽은 여전히 막아 둔다. 이 높이는
    // 미관이 아니라 **겨냥**의 문제이기도 해서, 칸이 좁아지면 끌어다 놓기가
    // 조준 게임이 된다.

    /// 끌어서 놓을 때 제목 대신 보이는 조각의 최대 글자 수.
    private static let chipLimit = 14

    struct Staged {
        var hoveredRow: ULID?
        var carrying: Memo?
        var carryPoint: CGPoint = .zero
        var target: CalendarDate?
        var writing = false
        var draft = ""
        /// 종이에서 건너와 놓을 날을 기다리는 메모 (설계문서 §7.2).
        var holding: Memo?
    }

    /// 세로로 선 접힌 자리가 창의 어디에서 시작하는가. 격자에서 잰 y 를 그
    /// 자리의 지역 좌표로 옮기는 데 쓴다.
    @State private var creaseOrigin: CGFloat = 0
    @State private var isHovering = false
    @State private var hoveredRow: ULID?
    @State private var grip: Grip?
    @State private var geometry = MonthGridGeometry(frame: .zero, rows: 0)
    /// 놓을 자리를 겨누는 동안의 포인터. 끌기가 아니라 **들고 온** 경우다.
    @State private var aimPoint: CGPoint?
    @State private var aimCell: Int?
    @State private var isWriting = false
    @State private var draft = ""
    @FocusState private var writerFocused: Bool
    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        // 창을 `GeometryReader` 로 받는다. `onGeometryChange` 로 스스로를 재면
        // **내용의 크기**가 돌아온다 — 격자가 창보다 커진 순간 그 큰 값이 다시
        // 판형에 들어가 격자가 한 번 더 자라는 되먹임이 생긴다 (실제로 그렇게
        // 됐다: 620×360 창에서 머리가 통째로 잘려 나갔다). 리더는 언제나
        // **제안된 크기**를 주므로 그 고리가 끊긴다.
        GeometryReader { proxy in
            let plan = CalendarLayout.resolve(size: proxy.size, rows: model.grid.weeks.count)
            VStack(spacing: 0) {
                header
                switch plan.shape {
                case .tall: standing(plan)
                case .wide: lying(plan)
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .background(Theme.paper(MemoColor.gray.ink, dotted: false))
        .overlay(Theme.edge())
        .overlay { carriedChip }
        .overlay { HoverSensor { isHovering = $0 } }
        .animation(Theme.reveal, value: isHovering)
        .animation(Theme.reveal, value: pointedRow)
        .animation(Theme.reveal, value: dropTarget)
        .animation(Theme.settle, value: model.selected)
        .task { await model.refresh() }
        .onChange(of: model.selected) { closeWriter() }
    }

    // MARK: 판형

    /// 세로로 선 창 — 위는 달, 아래는 그 날. 접힌 자리가 가로로 눕는다.
    private func standing(_ plan: CalendarLayout) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                weekdayRow(plan)
                monthGrid(plan)
            }
            .padding(.horizontal, Theme.normal)

            crease(.horizontal)
                .padding(.top, Theme.tight)

            dayPanel(plan)
        }
    }

    /// 가로로 누운 창 — 왼쪽은 달, 오른쪽은 그 날.
    ///
    /// 넓어진 폭을 격자와 목록이 **나눠 갖는다.** 한 판형만 있을 때 넓은 창이
    /// 못 쓰게 되던 이유가 이것이다 — 폭은 늘어나는데 목록의 폭은 그대로였다.
    /// 격자는 세로로도 남는 높이를 거의 다 쓴다. 접힌 자리가 세로로 서므로
    /// 아래에 자리를 비워 둘 이유가 없다.
    private func lying(_ plan: CalendarLayout) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                weekdayRow(plan)
                monthGrid(plan)
                Spacer(minLength: 0)
            }
            .padding(.leading, Theme.normal)

            crease(.vertical)
                .padding(.horizontal, Theme.tight / 2)

            dayPanel(plan)
                .frame(width: plan.panelWidth)
        }
        .padding(.bottom, Theme.snug)
    }

    /// 접힌 자리. 가리키는 것은 두 판형에서 같다 — **고른 날이 앉은 칸**이다.
    /// 세로로 선 창에서는 그 칸의 열을, 가로로 누운 창에서는 그 칸의 행을
    /// 가리킨다.
    private func crease(_ axis: PaperCrease.Axis) -> some View {
        PaperCrease(
            axis: axis,
            // 접힌 자리는 제 지역 좌표로 그린다. 세로로 설 때는 머리 아래에서
            // 시작하므로, 격자에서 잰 y 에서 그만큼을 빼야 자리가 맞는다.
            pointer: axis == .horizontal
                ? selectedCell?.midX
                : selectedCell.map { $0.midY - creaseOrigin }
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named(Self.space)).minY
        } action: { origin in
            creaseOrigin = origin
        }
    }

    // MARK: 머리

    /// 머리 — **달 이름이 곧 이동 버튼이다.**
    ///
    /// `‹ ›` 를 버렸다. 어느 앱에나 있는 부품이라 이 창이 무엇으로 만들어졌는지
    /// 말해 주지 않고, 무엇보다 **어디로 가는지 이름을 대지 않는다.** 이웃 달을
    /// 옅게 적어 두면 시간이 양옆으로 뻗어 있는 것이 그대로 보이고, 누르는
    /// 자리가 곧 도착지의 이름이 된다 (철학 2 — 시간이 유일한 구조).
    private var header: some View {
        HStack(spacing: Theme.tight) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                monthStep(-1)

                Text("\(model.grid.month)월")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Paper.ink)
                    .contentTransition(.numericText())

                monthStep(1)
            }

            Spacer(minLength: Theme.tight)

            // 해는 종이 귀퉁이에 적힌 것처럼. 달을 넘기다 해가 바뀔 때만 눈에 든다.
            Text(verbatim: "\(model.grid.year)")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(Paper.ink.opacity(0.26))

            // 오늘로 돌아오는 길은 길을 잃었을 때만 나타난다.
            if !model.isOnToday {
                Button("오늘") { model.goToday() }
                    .buttonStyle(.plain)
                    .spoken("오늘 — 오늘이 든 달로 돌아갑니다")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.highlightInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.highlightWash))
            }

            if isHovering {
                QuietButton(symbol: "xmark", help: "치우기 — 달력을 닫습니다", action: onClose)
            }
        }
        .padding(.horizontal, Theme.normal)
        // 판형이 셈에 쓴 높이를 화면이 그대로 지킨다. 여기가 몇 pt 어긋나면
        // 격자가 창을 넘고, 넘은 만큼은 잘려서 안 보인다.
        .frame(height: CalendarLayout.headerHeight)
    }

    /// 이웃 달. 평소엔 종이에 스민 정도로만 있다가 손이 오면 또렷해진다 (철학 4).
    private func monthStep(_ delta: Int) -> some View {
        let month = MonthStrip.neighbor(of: model.grid.month, by: delta)
        return Button { model.stepMonth(delta) } label: {
            Text("\(month)월")
                .font(.system(size: 11))
                .foregroundStyle(Paper.ink.opacity(isHovering ? 0.40 : 0.20))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .spoken("\(month)월 — \(delta < 0 ? "이전 달로" : "다음 달로") 넘깁니다")
    }

    private func weekdayRow(_ plan: CalendarLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { column, symbol in
                Text(symbol)
                    // 칸이 커지면 요일도 함께 큰다. 격자만 자라고 머리글이
                    // 그대로면 큰 창에서 요일 줄이 잔글씨로 남는다.
                    .font(.system(size: plan.shape == .wide ? 10.5 : 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(
                        columnColor(column).opacity(column == 0 || column == 6 ? 0.85 : 0.65)
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        // 판형이 셈에 쓴 높이와 화면의 높이가 같아야 격자가 창을 넘지 않는다.
        // 남는 몇 pt 는 아래 여백이 된다 — 요일과 첫 줄이 붙지 않게.
        .frame(height: CalendarLayout.weekdayHeight, alignment: .top)
    }

    // MARK: 달 격자 — 조망

    private func monthGrid(_ plan: CalendarLayout) -> some View {
        // 마른 정도와 얼룩을 **한 번에 훑어 둔다.** 칸마다 다시 세면 42번을
        // 42번 반복하게 된다.
        let ink = monthInk

        return VStack(spacing: 0) {
            ForEach(Array(model.grid.weeks.enumerated()), id: \.offset) { row, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                        cell(
                            day, column: column, plan: plan,
                            presence: ink.presence[row * MonthGridGeometry.columns + column]
                        )
                    }
                }
            }
        }
        // 붐비는 날의 얼룩은 칸이 아니라 **격자 전체에 한 장으로** 그린다
        // (`InkBleedLayer`). 얼룩이 칸 경계를 조금 넘어가는 것도 여기서 온다.
        .background {
            InkBleedLayer(rows: model.grid.weeks.count, stains: ink.stains, week: ink.week)
        }
        // 칸마다 자리를 묻지 않고 격자 하나만 잰다 — 나머지는 산수다
        // (`MonthGridGeometry`). 화면에 뷰 42개를 더 만들지 않기 위한 선택이다.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.space))
        } action: { frame in
            geometry = MonthGridGeometry(frame: frame, rows: model.grid.weeks.count)
        }
        .onChange(of: model.grid.weeks.count) { _, rows in
            geometry.rows = rows
        }
        .overlay { aimSensor }
    }

    /// 들고 온 메모를 겨누는 동안에만 붙는 포인터 감지기.
    ///
    /// 끌어다 놓기는 제스처가 좌표를 주지만, 종이에서 건너온 것은 손이 이미
    /// 마우스를 놓은 뒤다 — 어디를 가리키고 있는지 물을 곳이 없다. 그렇다고
    /// 늘 달아 두면 움직임 이벤트를 계속 받게 되므로 (`.activeAlways` 라 앱이
    /// 뒤에 있어도 온다) **들고 있는 동안에만** 단다.
    ///
    /// `.onContinuousHover` 를 쓰지 않는 이유는 `HoverSensor` 와 같다 —
    /// SwiftUI 의 hover 는 키 윈도에서만 반응하는데, 이 창은 종이의 버튼을
    /// 누르고 건너온 참이라 키를 잡고 있지 않다 (설계문서 §7.1).
    @ViewBuilder
    private var aimSensor: some View {
        if holding != nil {
            HoverSensor { inside in
                guard !inside else { return }
                aimPoint = nil
                aimCell = nil
            } onMove: { local in
                // 감지기는 격자를 그대로 덮고 있다. 격자의 자리를 더하면
                // 착지 판정이 쓰는 좌표계(`MonthGridGeometry`)와 같아진다.
                let point = CGPoint(
                    x: geometry.frame.minX + local.x, y: geometry.frame.minY + local.y
                )
                aimPoint = point
                aimCell = geometry.index(at: point)
            }
        }
    }

    /// 한 칸. **표시가 셋뿐이고 셋 다 펜 자국이다.**
    ///
    /// - 오늘: 손으로 그린 동그라미 (`HandRing`) + 스민 호박색
    /// - 고른 날: 밑줄 (`HandUnderline`)
    /// - 놓을 자리: 칸 전체가 눌린다
    ///
    /// 놓을 자리만 면으로 말하는 이유는 **손이 이미 움직이는 중**이기 때문이다.
    /// 작은 고리는 겨냥한 다음에야 보이고, 그때는 이미 늦다. 그리고 칸 전체가
    /// 곧 착지 판정 범위라 (`MonthGridGeometry`) 보이는 것과 되는 것이 같아진다.
    private func cell(
        _ day: MonthGrid.Day, column: Int, plan: CalendarLayout, presence: Double
    ) -> some View {
        let isToday = model.isToday(day.date)
        let isSelected = day.date == model.selected
        let isTarget = dropTarget == day.date

        return ZStack {
            if isTarget {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.accent.opacity(0.13))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1.5)
            }

            if isToday {
                // 동그라미 안쪽에 색이 스며 있다. 획만으로는 흘긋 볼 때
                // 안 잡히고, 채운 원은 다시 UI 부품이 된다.
                Ellipse()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: Theme.highlightWash, location: 0),
                            .init(color: Theme.highlightWash, location: 0.55),
                            .init(color: Theme.highlightWash.opacity(0), location: 1),
                        ],
                        center: .center, startRadius: 0, endRadius: plan.markSize * 0.67
                    ))
                    .frame(width: plan.markSize * 1.33, height: plan.markSize * 1.06)
                // 획의 굵기도 지름을 따라간다. 굵기를 못 박아 두면 큰 칸에서
                // 동그라미가 가는 철사처럼 보인다.
                HandRing(
                    seed: day.date.penSeed,
                    startWidth: plan.markSize * 0.10,
                    endWidth: plan.markSize * 0.039
                )
                .fill(Theme.highlightInk)
                .frame(width: plan.markSize * 1.44, height: plan.markSize * 1.17)
            }

            Text("\(day.date.day)")
                .font(
                    .system(size: plan.numeralSize, weight: isToday ? .semibold : .regular)
                        .monospacedDigit()
                )
                .foregroundStyle(numeralColor(column: column, isTarget: isTarget, presence: presence))
                .offset(y: -0.5)

            // 오늘이면서 고른 날일 때 — 창을 열면 늘 그렇다 — 밑줄을 겹치지
            // 않는다. 동그라미가 이미 그 칸을 가리키고 있고, 둘이 겹치면
            // 꼬리와 밑줄이 엉켜 두 표시가 다 안 읽힌다.
            if isSelected, !isToday {
                // 숫자에 **바짝 붙인다.** 아래로 내리면 얼룩과 같은 높이에
                // 앉아 둘이 한 덩어리로 뭉치고, 그러면 밑줄도 얼룩도 아닌
                // 검댕이 된다. 폭도 숫자만큼만 — 얼룩보다 좁아야 갈린다.
                HandUnderline(
                    seed: day.date.penSeed,
                    startWidth: plan.markSize * 0.094,
                    endWidth: plan.markSize * 0.028
                )
                .fill(Paper.ink.opacity(0.62))
                .frame(width: plan.markSize * 0.89, height: plan.markSize * 0.17)
                .offset(y: plan.markSize * 0.40)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: plan.weekHeight)
        .contentShape(.rect)
        .onTapGesture {
            // 들고 온 것이 있으면 누르기는 **놓기**다. 날짜를 글자로 치는
            // 대신 자리로 가리키는 것이 이 창의 유일한 방법이어야 한다.
            if holding != nil {
                Task { await model.place(on: day.date) }
            } else {
                model.select(day.date)
            }
        }
        .help(holding != nil ? "\(dayText(day.date))에 놓기" : dayHelp(day.date))
        // 칸은 숫자 하나뿐이라 "몇 월 며칠 · 몇 개" 를 소리로 따로 적는다.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(dayHelp(day.date)))
        .accessibilityHint(Text(holding != nil ? "여기에 놓기" : "이 날 펼치기"))
    }

    /// 달 한 장치의 잉크 — 칸마다 마른 정도와, 붐비는 날의 얼룩.
    ///
    /// 격자를 한 번만 훑는다. 두 값이 같은 순회에서 나오므로 얼룩도 지난 날이면
    /// 함께 마른다 — 표시와 바탕이 따로 늙으면 그 칸만 어색해진다.
    private struct MonthInk {
        var presence: [Double]
        var stains: [InkBleedLayer.Stain]
        /// 오늘이 든 주. 다른 달을 보고 있으면 `nil` — 그 달에는 「이번 주」가 없다.
        var week: Int?
    }

    private var monthInk: MonthInk {
        // 이 달에 오늘이 없다면 **일부러 찾아온 달**이다. 읽으려는 뜻이 곧
        // 되살리는 신호이므로 (철학 3) 아무것도 말리지 않는다.
        let anchor = model.grid.days.firstIndex { $0.date == model.today }
        var presence: [Double] = []
        var stains: [InkBleedLayer.Stain] = []
        presence.reserveCapacity(model.grid.days.count)

        for (index, day) in model.grid.days.enumerated() {
            let alive: Double
            if day.isOverflow {
                alive = 0.24
            } else if let anchor {
                alive = InkDrying.presence(daysAgo: anchor - index)
            } else {
                alive = 1
            }
            presence.append(alive)

            let memos = model.memos(on: day.date)
            guard !memos.isEmpty else { continue }
            stains.append(InkBleedLayer.Stain(
                index: index,
                inks: memos.prefix(InkBleed.maxInks).map(\.color.ink),
                count: memos.count,
                presence: alive
            ))
        }
        return MonthInk(
            presence: presence,
            stains: stains,
            week: anchor.map { $0 / MonthGridGeometry.columns }
        )
    }

    /// 고른 날이 격자에서 앉은 칸. 접힌 자리는 이 칸을 가리킨다 — 목록이 격자의
    /// 어디에서 나왔는지 날짜를 되읽지 않고 알 수 있다.
    private var selectedCell: CGRect? {
        guard geometry.frame.width > 0, geometry.rows > 0,
              let index = model.grid.days.firstIndex(where: { $0.date == model.selected })
        else { return nil }
        return geometry.frame(of: index)
    }

    // MARK: 고른 날 — 조작

    private func dayPanel(_ plan: CalendarLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeading(plan)

            rowList

            if let holding {
                holdLine(holding)
            } else if let failure = model.failure {
                Text(failure)
                    .font(Theme.micro)
                    .foregroundStyle(Theme.sunday)
                    .lineLimit(2)
                    .padding(.top, 4)
            } else if let deleted = model.lastDeleted {
                deleteUndoLine(deleted)
            } else if let move = model.lastMove {
                undoLine(move)
            }
        }
        // 세로로 선 창에서는 접힌 자리가 위에 있으므로 양옆이 같고, 가로로
        // 누운 창에서는 접힌 자리가 **왼쪽**이라 그쪽 여백이 짧다.
        .padding(.leading, plan.shape == .wide ? Theme.snug : Theme.normal)
        .padding(.trailing, Theme.normal)
        .padding(.top, Theme.snug)
        .padding(.bottom, Theme.snug)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 접힌 자리 너머는 **적는 면**이다. 메모가 놓이는 종이와 같은 점
        // 그리드를 깔아, 저쪽은 달을 보는 곳 이쪽은 쓰는 곳이라고 재질로 말한다.
        .background { DotGrid(color: Paper.ink.opacity(0.10), inset: Theme.snug) }
    }

    /// 고른 날의 머리 — **판형마다 다른 물건이다.**
    ///
    /// 세로로 선 창에서는 목록 위의 한 줄이면 된다. 바로 위 격자에 그 날이
    /// 동그라미와 밑줄로 이미 서 있고, 접힌 자리의 자국이 그 열을 가리키고
    /// 있으니 여기서 다시 크게 적으면 같은 말을 두 번 하는 것이다.
    ///
    /// 가로로 누운 창에서는 사정이 다르다. 오른쪽 면이 제 폭을 가진 **하나의
    /// 면**이 되므로 그 면에 제목이 필요하고, 눈이 격자에서 옆으로 건너오는
    /// 거리도 멀다. 그래서 날짜를 크게 적는다 — 건너온 눈이 처음 닿는 것이
    /// "며칠" 이어야 한다.
    @ViewBuilder
    private func dayHeading(_ plan: CalendarLayout) -> some View {
        switch plan.shape {
        case .tall:
            Text(dayTitle)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Paper.ink.opacity(0.56))
                .padding(.bottom, 6)

        case .wide:
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(model.selected.day)")
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Paper.ink.opacity(0.84))
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 1) {
                    Text(weekdayName(model.selected))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Paper.ink.opacity(0.56))
                    Text("\(model.selected.month)월")
                        .font(.system(size: 9))
                        .foregroundStyle(Paper.ink.opacity(0.30))
                }

                Spacer(minLength: 0)

                // 오늘은 머리에서 이미 한 번 말했지만, 넓은 창에서는 눈이
                // 격자를 건너와 여기에 오래 머문다. 그 자리에서 "지금" 이
                // 어디인지 다시 잡아 준다.
                if model.isToday(model.selected) {
                    Text("오늘")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.highlightInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.highlightWash))
                }
            }
            .padding(.bottom, 9)
        }
    }

    /// 적기 줄은 **목록의 마지막 줄**이다. 판 바닥에 못 박아 두면 마지막
    /// 일정과 사이가 벌어져 다른 물건처럼 보인다 — 한 줄 더 적는 자리여야 한다.
    /// 되돌리기만 바닥에 남는다. 그것은 목록이 아니라 방금 한 일의 흔적이다.
    @ViewBuilder
    private var rowList: some View {
        Group {
            // ScrollView 는 화면 밖 렌더에서 내용을 그리지 않는다 (`PreviewRenderer`).
            if rendersStatically {
                VStack(alignment: .leading, spacing: 0) { rows; writer }
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) { rows; writer }
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// 빈 날에 "일정 없음" 이라고 적지 않는다. 그것은 채우라는 말이고,
    /// 이 앱은 완성을 요구하지 않는다 (철학 1). 아무것도 없으면 아무것도 없다.
    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.selectedMemos) { memo in
                row(memo)
            }
        }
    }

    private func row(_ memo: Memo) -> some View {
        let isCarried = carried?.memo.id == memo.id

        return HStack(spacing: 0) {
            HStack(spacing: Theme.tight + 1) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(memo.color.ink)
                    .frame(width: 3, height: 14)

                // 시각은 고정 폭 자리에 둔다. 시각 없는 것이 섞여도 제목이 한 줄로
                // 서고, 콜론이 세로로 맞아 훑어보기가 쉽다.
                Text(clockLabel(memo))
                    .font(Theme.microMono)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)

                Text(memo.title)
                    .font(Theme.label)
                    .foregroundStyle(Paper.ink.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: Theme.tight)
            }
            // 끌기는 여기까지다. 버튼을 이 안에 두면 누르기 하나를 놓고 버튼과
            // 끌기가 다투게 되고, 어느 쪽이 이기는지가 상황마다 달라진다.
            .contentShape(.rect)
            .gesture(carry(memo))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(clockLabel(memo).isEmpty
                ? memo.title : "\(clockLabel(memo)) \(memo.title)"))
            .accessibilityHint(Text("눌러서 열고, 끌어서 다른 날로 옮깁니다"))
            .help("눌러서 열고, 끌어서 다른 날로 옮깁니다")

            if pointedRow == memo.id, !isCarried {
                postponeButton(memo)
                detachButton(memo)
                deleteButton(memo)
            }
        }
        .padding(.vertical, 3)
        .opacity(isCarried ? 0.22 : 1)
        .overlay {
            HoverSensor { inside in
                if inside { hoveredRow = memo.id }
                else if hoveredRow == memo.id { hoveredRow = nil }
            }
        }
    }

    /// 하루 미루기 — 게으른 사람이 달력에 가장 자주 하는 일이라 한 번에 닿는다.
    ///
    /// 끌어 놓기로도 되지만 그건 겨냥이 필요하다. 「내일」은 겨냥할 필요가 없어야 한다.
    private func postponeButton(_ memo: Memo) -> some View {
        Button {
            Task { await model.postpone(memo) }
        } label: {
            Text("미루기")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Paper.ink.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        // 누르기 **전에** 어디로 가는지 말해 준다.
        .spoken("미루기 — " + (model.postponeTarget(memo).map { "\(dayText($0))로 미룹니다" } ?? "하루 미룹니다"))
    }

    /// 날짜 떼기 — **「미루기」의 짝이다.**
    ///
    /// 미루기가 *언제*를 고치는 것이라면 이것은 *어디*를 고친다. 언제 할지
    /// 모르겠다고 판명된 일을 달력에 남겨 두면 그 날이 와서 그냥 지나가고,
    /// 그 다음부터 달력은 지나간 일로 채워진다. 날짜를 떼면 그 메모는 다시
    /// 바탕화면의 종이가 되어 눈에 밟힌다 (설계문서 §7.2).
    private func detachButton(_ memo: Memo) -> some View {
        Button {
            Task { await model.detach(memo) }
        } label: {
            Text("종이로")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Paper.ink.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .spoken("종이로 — 날짜를 떼고 바탕화면의 종이로 보냅니다")
    }

    /// 지우기 — **§6 의 「지우는 길이 셋」이 여기서만 뚫려 있었다.**
    ///
    /// 「미루기」·「종이로」와 나란히 서지만 낱말이 아니라 그림이고 색도 다르다.
    /// 되돌아오지 않는 쪽으로 가는 버튼은 반쯤 보고도 구별되어야 한다 (설계문서 §6) —
    /// 이 줄에서 잘못 누르면 미루려던 일이 없어진다.
    ///
    /// 붉은 원은 **손이 닿았을 때만** 깔린다. 목록의 모든 줄에 붉은 것이 서
    /// 있으면 달력에서 가장 눈에 띄는 것이 지우기가 된다 (`CaptureRowTrash` 와
    /// 같은 규칙).
    private func deleteButton(_ memo: Memo) -> some View {
        RowTrash(help: "지우기 — 바로 아래 줄에서 되돌릴 수 있습니다") {
            Task { await model.delete(memo) }
        }
    }

    // MARK: 집어서 옮기기

    /// 한 제스처가 누르기와 끌기를 겸한다.
    ///
    /// 손이 움직이지 않았으면 **누르기**(메모 열기), 움직였으면 **끌기**(날짜
    /// 옮기기)다. 둘을 따로 두면 목록 위에서 무엇을 하려는 건지 앱이 먼저
    /// 물어봐야 하는데, 그 물음이 곧 불편이다.
    private func carry(_ memo: Memo) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let moved = max(abs(value.translation.width), abs(value.translation.height)) > 3
                grip = Grip(
                    memo: memo,
                    point: value.location,
                    cell: geometry.index(at: value.location),
                    isDragging: moved || grip?.isDragging == true
                )
            }
            .onEnded { value in
                let carried = grip?.isDragging == true
                let landing = geometry.index(at: value.location)
                grip = nil

                guard carried else {
                    onSelectMemo(memo.id)
                    return
                }
                guard let index = landing, let day = model.grid.days[safe: index] else { return }
                Task { await model.move(memo, to: day.date) }
            }
    }

    private var dropTarget: CalendarDate? {
        if let staged { return staged.target }
        if holding != nil, let index = aimCell { return model.grid.days[safe: index]?.date }
        guard let grip, grip.isDragging, let index = grip.cell else { return nil }
        return model.grid.days[safe: index]?.date
    }

    /// 종이에서 건너와 놓을 날을 기다리는 메모. 연출값이 있으면 그것이 이긴다.
    private var holding: Memo? { staged?.holding ?? model.holding }

    /// 지금 손에 들려 있는 것 — 실제 끌기든, 렌더용 연출이든.
    private var carried: (memo: Memo, point: CGPoint)? {
        if let staged, let memo = staged.carrying { return (memo, staged.carryPoint) }
        // 들고 온 것은 끌고 있는 것과 **같은 조각으로** 보인다. 오는 길이
        // 달랐을 뿐 지금 하는 일은 같다 — 놓을 날을 가리키는 중이다.
        if let holding = model.holding, let point = aimPoint { return (holding, point) }
        guard let grip, grip.isDragging else { return nil }
        return (grip.memo, grip.point)
    }

    private var pointedRow: ULID? { staged?.hoveredRow ?? hoveredRow }

    /// 끌고 다니는 종이 조각. 손끝보다 조금 위에 떠서 목표 칸을 가리지 않는다.
    @ViewBuilder
    private var carriedChip: some View {
        if let carried {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(carried.memo.color.ink)
                    .frame(width: 3, height: 11)
                Text(shortTitle(carried.memo.title))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Paper.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Paper.ink.opacity(0.14), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.20), radius: 5, y: 2)
            .fixedSize()
            .position(x: carried.point.x + 6, y: carried.point.y - 13)
            .allowsHitTesting(false)
        }
    }

    // MARK: 적기

    /// 고른 날에 한 줄. 상자를 따로 띄우지 않는다 — 날을 고르고 그 자리에서 친다.
    @ViewBuilder
    private var writer: some View {
        if isWriting || staged?.writing == true {
            TextField("", text: staged.map { .constant($0.draft) } ?? $draft)
                .textFieldStyle(.plain)
                .font(Theme.label)
                .foregroundStyle(Paper.ink)
                .focused($writerFocused)
                .onSubmit(commit)
                .onExitCommand(perform: closeWriter)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.accent.opacity(0.55)).frame(height: 1)
                }
        } else {
            // ＋ 를 버렸다. 칸마다 붙은 ＋ 는 "채워라" 라는 말이고 이 앱은
            // 완성을 요구하지 않는다 (철학 1). 대신 **다음 줄을 비워 둔다** —
            // 노트에서 한 줄 더 적을 자리가 그렇게 생겼다.
            Button(action: openWriter) {
                HStack(spacing: Theme.tight) {
                    Text("이 날에 적기")
                        .font(Theme.micro)
                        .foregroundStyle(Paper.ink.opacity(isHovering ? 0.46 : 0.22))
                    DashedRule()
                        .stroke(
                            Paper.ink.opacity(isHovering ? 0.22 : 0.11),
                            style: StrokeStyle(lineWidth: 0.75, dash: [2.5, 3])
                        )
                        .frame(height: 1)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 5)
        }
    }

    private func openWriter() {
        isWriting = true
        writerFocused = true
    }

    private func closeWriter() {
        isWriting = false
        writerFocused = false
        draft = ""
    }

    /// 빈 채로 Return 이면 손을 뗀 것으로 본다. 적었으면 그대로 두고 다음 줄을 기다린다 —
    /// 하나 적고 상자가 닫히면 둘째 줄을 적으려고 다시 눌러야 한다.
    private func commit() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            closeWriter()
            return
        }
        draft = ""
        Task { await model.add(text) }
    }

    // MARK: 되돌리기

    private func undoLine(_ move: CalendarModel.Move) -> some View {
        HStack(spacing: Theme.tight) {
            Text(MoveNote.text(from: move.from, to: move.to))
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
            Button("되돌리기") { Task { await model.undo() } }
                .buttonStyle(.plain)
                .font(Theme.micro)
                .foregroundStyle(Theme.accentInk)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    /// 방금 지운 것을 되살리는 줄. **옮기기의 되돌리기와 같은 자리를 쓴다** —
    /// 방금 한 일은 하나뿐이고, 자리를 따로 만들면 격자가 그만큼 줄어든다.
    private func deleteUndoLine(_ memo: Memo) -> some View {
        HStack(spacing: Theme.tight) {
            Text("「\(shortTitle(memo.title))」 지웠습니다")
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Button("되돌리기") { Task { await model.restoreDeleted() } }
                .buttonStyle(.plain)
                .font(Theme.micro)
                .foregroundStyle(Theme.accentInk)
                .spoken("되돌리기 — 방금 지운 일정을 되살립니다")
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    /// 놓을 날을 기다리는 동안 바닥에 서는 줄.
    ///
    /// 되돌리기 줄과 **같은 자리**를 쓴다. 방금 한 일과 지금 하는 일은 둘 다
    /// "이 창이 알려주는 한 줄" 이고, 자리를 따로 만들면 격자가 그만큼 줄어든다.
    private func holdLine(_ memo: Memo) -> some View {
        HStack(spacing: Theme.tight) {
            Text("「\(shortTitle(memo.title))」 놓을 날을 고르세요")
                .font(Theme.micro)
                .foregroundStyle(Theme.highlightInk)
                .lineLimit(1)
            Button("그만두기") { model.cancelHold() }
                .buttonStyle(.plain)
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: 글자와 색

    private var dayTitle: String {
        guard let start = model.selected.startOfDay() else { return model.selected.description }
        let formatted = start.formatted(.dateTime.month().day().weekday(.wide))
        return model.isToday(model.selected) ? "오늘 · \(formatted)" : formatted
    }

    private func weekdayName(_ date: CalendarDate) -> String {
        guard let start = date.startOfDay() else { return "" }
        return start.formatted(.dateTime.weekday(.wide))
    }

    private func dayText(_ date: CalendarDate) -> String {
        "\(date.month)월 \(date.day)일"
    }

    private func dayHelp(_ date: CalendarDate) -> String {
        let count = model.memos(on: date).count
        return count > 0 ? "\(dayText(date)) — \(count)개" : dayText(date)
    }

    /// `14:30`. 로케일 형식(오후 2:30)은 폭이 들쭉날쭉해 세로로 안 맞는다.
    private func clockLabel(_ memo: Memo) -> String {
        guard let at = memo.at else { return "" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: at)
        guard let hour = parts.hour, let minute = parts.minute else { return "" }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func shortTitle(_ title: String) -> String {
        title.count > Self.chipLimit ? String(title.prefix(Self.chipLimit)) + "…" : title
    }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    private func columnColor(_ column: Int) -> Color {
        switch column {
        case 0: Theme.sunday
        case 6: Theme.saturday
        default: Paper.ink
        }
    }

    /// 숫자의 색. 마른 정도는 이미 `monthInk` 가 세어 두었다.
    private func numeralColor(column: Int, isTarget: Bool, presence: Double) -> Color {
        // 손이 향하고 있는 칸은 바래지 않는다. 지난 날이라고 흐린 채로 두면
        // 지금 놓으려는 그 자리가 가장 안 읽히는 칸이 된다.
        if isTarget { return Theme.accentInk }
        return columnColor(column).opacity(0.92 * presence)
    }
}
