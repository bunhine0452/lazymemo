import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 「달력」의 얼굴들.
struct CalendarWidgetView: View {
    let entry: CalendarEntry
    let family: WidgetFamily

    @Environment(\.widgetTheme) private var theme

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    /// 오늘 한 칸 — 요일, 큰 날짜, 일정 수. 누르면 오늘.
    private var small: some View {
        TodayBlock(entry: entry, big: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(WidgetLink.calendar(entry.today))
    }

    /// 오늘 칸 옆에 격자. 자리가 얕아 숫자를 작게 — 달 이름은 왼쪽 칸이 든다.
    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            TodayBlock(entry: entry, big: false)
                .frame(width: 72, alignment: .leading)
            MonthGridFace(entry: entry, compact: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetLink.calendar())
    }

    /// 격자와 「오늘부터」.
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHead(
                kind: Text(DateWords.yearMonth(year: entry.grid.year, month: entry.grid.month)),
                trailing: Text(DateWords.monthDayWeekday(entry.today))
            )
            MonthGridFace(entry: entry, compact: false)
            if entry.agenda.isEmpty {
                EmptyFace(line: Text("적어 둔 일정이 없어요"))
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.agenda) { row in
                        Link(destination: WidgetLink.memo(row.id)) { AgendaRow(row: row, now: entry.date) }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetLink.calendar())
    }
}

/// 오늘 — 요일 한 줄, 날짜 하나, 일정 몇. 애플 달력의 작은 위젯이 하는 말과 같다.
private struct TodayBlock: View {
    let entry: CalendarEntry
    /// 작은 위젯이면 날짜가 크고, 중간 위젯의 옆 칸이면 격자에 자리를 내준다.
    let big: Bool

    @Environment(\.widgetTheme) private var theme

    private var count: Int { entry.marks[entry.today] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: big ? 4 : 2) {
            Text(weekday)
                .font((big ? Font.subheadline : .caption).weight(.semibold))
                .foregroundStyle(theme.accentInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
            Text(String(entry.today.day))
                .font(.system(size: big ? 52 : 34, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !big {
                Text(DateWords.month(entry.grid.month))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(count > 0 ? String(localized: "일정 \(count)") : String(localized: "일정 없음"))
                .font((big ? Font.subheadline : .caption2).weight(.medium))
                .foregroundStyle(count > 0 ? theme.highlightInk : theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private var weekday: String {
        entry.date.formatted(.dateTime.weekday(.wide))
    }
}

/// 달 격자 — 폰의 `MonthGridView` 를 위젯 크기에 맞게 옮긴 것. 누르는 것은 시스템이 하니
/// 버튼이 아니라 `Link` 다. 여섯 주가 다 차면 줄이 낮아진다.
private struct MonthGridFace: View {
    let entry: CalendarEntry
    /// 중간 위젯 — 요일과 숫자만, 작게.
    let compact: Bool

    @Environment(\.widgetTheme) private var theme

    private let weekdays = DateWords.weekdayLetters()

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(weekdayInk(index))
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(entry.grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        Link(destination: WidgetLink.calendar(day.date)) { cell(day) }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(_ day: MonthGrid.Day) -> some View {
        let isToday = day.date == entry.today
        let count = entry.marks[day.date] ?? 0
        let ring: CGFloat = compact ? 21 : 30
        return ZStack {
            if isToday {
                // 채운 원이 아니라 펜 자국 — 숫자가 종이에 그대로 남는다. 색은 `accent`(면의 색)가
                // 아니라 `accentInk`(작은 획의 색)다 — 숯색 종이 위에서 포레스트 획은 거의 안 보인다.
                HandRing(color: theme.accentInk, line: compact ? 1.4 : 1.7)
                    .frame(width: ring, height: ring)
                    .widgetAccentable()
            }
            Text(String(day.date.day))
                .font((compact ? Font.caption2 : .footnote).monospacedDigit().weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? theme.accentInk : theme.ink)
                .opacity(day.isOverflow ? 0.35 : 1)
            if count > 0 {
                HStack(spacing: compact ? 1.5 : 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle()
                            .fill(theme.highlightInk)
                            .frame(width: compact ? 3 : 4, height: compact ? 3 : 4)
                    }
                }
                .offset(y: compact ? 7 : 11)
                .opacity(day.isOverflow ? 0.5 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(count > 0
            ? String(localized: "\(DateWords.dayWeekday(day.date)), 일정 \(count)")
            : DateWords.dayWeekday(day.date))
        .accessibilityAddTraits(isToday ? .isSelected : [])
    }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑 (`ios/LazyMemo/Theme.swift`). 색을 걷어 가는
    /// 자리에서는 계층색으로 물러난다 — 거기서 빨강·파랑은 흰 얼룩이 된다.
    private func weekdayInk(_ index: Int) -> Color {
        guard theme.papery else { return theme.secondary }
        switch index {
        case 0: return Color(red: 0.76, green: 0.36, blue: 0.34)
        case 6: return Color(red: 0.36, green: 0.55, blue: 0.72)
        default: return theme.secondary
        }
    }
}
