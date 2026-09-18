import LazyMemoCore
import SwiftUI

/// 달 격자의 **칸들** — 42칸과 그 아래 번진 잉크 (설계문서 §10.3·§10.4).
///
/// ## 왜 따로 떼어 냈나
///
/// 칸들은 `CalendarView` 안에 있었고, 그래서 **창에서 무엇이 바뀌든 42칸이 다시
/// 만들어졌다.** 가장 비싼 순간은 줄을 집어 격자로 끌고 갈 때다 — `DragGesture`
/// 가 손가락 자리를 `@State` 에 적으므로 **매 프레임** `CalendarView.body` 가
/// 다시 돌고, 그 안에서
///
/// - 칸마다 `dayHelp` 를 **둘씩**(`.help` 와 소리 이름표) 지었다. 그 한 줄이
///   `Date.FormatStyle` 을 새로 만들어 서식한다 — 프레임마다 **84번**이다.
/// - 42칸의 `ZStack`·`Button`·`onTapGesture` 트리를 다시 지어 diff 했다.
/// - 마른 정도와 얼룩(`monthInk`)을 다시 훑었다.
///
/// 폰의 달력이 같은 이유로 걸렸고 같은 방법으로 고쳤다 (2026-09-17
/// `MonthStrip`·`MonthPanel`). 맥에도 그대로 둔다: 판은 `Equatable` 인 자식이고,
/// 견주는 것은 **값**뿐이라(닫힘은 뺀다) 달·고른 날·놓을 자리·잉크가 그대로면
/// SwiftUI 가 `body` 를 통째로 건너뛴다. 끌고 가는 동안 실제로 바뀌는 것은
/// `dropTarget` 한 칸이므로, 그때만 한 번 다시 그린다.
///
/// ## 이름표는 달이 바뀔 때만 짓는다
///
/// 「9월 14일 — 4개」는 `.help` 와 VoiceOver 가 같이 쓴다. 판이 다시 그려질 때
/// 한 번 지어 42개를 들고 있는다 — 칸마다 둘씩 짓던 것이 판마다 한 벌이 된다.
struct MonthPanel: View, Equatable {
    /// 잉크는 모델에서 읽는다. 참조는 바뀌지 않으므로 견주지 않는다 —
    /// 「잉크가 달라졌나」는 `inkVersion` 한 숫자가 답한다.
    let model: CalendarModel
    let grid: MonthGrid
    let plan: CalendarLayout
    let selected: CalendarDate
    let today: CalendarDate
    /// 끌거나 들고 온 것이 겨누는 칸.
    let dropTarget: CalendarDate?
    /// 지금 무언가를 **놓으려는 중**인가. 누르기의 뜻이 달라진다.
    let isPlacing: Bool
    /// 날짜별 일정이 다시 읽힌 횟수 (`CalendarModel.inkVersion`).
    let inkVersion: Int
    let onSelect: (CalendarDate) -> Void
    let onPlace: (CalendarDate) -> Void

    /// 닫힘(함수)은 견줄 수 없다 — 부르는 쪽이 매번 새로 만들지만 하는 일은 같다.
    /// 값만 견준다 (폰의 `MonthPanel` 과 같은 규칙).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.grid == rhs.grid && lhs.plan == rhs.plan && lhs.selected == rhs.selected
            && lhs.today == rhs.today && lhs.dropTarget == rhs.dropTarget
            && lhs.isPlacing == rhs.isPlacing && lhs.inkVersion == rhs.inkVersion
    }

    var body: some View {
        // 마른 정도·얼룩·이름표를 **한 번에 훑어 둔다.** 칸마다 다시 세면
        // 42번을 42번 반복하게 된다.
        let ink = monthInk
        let words = dayWords

        return VStack(spacing: 0) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { row, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                        let index = row * MonthGridGeometry.columns + column
                        cell(
                            day, column: column,
                            presence: ink.presence[index],
                            words: words[index]
                        )
                    }
                }
            }
        }
        // 붐비는 날의 얼룩은 칸이 아니라 **격자 전체에 한 장으로** 그린다
        // (`InkBleedLayer`). 얼룩이 칸 경계를 조금 넘어가는 것도 여기서 온다.
        .background {
            InkBleedLayer(rows: grid.weeks.count, stains: ink.stains, week: nil)
        }
    }

    // MARK: 한 칸

    /// **표시가 셋뿐이고 셋 다 펜 자국이다.**
    ///
    /// - 오늘: 손으로 그린 동그라미 (`HandRing`) + 스민 호박색
    /// - 고른 날: 밑줄 (`HandUnderline`)
    /// - 놓을 자리: 칸 전체가 눌린다
    ///
    /// 놓을 자리만 면으로 말하는 이유는 **손이 이미 움직이는 중**이기 때문이다.
    /// 작은 고리는 겨냥한 다음에야 보이고, 그때는 이미 늦다. 그리고 칸 전체가
    /// 곧 착지 판정 범위라 (`MonthGridGeometry`) 보이는 것과 되는 것이 같아진다.
    private func cell(
        _ day: MonthGrid.Day, column: Int, presence: Double, words: String
    ) -> some View {
        let isToday = day.date == today
        let isSelected = day.date == selected
        let isTarget = dropTarget == day.date

        return ZStack {
            if isTarget {
                RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                    // **잉크 쪽 값이다.** 면을 칠하는 딥 네이비를 13% 로 깔면
                    // 어두운 종이에서 아무것도 안 보인다 — 끌고 있는 동안
                    // 가장 중요한 표시가 다크에서만 사라진다.
                    .fill(Theme.accentInk.opacity(0.15))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1.5)
            }

            if isSelected || isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isToday ? Theme.accent : Theme.softAccent)
                    .frame(width: plan.markSize * 1.48, height: plan.markSize * 1.20)
                    .offset(y: -3)
            }

            Text("\(day.date.day)")
                .font(.system(size: plan.numeralSize, weight: isToday || isSelected ? .bold : .medium,
                              design: .rounded).monospacedDigit())
                .foregroundStyle(isToday ? Theme.onAccent : Self.numeralColor(column: column, isTarget: isTarget, presence: presence))
                .offset(y: -3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: plan.weekHeight)
        .contentShape(.rect)
        .onTapGesture {
            // 들고 온 것이 있으면 누르기는 **놓기**다. 날짜를 글자로 치는
            // 대신 자리로 가리키는 것이 이 창의 유일한 방법이어야 한다.
            if isPlacing { onPlace(day.date) } else { onSelect(day.date) }
        }
        .help(isPlacing ? L("\(DateWords.monthDay(day.date))에 놓기") : words)
        // 칸은 숫자 하나뿐이라 "몇 월 며칠 · 몇 개" 를 소리로 따로 적는다.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(words))
        .accessibilityHint(Text(isPlacing ? L("여기에 놓기") : L("이 날 펼치기")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: 한 달치의 잉크

    /// 달 한 장치의 잉크 — 칸마다 마른 정도와, 붐비는 날의 얼룩.
    ///
    /// 격자를 한 번만 훑는다. 두 값이 같은 순회에서 나오므로 얼룩도 지난 날이면
    /// 함께 마른다 — 표시와 바탕이 따로 늙으면 그 칸만 어색해진다.
    struct MonthInk: Equatable {
        var presence: [Double]
        var stains: [InkBleedLayer.Stain]
    }

    private var monthInk: MonthInk {
        // 이 달에 오늘이 없다면 **일부러 찾아온 달**이다. 읽으려는 뜻이 곧
        // 되살리는 신호이므로 (철학 3) 아무것도 말리지 않는다.
        let anchor = grid.days.firstIndex { $0.date == today }
        var presence: [Double] = []
        var stains: [InkBleedLayer.Stain] = []
        presence.reserveCapacity(grid.days.count)

        for (index, day) in grid.days.enumerated() {
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
        return MonthInk(presence: presence, stains: stains)
    }

    /// 칸의 말 — 「9월 14일」 · 「9월 14일 — 4개」. **판마다 한 벌만 짓는다.**
    /// 칸마다 둘씩 지으면 `Date.FormatStyle` 이 한 프레임에 84번 만들어진다.
    private var dayWords: [String] {
        grid.days.map { day in
            let text = DateWords.monthDay(day.date)
            let count = model.memos(on: day.date).count
            return count > 0 ? L("\(text) — \(count)개") : text
        }
    }

    // MARK: 색 — 요일 줄도 같은 것을 쓴다

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    static func columnColor(_ column: Int) -> Color {
        switch column {
        case 0: Theme.sunday
        case 6: Theme.saturday
        default: Paper.ink
        }
    }

    /// 숫자의 색. 마른 정도는 이미 `monthInk` 가 세어 두었다.
    static func numeralColor(column: Int, isTarget: Bool, presence: Double) -> Color {
        // 손이 향하고 있는 칸은 바래지 않는다. 지난 날이라고 흐린 채로 두면
        // 지금 놓으려는 그 자리가 가장 안 읽히는 칸이 된다.
        if isTarget { return Theme.accentInk }
        return columnColor(column).opacity(0.92 * presence)
    }
}
