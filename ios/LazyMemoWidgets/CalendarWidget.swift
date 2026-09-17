import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 「달력」 — 이번 달 격자를 홈 화면에 (`WidgetAgenda.monthMarks`).
///
/// 폰·맥의 달력과 같은 낱말이다: 오늘은 포레스트 원, 일정이 있는 날은 숫자 밑의 점(셋까지),
/// 일요일 빨강·토요일 파랑, 앞뒤 달에서 넘어온 칸은 옅다. 작은 것은 오늘 한 칸(요일·날·일정 수),
/// 중간은 오늘 칸 옆에 격자, 큰 것은 격자와 그 아래 「오늘부터」 몇 줄. 자정마다 오늘이 옮겨
/// 간다 (`WidgetAgenda.dayChanges`). 누르면 달력 — 날을 누르면 그 날 (`WidgetLink.calendar`).
struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.calendar.identifier, provider: CalendarProvider()) { entry in
            CalendarRoot(entry: entry)
        }
        .configurationDisplayName(Text("달력"))
        .description(Text("이번 달 한눈에. 일정이 있는 날은 점."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CalendarEntry: TimelineEntry, Sendable {
    let date: Date
    let grid: MonthGrid
    let marks: [CalendarDate: Int]
    /// 큰 위젯의 아래 절 — 오늘부터의 일정.
    let agenda: [WidgetAgenda.Upcoming]

    var today: CalendarDate { CalendarDate(date) }

    static func make(_ memos: [Memo], at date: Date) -> CalendarEntry {
        let grid = MonthGrid.current(date)
        return CalendarEntry(
            date: date,
            grid: grid,
            marks: WidgetAgenda.monthMarks(memos, in: grid),
            agenda: WidgetAgenda.upcoming(memos, now: date, limit: 4, includingToday: true)
        )
    }

    static func sample(at date: Date = Date()) -> CalendarEntry {
        make(WidgetSample.memos(now: date), at: date)
    }
}

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CalendarEntry) -> Void) {
        if context.isPreview { completion(.sample()); return }
        Task { completion(.make(await WidgetVault.memos(), at: Date())) }
    }

    /// 장면은 자정마다 하나 — 오늘이 옮겨 가고, 달이 넘어가면 격자가 바뀐다. 메모가 바뀌면
    /// `WidgetRefresher` 가 처음부터 다시 부른다.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CalendarEntry>) -> Void) {
        Task {
            let memos = await WidgetVault.memos()
            let entries = WidgetAgenda.dayChanges(now: Date()).map { CalendarEntry.make(memos, at: $0) }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

// MARK: - 얼굴

private struct CalendarRoot: View {
    let entry: CalendarEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        CalendarWidgetView(entry: entry, family: family)
            .containerBackground(for: .widget) { Paper.surface }
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarEntry
    let family: WidgetFamily

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(DateWords.month(entry.grid.month))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Paper.ink)
                Text(String(entry.grid.year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DateWords.monthDayWeekday(entry.today))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accentInk)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            MonthGridFace(entry: entry, compact: false)
            if entry.agenda.isEmpty {
                Text("적어 둔 일정이 없어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.agenda) { row in
                        Link(destination: WidgetLink.memo(row.id)) { agendaRow(row) }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetLink.calendar())
    }

    /// 「오늘 · 오후 3:00   치과」 — 「지금」 위젯의 「다음」 줄과 같은 꼴 (`NowView.upcomingRow`).
    private func agendaRow(_ row: WidgetAgenda.Upcoming) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text([WidgetWords.day(row.day, now: entry.date), row.at.map(WidgetWords.time)].compactMap { $0 }.joined(separator: " · "))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.highlightInk)
                .lineLimit(1)
                .layoutPriority(1)
            Text(row.memo.title)
                .font(.caption)
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 오늘 — 요일 한 줄, 날짜 하나, 일정 몇. 애플 달력의 작은 위젯이 하는 말과 같다.
private struct TodayBlock: View {
    let entry: CalendarEntry
    /// 작은 위젯이면 날짜가 크고, 중간 위젯의 옆 칸이면 격자에 자리를 내준다.
    let big: Bool

    private var count: Int { entry.marks[entry.today] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: big ? 4 : 2) {
            Text(weekday)
                .font((big ? Font.subheadline : .caption).weight(.semibold))
                .foregroundStyle(Theme.accentInk)
            Text(String(entry.today.day))
                .font(.system(size: big ? 52 : 34, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !big {
                Text(DateWords.month(entry.grid.month))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(count > 0 ? String(localized: "일정 \(count)") : String(localized: "일정 없음"))
                .font((big ? Font.subheadline : .caption2).weight(.medium))
                .foregroundStyle(count > 0 ? Theme.highlightInk : .secondary)
                .lineLimit(1)
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
    /// 중간 위젯 — 머리글 없이 요일과 숫자만, 작게.
    let compact: Bool

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
        let ring: CGFloat = compact ? 20 : 30
        return ZStack {
            if isToday {
                Circle().fill(Theme.accent).frame(width: ring, height: ring)
            }
            Text(String(day.date.day))
                .font((compact ? Font.caption2 : .footnote).monospacedDigit().weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Theme.onAccent : Paper.ink)
                .opacity(day.isOverflow ? 0.35 : 1)
            if count > 0 {
                HStack(spacing: compact ? 1.5 : 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle()
                            .fill(isToday ? Theme.onAccent : Theme.highlightInk)
                            .frame(width: compact ? 3 : 4, height: compact ? 3 : 4)
                    }
                }
                .offset(y: compact ? 7 : 11)
                .opacity(day.isOverflow ? 0.5 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(count > 0
            ? String(localized: "\(DateWords.dayWeekday(day.date)), 일정 \(count)")
            : DateWords.dayWeekday(day.date))
        .accessibilityAddTraits(isToday ? .isSelected : [])
    }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑 (`ios/LazyMemo/Theme.swift`).
    private func weekdayInk(_ index: Int) -> Color {
        switch index {
        case 0: Color(red: 0.76, green: 0.36, blue: 0.34)
        case 6: Color(red: 0.36, green: 0.55, blue: 0.72)
        default: .secondary
        }
    }
}
