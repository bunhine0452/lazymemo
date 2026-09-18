import LazyMemoCore
import LazyMemoWidgetsCore
import SwiftUI

/// 「지금」 — 목록 위의 최대 세 장 (RECALL_PLAN 「지금 세 장」).
///
/// 차례는 `Recall.nowCards` 가 정한다 — 다가오는 것부터. 여기서는 **왜 올라왔는지와
/// 언제인지**를 적을 뿐이다 — 이유 없는 카드는 "앱이 골라 준 것" 이고, 이유가 보이는
/// 카드는 "내가 정해 둔 것" 이다. 띠에 오른 메모는 아래 목록에서 빠진다 — 같은 줄이
/// 두 번 서면 화면이 무겁다. 대신 카드도 줄이 하는 일(고정·지우기)을 전부 한다.
///
/// **「봤어요」** 가 카드를 내려놓는다. 지나간 시각의 카드는 놓친 사람을 위해 남지만,
/// 본 사람에게는 치울 거리다. 내려놓은 것은 이 기기만 기억하고(`NowSeen`), 시각을
/// 미루거나 날이 바뀌면 다시 오른다 (`Recall.Card.stamp`).
///
/// 찾는 중이거나 폴더를 골랐을 때는 없다 — 범위가 좁혀진 화면 위에 범위 밖의
/// 카드가 서면 그 화면이 무엇을 보여 주는지 흐려진다 (`StackView`).
struct NowBand: View {
    let cards: [Recall.Card]
    let now: Date
    let open: (Memo) -> Void
    let putDown: (Recall.Card) -> Void
    /// 「하루 미루기」 — 일정이 있는 카드만. 달력 탭의 밀기와 같은 낱말·같은 방향 (2026-09-17 편의성 감사 §2.1).
    let postpone: (Memo) -> Void
    let pin: (Memo) -> Void
    let delete: (Memo) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text("지금")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("now-band")
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        ForEach(cards) { card in
            Button { open(card.memo) } label: { row(card) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Self.reasonText(card, now: now)), \(card.memo.title)")
                .accessibilityHint("메모를 엽니다")
                .accessibilityIdentifier("now-card")
                .accessibilityActions {
                    Button("봤어요") { putDown(card) }
                    if card.memo.isScheduled { Button("하루 미루기") { postpone(card.memo) } }
                    Button(card.memo.pinned ? String(localized: "고정 해제") : String(localized: "고정")) { pin(card.memo) }
                    Button("지우기") { delete(card.memo) }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { delete(card.memo) } label: { Label("지우기", systemImage: "trash") }
                }
                .swipeActions(edge: .leading) {
                    // 일정이 있으면 미루기가 앞이다 — 끝까지 밀면 그것 (달력 탭과 같다).
                    if card.memo.isScheduled {
                        Button { postpone(card.memo) } label: { Label("미루기", systemImage: "arrow.right") }
                            .tint(Theme.accent)
                    }
                    Button { pin(card.memo) } label: {
                        Label(card.memo.pinned ? String(localized: "고정 해제") : String(localized: "고정"), systemImage: card.memo.pinned ? "pin.slash" : "pin")
                    }
                    .tint(card.memo.isScheduled ? Theme.highlightInk : Theme.accent)
                }
                .contextMenu {
                    Button { putDown(card) } label: { Label("봤어요", systemImage: "checkmark") }
                    if card.memo.isScheduled {
                        Button { postpone(card.memo) } label: { Label("하루 미루기", systemImage: "arrow.right") }
                    }
                    Button { pin(card.memo) } label: {
                        Label(card.memo.pinned ? String(localized: "고정 해제") : String(localized: "고정"), systemImage: card.memo.pinned ? "pin.slash" : "pin")
                    }
                    Divider()
                    Button(role: .destructive) { delete(card.memo) } label: { Label("지우기", systemImage: "trash") }
                }
        }
    }

    private func row(_ card: Recall.Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(Self.reasonText(card, now: now), systemImage: Self.symbol(card.reason))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.accentInk)
                Spacer(minLength: 8)
                // 내려놓기는 카드 위에 보인다 — 쓸어 넘기는 손짓은 아는 사람만 안다.
                // 알약은 28pt 그대로 두고 **누르는 자리만** 44 로 넓힌다
                // (HIG Buttons — "a button needs a hit region of at least 44x44 pt").
                // 이 단추는 **카드 전체가 단추인 그 안에** 있다 — 과녁이 좁으면
                // 「봤어요」를 누르려다 메모가 열린다. 늘린 만큼은 카드의 여백을
                // 먹으므로 보이는 것은 달라지지 않는다.
                Button { putDown(card) } label: {
                    Text("봤어요")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(Paper.ink.opacity(0.06), in: Capsule())
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("봤어요")
                .accessibilityHint("「지금」에서 내려놓습니다")
                .accessibilityIdentifier("now-seen")
            }
            Text(card.memo.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 「봤어요」의 과녁이 28 → 44 로 자란 만큼 위를 덜어 낸다. 넓어진 것은
        // 누르는 자리이지 카드가 아니다.
        .padding(.top, 6)
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.bottom, 14)
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

/// 「봤어요」로 내려놓은 것 — 이 기기의 기억. 위젯도 같은 기억을 보므로 앱 밖에 산다
/// (`LazyMemoWidgetsCore.NowSeen`, App Group defaults).
typealias NowSeen = LazyMemoWidgetsCore.NowSeen

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
