import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit

/// 「지금」 — 앱의 띠 그대로 홈 화면에 (`Recall.nowCards`).
///
/// 작은 것은 한 장, 중간은 세 장, 큰 것은 세 장과 그 아래 「다음」 — 오늘 뒤에 올 일정 몇 줄.
/// 잠금 화면에는 한 장. 카드를 누르면 그 메모가 열린다 (`WidgetLink.memo`), 빈 위젯을
/// 누르면 펜이 올라온다 — 펼칠 것이 없으면 적을 차례다.
struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.now.identifier, provider: NowProvider()) { entry in
            NowRoot(entry: entry)
        }
        .configurationDisplayName(Text("지금"))
        .description(Text("오늘 다시 볼 것·오늘 일정·고정한 메모 — 앱의 「지금」 그대로."))
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct NowEntry: TimelineEntry, Sendable {
    let date: Date
    let cards: [Recall.Card]
    /// 큰 위젯의 아래 절 — 오늘 뒤에 올 일정.
    let upcoming: [WidgetAgenda.Upcoming]

    static func make(_ memos: [Memo], at date: Date, seen: [ULID: Date]) -> NowEntry {
        NowEntry(
            date: date,
            cards: WidgetAgenda.nowCards(memos, now: date, seen: seen),
            // 큰 위젯의 아래 절 — 세 장 아래 여섯 줄이 들어간다.
            upcoming: WidgetAgenda.upcoming(memos, now: date, limit: 6)
        )
    }

    static func sample(at date: Date = Date()) -> NowEntry {
        make(WidgetSample.memos(now: date), at: date, seen: [:])
    }
}

struct NowProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NowEntry) -> Void) {
        // 갤러리에는 견본을 — 빈 위젯을 보고는 무엇인지 알 수 없다.
        if context.isPreview { completion(.sample()); return }
        Task {
            let memos = await WidgetVault.memos()
            completion(.make(memos, at: Date(), seen: NowSeen.load()))
        }
    }

    /// 장면은 「지금」이 바뀌는 순간마다 하나 — 시각이 지나 「지남」이 되고, 자정에 오늘이 바뀐다
    /// (`WidgetAgenda.moments`). 앱이 파일을 바꾸면 `WidgetRefresher` 가 처음부터 다시 부른다.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NowEntry>) -> Void) {
        Task {
            let memos = await WidgetVault.memos()
            let seen = NowSeen.load()
            let entries = WidgetAgenda.moments(memos, now: Date()).map { NowEntry.make(memos, at: $0, seen: seen) }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

// MARK: - 얼굴

/// 확장 안에서는 시스템이 크기를 준다. 얼굴(`NowView`)은 크기를 손으로도 받는다 — 렌더 검증이 그렇게 부른다.
private struct NowRoot: View {
    let entry: NowEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        NowView(entry: entry, family: family)
            .containerBackground(for: .widget) { Paper.surface }
    }
}

struct NowView: View {
    let entry: NowEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        #if os(iOS)
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        #endif
        default: small
        }
    }

    /// 한 장 — 이유와 제목. 나머지는 「외 N장」으로만.
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let card = entry.cards.first {
                reason(card, lines: 2)
                Text(card.memo.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(3)
                Spacer(minLength: 0)
                if entry.cards.count > 1 {
                    Text("외 \(entry.cards.count - 1)장")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Spacer(minLength: 0)
                empty
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.cards.first.map { WidgetLink.memo($0.id) } ?? WidgetLink.write)
    }

    /// 세 장 — 한 줄씩.
    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.cards.isEmpty {
                Spacer(minLength: 0)
                empty
                Spacer(minLength: 0)
            } else {
                ForEach(entry.cards) { card in
                    Link(destination: WidgetLink.memo(card.id)) { row(card, titleLines: 1) }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.cards.isEmpty ? WidgetLink.write : nil)
    }

    /// 세 장과 「다음」.
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.cards.isEmpty {
                empty.padding(.vertical, 8)
            } else {
                ForEach(entry.cards) { card in
                    Link(destination: WidgetLink.memo(card.id)) { row(card, titleLines: 2, roomy: true) }
                }
            }
            if !entry.upcoming.isEmpty {
                Text("다음")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entry.upcoming) { row in
                        Link(destination: WidgetLink.memo(row.id)) { upcomingRow(row) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.cards.isEmpty && entry.upcoming.isEmpty ? WidgetLink.write : nil)
    }

    private var header: some View {
        Text("지금")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("펼칠 것이 없어요")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paper.ink)
            Text("적어 두면 여기 올라와요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func reason(_ card: Recall.Card, lines: Int) -> some View {
        Label(WidgetWords.reason(card, now: entry.date), systemImage: WidgetWords.symbol(card.reason))
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(Theme.accentInk)
            .lineLimit(lines)
    }

    /// 종이 한 장 — 이유 한 줄, 제목 한두 줄. `roomy` 는 큰 위젯의 숨 쉴 자리.
    private func row(_ card: Recall.Card, titleLines: Int, roomy: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: roomy ? 4 : 2) {
            reason(card, lines: 1)
            Text(card.memo.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .lineLimit(titleLines)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, roomy ? 12 : 10)
        .padding(.vertical, roomy ? 10 : 6)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.accentInk.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    /// 「내일 · 오후 3:00   치과」 — 시각이 없으면 날만.
    private func upcomingRow(_ row: WidgetAgenda.Upcoming) -> some View {
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

    #if os(iOS)
    /// 잠금 화면의 한 장 — 색은 시스템이 걷어 내므로 계층으로만 말한다.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let card = entry.cards.first {
                Label(WidgetWords.reason(card, now: entry.date), systemImage: WidgetWords.symbol(card.reason))
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .widgetAccentable()
                    .lineLimit(1)
                Text(card.memo.title)
                    .font(.headline)
                    .lineLimit(2)
            } else {
                Label("지금", systemImage: "note.text")
                    .font(.caption2.weight(.medium))
                    .widgetAccentable()
                Text("펼칠 것이 없어요")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.cards.first.map { WidgetLink.memo($0.id) } ?? WidgetLink.write)
    }

    /// 시계 위의 한 줄 — 「🔔 오후 3:00 치과 예약」.
    private var inline: some View {
        Group {
            if let card = entry.cards.first {
                Label {
                    Text(verbatim: "\(WidgetWords.shortReason(card)) \(card.memo.title)")
                } icon: {
                    Image(systemName: WidgetWords.symbol(card.reason))
                }
            } else {
                Label("지금 펼칠 것이 없어요", systemImage: "note.text")
            }
        }
        .widgetURL(entry.cards.first.map { WidgetLink.memo($0.id) } ?? WidgetLink.write)
    }
    #endif
}
