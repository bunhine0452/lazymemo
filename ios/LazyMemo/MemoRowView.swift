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

    /// 제목 다음의 글 한 줄. 사진 참조는 글이 아니라 아래 「사진 1장」으로 센다 (`Memo.previewLine`).
    private var secondLine: String? { memo.previewLine }

    /// 긴 글은 이 줄이 이만큼부터 「길다」 — 붙여 넣은 글 한 덩이가 이 언저리다.
    static let longBody = 300

    /// 미리보기에 내줄 줄 수.
    ///
    /// **짧은 줄은 그대로 둔다.** 목록은 훑는 자리라 칸이 다 같은 키일 때 가장 빨리 읽히고,
    /// 두 줄이면 대개 다 담긴다. 그런데 긴 글을 붙여 넣은 메모는 두 줄로 잘리면 **무슨 메모인지
    /// 알 수 없다** — 제목 한 줄이 링크거나 날짜뿐인 일이 흔하기 때문이다. 그런 칸만 넉 줄까지
    /// 편다. 짧은 줄은 `lineLimit` 을 올려도 그만큼 안 자라니 칸의 키는 그대로다.
    /// 큰 글자에서는 한 줄이 더 넓게 퍼지므로 원래의 셋에서 시작한다.
    static func previewLines(bodyLength: Int, accessibility: Bool) -> Int {
        let base = accessibility ? 3 : 2
        return bodyLength > longBody ? 4 : base
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
                        .lineLimit(Self.previewLines(
                            bodyLength: memo.body.count, accessibility: typeSize.isAccessibilitySize
                        ))
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
            HStack(spacing: 12) { timeLabel; placeLabel; photoLabel }
            VStack(alignment: .leading, spacing: 6) { timeLabel; placeLabel; photoLabel }
        }
        .font(.caption)
    }

    /// 붙인 사진은 경로가 아니라 수로 — 목록에서 `![](attachments/…)` 를 읽는 사람은 없다.
    @ViewBuilder
    private var photoLabel: some View {
        let photos = memo.photoCount
        if photos > 0 {
            Label(String(localized: "사진 \(photos)장"), systemImage: "photo")
                .foregroundStyle(.secondary)
        }
    }

    /// 휴지통에서는 「언제 지웠나」가 유일하게 쓸모 있는 시각이다 — 30일 뒤에
    /// 사라지는 것이 그 날로부터 세니까.
    private var timeText: String {
        if retired, let deleted = memo.deleted { return String(localized: "\(MemoTimeLabel.elapsed(deleted, now: now)) 지움") }
        return MemoTimeLabel.text(for: memo, now: now)
    }

    private var timeLabel: some View {
        Label(timeText, systemImage: retired ? "trash" : scheduled ? "calendar" : "clock")
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
        var parts = [memo.title, timeText, memo.color.label]
        if memo.pinned { parts.append(String(localized: "고정됨")) }
        if let place = memo.place { parts.append(place) }
        if memo.photoCount > 0 { parts.append(String(localized: "사진 \(memo.photoCount)장")) }
        return parts.joined(separator: ", ")
    }
}
