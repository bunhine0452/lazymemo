import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 다음 약속 — 시각이 적힌 것 중 가장 가까운 한 장 (`WidgetAgenda.next`).
///
/// 큰 글자는 시각이다. 그 아래 제목, 그리고 가는 길을 적어 두었으면 **출발 시각과 첫 탈것**
/// (「18:12 출발 · 2호선」) — 길이 없으면 남은 시간이 흐른다. 누르면 그 메모.
/// 시각이 지나면 다음 장면이 그다음 약속을 든다 (`WidgetAgenda.moments`).
struct NextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.next.identifier, provider: NextProvider()) { entry in
            NextRoot(entry: entry)
        }
        .configurationDisplayName(Text("다음 약속"))
        .description(Text("다음 약속의 시각. 가는 길을 적어 두었으면 출발 시각도."))
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        #else
        [.systemSmall]
        #endif
    }
}

struct NextEntry: TimelineEntry, Sendable {
    let date: Date
    let next: WidgetAgenda.NextAppointment?

    static func make(_ memos: [Memo], at date: Date) -> NextEntry {
        NextEntry(date: date, next: WidgetAgenda.next(memos, now: date))
    }

    static func sample(at date: Date = Date()) -> NextEntry {
        make(WidgetSample.memos(now: date), at: date)
    }
}

struct NextProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NextEntry) -> Void) {
        if context.isPreview { completion(.sample()); return }
        Task { completion(.make(await WidgetVault.memos(), at: Date())) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NextEntry>) -> Void) {
        Task {
            let memos = await WidgetVault.memos()
            let entries = WidgetAgenda.moments(memos, now: Date()).map { NextEntry.make(memos, at: $0) }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

// MARK: - 얼굴

private struct NextRoot: View {
    let entry: NextEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        NextView(entry: entry, family: family)
            .containerBackground(for: .widget) { Paper.surface }
    }
}

struct NextView: View {
    let entry: NextEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryRectangular: rectangular
        case .accessoryCircular: circular
        case .accessoryInline: inline
        #endif
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("다음 약속")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            if let next = entry.next {
                // 시각이 큰 글자, 날은 그 옆에 작게 — 한 줄을 아껴야 작은 위젯에 제목 두 줄이 선다.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(WidgetWords.time(next.at))
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(WidgetWords.day(CalendarDate(next.at), now: entry.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.accentInk)
                        .lineLimit(1)
                }
                Text(next.memo.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                Spacer(minLength: 0)
                tail(next)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
                Text("약속이 없어요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paper.ink)
                Text("시각을 적은 메모가 여기 서요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.next.map { WidgetLink.memo($0.memo.id) } ?? WidgetLink.write)
    }

    /// 마지막 줄 — 출발이 적혀 있으면 「18:12 출발 · 2호선」, 아니면 남은 시간이 흐른다.
    @ViewBuilder
    private func tail(_ next: WidgetAgenda.NextAppointment) -> some View {
        if let departure = next.departure {
            Label(WidgetWords.departure(departure), systemImage: "figure.walk")
                .foregroundStyle(Theme.highlightInk)
        } else {
            Text("\(Text(next.at, style: .relative)) 뒤")
                .foregroundStyle(.secondary)
        }
    }

    #if os(iOS)
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = entry.next {
                Label(WidgetWords.time(next.at), systemImage: "calendar")
                    .font(.headline.monospacedDigit())
                    .widgetAccentable()
                    .lineLimit(1)
                Text(next.memo.title)
                    .font(.caption)
                    .lineLimit(1)
                tail(next)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
            } else {
                Label("다음 약속", systemImage: "calendar")
                    .font(.caption2.weight(.medium))
                    .widgetAccentable()
                Text("약속이 없어요")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.next.map { WidgetLink.memo($0.memo.id) } ?? WidgetLink.write)
    }

    /// 동그라미 — 시각 하나. 좁아서 24시간 시계(`RouteNote.clock`)를 쓴다.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .widgetAccentable()
                if let next = entry.next {
                    Text(RouteNote.clock(next.at))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .minimumScaleFactor(0.7)
                } else {
                    Text("—")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .widgetURL(entry.next.map { WidgetLink.memo($0.memo.id) } ?? WidgetLink.write)
    }

    private var inline: some View {
        Group {
            if let next = entry.next {
                Label {
                    Text(verbatim: "\(WidgetWords.time(next.at)) \(next.memo.title)")
                } icon: {
                    Image(systemName: "calendar")
                }
            } else {
                Label("약속이 없어요", systemImage: "calendar")
            }
        }
        .widgetURL(entry.next.map { WidgetLink.memo($0.memo.id) } ?? WidgetLink.write)
    }
    #endif
}
