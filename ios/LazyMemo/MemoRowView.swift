import LazyMemoCore
import SwiftUI

/// 무더기의 한 줄 — 점 · 제목 · 시각 한 조각 (MOBILE_DESIGN §4). 맥 메뉴 목록과 같은 낱말이다.
struct MemoRowView: View {
    let memo: Memo
    var now: Date = Date()
    /// 55% 로 바래 보이는 자리(휴지통)에서 쓴다.
    var faded: Bool = false

    private var secondLine: String? {
        let lines = memo.body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        return lines[1].trimmingCharacters(in: CharacterSet(charactersIn: "#-*> "))
    }

    private var scheduled: Bool { memo.due != nil || memo.at != nil }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(memo.tidied == nil ? memo.color.ink : .clear)
                .overlay(Circle().stroke(memo.color.ink, lineWidth: memo.tidied == nil ? 0 : 1.5))
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if memo.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accentInk)
                    }
                    Text(memo.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                }
                if let secondLine {
                    Text(secondLine)
                        .font(.subheadline)
                        .foregroundStyle(Paper.fadedInk)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MemoTimeLabel.text(for: memo, now: now))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(scheduled ? Theme.highlightInk : Paper.fadedInk)
                    .fixedSize()
                if let place = memo.place {
                    Text("@" + place)
                        .font(.caption2)
                        .foregroundStyle(Paper.fadedInk)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
        .opacity(faded ? 0.55 : MemoAge.of(memo, now: now).presence)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// 「장보기, 내일 15시, 노랑, 고정됨」
    private var spoken: String {
        var parts = [memo.title, MemoTimeLabel.text(for: memo, now: now), memo.color.label]
        if memo.pinned { parts.append("고정됨") }
        if let place = memo.place { parts.append(place) }
        return parts.joined(separator: ", ")
    }
}
