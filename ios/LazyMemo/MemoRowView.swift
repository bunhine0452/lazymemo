import LazyMemoCore
import SwiftUI

/// 목록의 한 줄 — 점 · 제목 · 시각 한 조각 (MOBILE_DESIGN §4). 맥 메뉴 목록과 같은 낱말이다.
///
/// 바램은 **제목의 색**으로 말한다 — 줄 전체를 흐리게 하면 캡션이 대비를 잃는다.
/// 대비 높임이 켜져 있으면 바래지 않는다. 큰 글자에서는 시각이 제목 아래로 내려간다.
struct MemoRowView: View {
    let memo: Memo
    var now: Date = Date()
    /// 휴지통처럼 처음부터 물러난 자리.
    var retired: Bool = false

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    private var secondLine: String? {
        let lines = memo.body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        return lines[1].trimmingCharacters(in: CharacterSet(charactersIn: "#-*> "))
    }

    private var scheduled: Bool { memo.due != nil || memo.at != nil }

    private var titleInk: Color {
        if retired { return .secondary }
        if contrast == .increased { return Paper.ink }
        return MemoAge.of(memo, now: now) <= .recent ? Paper.ink : .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            dot.padding(.top, 8)
            VStack(alignment: .leading, spacing: 8) {
                title
                if let secondLine {
                    Text(secondLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                        .lineSpacing(3)
                }
                when
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(minHeight: 88, alignment: .leading)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(memo.pinned ? Theme.accentInk.opacity(0.35) : Paper.ink.opacity(contrast == .increased ? 0.35 : 0.07), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var dot: some View {
        Circle()
            .fill(memo.tidied == nil ? memo.color.ink : .clear)
            .overlay(Circle().stroke(memo.color.ink, lineWidth: memo.tidied == nil ? 0 : 1.5))
            .frame(width: 8, height: 8)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
    }

    private var title: some View {
        HStack(spacing: 6) {
            if memo.pinned {
                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Theme.accentInk)
            }
            Text(memo.title).font(.body.weight(.semibold)).foregroundStyle(titleInk).lineLimit(2)
        }
    }

    private var when: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { timeLabel; placeLabel }
            VStack(alignment: .leading, spacing: 6) { timeLabel; placeLabel }
        }
        .font(.caption)
    }

    private var timeLabel: some View {
        Label(MemoTimeLabel.text(for: memo, now: now), systemImage: scheduled ? "calendar" : "clock")
            .monospacedDigit()
            .foregroundStyle(scheduled && !retired ? Theme.highlightInk : .secondary)
    }

    @ViewBuilder
    private var placeLabel: some View {
        if let place = memo.place {
            Label(place, systemImage: "mappin")
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    /// 「장보기, 내일 15시, 노랑, 고정됨」
    private var spoken: String {
        var parts = [memo.title, MemoTimeLabel.text(for: memo, now: now), memo.color.label]
        if memo.pinned { parts.append("고정됨") }
        if let place = memo.place { parts.append(place) }
        return parts.joined(separator: ", ")
    }
}
