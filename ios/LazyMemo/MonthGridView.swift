import LazyMemoCore
import SwiftUI

/// 달 격자 — 달력 탭과 날짜 시트가 같은 것을 쓴다 (MOBILE_DESIGN §5·§6).
///
/// 오늘은 포레스트 원, 고른 날은 옅은 원, 일정은 숫자 밑의 **점**이다 — 맥의
/// 달력과 같은 낱말 (§10.4). 앞선 판은 일정 있는 칸을 네모 바탕으로 물들였는데,
/// 그 네모가 「고른 날」과 같은 모양이라 두 칸이 골라진 것처럼 읽혔다.
/// 여섯 주의 높이를 예약해 5주·6주를 오가도 아래가 흔들리지 않는다.
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
    private let weekdays = DateWords.weekdayLetters()

    var body: some View {
        VStack(spacing: 8) {
            header
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(weekdayInk(index))
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 4) {
                ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week) { day in cell(day) }
                    }
                }
            }
            .frame(minHeight: Self.cell * 6 + 4 * 5, alignment: .top)
        }
        .padding(.horizontal, 12)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                onStep(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(DateWords.month(grid.month))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Paper.ink)
            Text(String(grid.year))
                .font(.title3)
                .foregroundStyle(.secondary)
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
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
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
        .accessibilityLabel(count > 0
            ? String(localized: "\(DateWords.dayWeekday(day.date)), 일정 \(count)")
            : DateWords.dayWeekday(day.date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func weekdayInk(_ index: Int) -> Color {
        switch index {
        case 0: Theme.sundayInk
        case 6: Theme.saturdayInk
        default: .secondary
        }
    }

}
