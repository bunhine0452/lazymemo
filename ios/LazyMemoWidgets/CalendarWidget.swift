import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 「달력」 — 이번 달 격자를 홈 화면에 (`WidgetAgenda.monthMarks`).
///
/// 폰의 달력과 같은 낱말이다: 오늘은 숫자를 두른 **정확한 원**(테두리 — 숫자가 종이에 남는다),
/// 일정이 있는 날은 숫자 밑의 점(셋까지, **메모의 색**), 일요일 빨강·토요일 파랑, 앞뒤 달에서 넘어온 칸은 옅다.
/// 작은 것은 오늘 한 칸, 중간은 오늘 칸 옆에 격자, 큰 것은 격자와 그 아래 「오늘부터」 몇 줄.
/// 자정마다 오늘이 옮겨 간다 (`WidgetAgenda.dayChanges`). 얼굴은 `CalendarFaces.swift`.
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
    /// 날짜별 점 — 메모의 색, 그 날의 차례로 (`WidgetAgenda.monthInks`).
    let marks: [CalendarDate: [MemoColor]]
    /// 큰 위젯의 아래 절 — 오늘부터의 일정.
    let agenda: [WidgetAgenda.Upcoming]

    var today: CalendarDate { CalendarDate(date) }

    static func make(_ memos: [Memo], at date: Date) -> CalendarEntry {
        let grid = MonthGrid.current(date)
        return CalendarEntry(
            date: date,
            grid: grid,
            marks: WidgetAgenda.monthInks(memos, in: grid),
            agenda: WidgetAgenda.upcoming(memos, now: date, limit: 4, includingToday: true)
        )
    }

    static func sample(at date: Date = Date()) -> CalendarEntry {
        make(WidgetSample.memos(now: date), at: date)
    }

    static func empty(at date: Date = Date()) -> CalendarEntry {
        make([], at: date)
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

struct CalendarRoot: View {
    let entry: CalendarEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        CalendarWidgetView(entry: entry, family: family)
            .widgetPaper(.resolved(mode))
    }
}

#if DEBUG
#Preview("달력 · 작게", as: .systemSmall) { CalendarWidget() } timeline: { CalendarEntry.sample() }
#Preview("달력 · 중간", as: .systemMedium) { CalendarWidget() } timeline: { CalendarEntry.sample() }
#Preview("달력 · 크게", as: .systemLarge) { CalendarWidget() } timeline: { CalendarEntry.sample() }
#Preview("달력 · 빈 자리", as: .systemLarge) { CalendarWidget() } timeline: { CalendarEntry.empty() }
#endif
