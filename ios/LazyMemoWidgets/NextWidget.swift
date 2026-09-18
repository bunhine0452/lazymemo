import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 다음 약속 — 시각이 적힌 것 중 가장 가까운 한 장 (`WidgetAgenda.next`).
///
/// 큰 글자는 시각이다. 그 아래 제목, 그리고 가는 길을 적어 두었으면 **출발 시각과 첫 탈것**
/// (「18:12 출발 · 2호선」). 마지막 줄은 **스스로 흐르는 남은 시간** — 시간표 장면을 더 만들지
/// 않고 시스템이 그 글자만 고쳐 그린다 (`Text(_:style:.relative)`). 누르면 그 메모.
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

    static func empty(at date: Date = Date()) -> NextEntry {
        NextEntry(date: date, next: nil)
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

struct NextRoot: View {
    let entry: NextEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        NextView(entry: entry, family: family)
            .widgetPaper(.resolved(mode))
    }
}

struct NextView: View {
    let entry: NextEntry
    let family: WidgetFamily

    @Environment(\.widgetTheme) private var theme

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
            WidgetHead(kind: Text("다음"), trailing: entry.next.map { Text(WidgetWords.day(CalendarDate($0.at), now: entry.date)) })
            if let next = entry.next {
                Text(WidgetWords.time(next.at))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Text(next.memo.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .privacySensitive()
                Spacer(minLength: 2)
                tail(next)
            } else {
                Spacer(minLength: 0)
                EmptyFace(line: Text("약속이 없어요"))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.next.map { WidgetLink.memo($0.memo.id) } ?? WidgetLink.write)
    }

    /// 마지막 줄들 — 출발이 적혀 있으면 「18:12 출발 · 2호선」, 그 아래 흐르는 남은 시간.
    /// 자리가 얕으면 남은 시간만 남는다 (그것이 더 급한 말이다).
    @ViewBuilder
    private func tail(_ next: WidgetAgenda.NextAppointment) -> some View {
        ViewThatFits(in: .vertical) {
            VStack(alignment: .leading, spacing: 1) {
                departureLine(next)
                countdown(next)
            }
            countdown(next)
        }
        .font(.caption2.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private func departureLine(_ next: WidgetAgenda.NextAppointment) -> some View {
        if let departure = next.departure {
            Label(WidgetWords.departure(departure), systemImage: "figure.walk")
                .foregroundStyle(theme.highlightInk)
                .widgetAccentable()
        }
    }

    /// **스스로 흐르는 한 줄.** 출발이 아직 오지 않았으면 그쪽까지, 아니면 약속까지.
    @ViewBuilder
    private func countdown(_ next: WidgetAgenda.NextAppointment) -> some View {
        if let departure = next.departure?.at, departure > entry.date {
            Text("\(Text(departure, style: .relative)) 뒤 출발").foregroundStyle(theme.secondary)
        } else if next.at > entry.date {
            Text("\(Text(next.at, style: .relative)) 뒤").foregroundStyle(theme.secondary)
        } else {
            Text("지금").foregroundStyle(theme.highlightInk)
        }
    }

    // MARK: 잠금 화면

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
                    .privacySensitive()
                tail(next)
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
                    Text(verbatim: "—")
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
                    Text(verbatim: "\(WidgetWords.time(next.at)) \(next.memo.title)").privacySensitive()
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

#if DEBUG
#Preview("다음 · 작게", as: .systemSmall) { NextWidget() } timeline: { NextEntry.sample() }
#Preview("다음 · 빈 자리", as: .systemSmall) { NextWidget() } timeline: { NextEntry.empty() }
#if os(iOS)
#Preview("다음 · 잠금 네모", as: .accessoryRectangular) { NextWidget() } timeline: { NextEntry.sample() }
#Preview("다음 · 잠금 동그라미", as: .accessoryCircular) { NextWidget() } timeline: { NextEntry.sample() }
#Preview("다음 · 잠금 한 줄", as: .accessoryInline) { NextWidget() } timeline: { NextEntry.sample() }
#endif
#endif
