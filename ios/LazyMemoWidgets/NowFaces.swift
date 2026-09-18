import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI
import WidgetKit
#if os(iOS)
import AppIntents
#endif

/// 「지금」의 얼굴들.
///
/// 한 장의 카드는 **줄머리의 색 획 · 이유 한 줄 · 제목**이다. 1초에 읽히는 것은 이유와 시각이고
/// (「다시 보기 · 오후 3:00」), 3초에 읽히는 것은 제목이다 — 이유가 보이지 않는 카드는 앱이 골라
/// 준 것이고 보이는 카드는 내가 정해 둔 것이다 (MOBILE_DESIGN §4).
struct NowView: View {
    let entry: NowEntry
    let family: WidgetFamily

    @Environment(\.widgetTheme) private var theme

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

    // MARK: 시스템 가족

    /// 한 장 — 이유와 제목. 나머지는 「외 N장」으로만.
    ///
    /// "Small widgets use their limited space to typically show a single piece of information."
    private var small: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.headGap) {
            head
            if let card = entry.cards.first {
                Link(destination: WidgetLink.memo(card.id)) {
                    cardBody(card, titleLines: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                Spacer(minLength: 0)
                if entry.cards.count > 1 {
                    Text("외 \(entry.cards.count - 1)장")
                        .font(.caption2)
                        .foregroundStyle(theme.secondary)
                }
            } else {
                Spacer(minLength: 0)
                EmptyFace(line: Text("펼칠 것이 없어요"))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.cards.first.map { WidgetLink.memo($0.id) } ?? WidgetLink.write)
    }

    /// 세 장 — 한 줄씩, 오른쪽에 「봤어요」.
    private var medium: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.headGap) {
            head
            if entry.cards.isEmpty {
                Spacer(minLength: 0)
                EmptyFace(line: Text("펼칠 것이 없어요"))
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.cards) { card in row(card, titleLines: 1, roomy: false) }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.cards.isEmpty ? WidgetLink.write : nil)
    }

    /// 세 장과 「다음」 — 오늘 뒤에 올 일정 넉 줄까지.
    private var large: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.headGap) {
            head
            if entry.cards.isEmpty {
                EmptyFace(line: Text("펼칠 것이 없어요")).padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: WidgetMetrics.rowGap) {
                    ForEach(entry.cards) { card in row(card, titleLines: 2, roomy: true) }
                }
            }
            if !entry.upcoming.isEmpty {
                Text("다음")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(theme.secondary)
                    .padding(.top, 6)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.upcoming) { line in
                        Link(destination: WidgetLink.memo(line.id)) { AgendaRow(row: line, now: entry.date) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.cards.isEmpty && entry.upcoming.isEmpty ? WidgetLink.write : nil)
    }

    private var head: some View {
        WidgetHead(kind: Text("지금"), trailing: Text(WidgetWords.headDay(entry.date)))
    }

    /// 카드 한 장의 속 — 색 획, 이유, 제목. 카드마다 종이를 깔지 않는다 (`InkBar`).
    private func cardBody(_ card: Recall.Card, titleLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(WidgetWords.reason(card, now: entry.date), systemImage: WidgetWords.symbol(card.reason))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(theme.accentInk)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .widgetAccentable()
            Text(card.memo.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(titleLines)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.leading)
                // 잠금 화면에서 제목은 가려진다 — 이유와 시각은 남는다.
                .privacySensitive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkBar(theme.papery ? theme.ink(for: card.memo.color) : theme.accentInk)
        .accessibilityElement(children: .combine)
    }

    /// 누르는 자리 둘 — 왼쪽은 그 메모로, 오른쪽은 내려놓기. **겹치지 않게 나란히 둔다.**
    private func row(_ card: Recall.Card, titleLines: Int, roomy: Bool) -> some View {
        HStack(spacing: 8) {
            Link(destination: WidgetLink.memo(card.id)) {
                cardBody(card, titleLines: titleLines)
                    .frame(maxWidth: .infinity, minHeight: roomy ? 44 : 34, alignment: .leading)
                    .contentShape(Rectangle())
            }
            #if os(iOS)
            SeenButton(card: card, roomy: roomy)
            #endif
        }
    }

    // MARK: 잠금 화면

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
                    .privacySensitive()
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

    /// 시계 위의 한 줄 — 과녁이 하나뿐인 가족이다 ("inline accessory widgets offer only one tap target").
    private var inline: some View {
        Group {
            if let card = entry.cards.first {
                Label {
                    Text(verbatim: "\(WidgetWords.shortReason(card)) \(card.memo.title)").privacySensitive()
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

#if os(iOS)
/// 「봤어요」 — 위젯 안에서 끝나는 단추 (`SeenIntent`).
///
/// 보이는 것은 28pt 원이지만 과녁은 큰 가족에서 44, 중간에서 36×34 다 — 중간 위젯의 줄 높이가
/// 34 라 44 를 주면 위아래 줄의 과녁이 겹친다. 겹친 과녁은 44 보다 나쁘다.
struct SeenButton: View {
    let card: Recall.Card
    var roomy = false

    @Environment(\.widgetTheme) private var theme

    var body: some View {
        Button(intent: SeenIntent(id: card.id, stamp: card.stamp)) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondary)
                .frame(width: 28, height: 28)
                .background(theme.ink.opacity(0.07), in: Circle())
                .frame(width: roomy ? 44 : 36, height: roomy ? 44 : 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("봤어요"))
        .accessibilityHint(Text("「지금」에서 내려놓습니다"))
    }
}
#endif
