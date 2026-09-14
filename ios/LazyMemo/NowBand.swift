import LazyMemoCore
import SwiftUI

/// 「지금」 — 목록 위의 최대 세 장 (RECALL_PLAN 「지금 세 장」).
///
/// 오늘 다시 볼 것 → 오늘 일정 → 고정, 차례는 `Recall.nowCards` 가 정한다. 여기서는
/// **왜 올라왔는지와 언제인지**를 적을 뿐이다 — 이유 없는 카드는 "앱이 골라 준 것"
/// 이고, 이유가 보이는 카드는 "내가 정해 둔 것" 이다. 아래 목록에도 같은 줄이
/// 있다; 이 띠는 걸러 낸 결과가 아니라 오늘의 머리다.
///
/// 찾는 중이거나 폴더를 골랐을 때는 없다 — 범위가 좁혀진 화면 위에 범위 밖의
/// 카드가 서면 그 화면이 무엇을 보여 주는지 흐려진다 (`StackView`).
struct NowBand: View {
    let cards: [Recall.Card]
    let now: Date
    let open: (Memo) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("지금")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("now-band")
            ForEach(cards) { card in
                Button { open(card.memo) } label: { row(card) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Self.reasonText(card, now: now)), \(card.memo.title)")
                    .accessibilityHint("메모를 엽니다")
                    .accessibilityIdentifier("now-card")
            }
        }
    }

    private func row(_ card: Recall.Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(Self.reasonText(card, now: now), systemImage: Self.symbol(card.reason))
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.accentInk)
            Text(card.memo.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.accentInk.opacity(0.35), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    /// 「다시 보기 · 15:00」 · 「오늘 일정 · 15:00 지남」 · 「오늘 일정」 · 「고정」.
    static func reasonText(_ card: Recall.Card, now: Date) -> String {
        let time = card.moment.map { $0.formatted(date: .omitted, time: .shortened) }
        let passed = card.moment.map { $0 <= now } ?? false
        switch (card.reason, time, passed) {
        case (.revisit, let time?, false): return String(localized: "다시 보기 · \(time)")
        case (.revisit, let time?, true): return String(localized: "다시 보기 · \(time) 지남")
        case (.revisit, nil, _): return String(localized: "다시 보기")
        case (.today, let time?, false): return String(localized: "오늘 일정 · \(time)")
        case (.today, let time?, true): return String(localized: "오늘 일정 · \(time) 지남")
        case (.today, nil, _): return String(localized: "오늘 일정")
        case (.pinned, _, _): return String(localized: "고정")
        }
    }

    static func symbol(_ reason: Recall.Reason) -> String {
        switch reason {
        case .revisit: "bell.fill"
        case .today: "calendar"
        case .pinned: "pin.fill"
        }
    }
}

/// 조용히 지나가면 안 되는 실패 한 줄 — 저장소의 `trouble` 과 알림의 `trouble`.
///
/// 맥은 메뉴 첫머리가 읽는다; 폰은 목록의 머리가 읽는다. 저장 버튼이 없는 앱에서
/// 저장 실패가 안 보이면 사용자는 영영 모른다.
struct NoticeRow: View {
    let title: String
    var detail: String?
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.highlightInk)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Paper.ink)
                if let detail {
                    Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                }
                if let retry {
                    Button("다시 시도", action: retry).font(.footnote).buttonStyle(.bordered).buttonBorderShape(.capsule)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.highlightWash, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notice")
    }
}
