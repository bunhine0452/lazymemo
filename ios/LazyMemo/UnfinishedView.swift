import LazyMemoCore
import LazyMemoReminders
import LazyMemoWidgetsCore
import SwiftUI

/// 「지금」 세 장 곁의 조용한 요약 — 「놓친 2 · 오늘 5 · 나중에 3」 (인계서 묶음 4 `#unfinished-recall`).
///
/// 세 장이 전부라고 오해하지 않게 하고, 놓친 미처리는 날이 바뀌어도 여기서 찾는다. 푸시는 없다 —
/// 매일 다시 울리면 그것은 알림이 아니라 소음이다. 누르면 전체(`UnfinishedSheet`)로 간다.
struct RecallSummaryRow: View {
    let summary: Recall.Summary
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                Image(systemName: summary.missed.isEmpty ? "list.bullet" : "exclamationmark.circle")
                    .foregroundStyle(summary.missed.isEmpty ? .secondary : Theme.highlightInk)
                Text(Self.line(summary))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(summary.missed.isEmpty ? .secondary : Paper.ink)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Paper.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.line(summary))
        .accessibilityHint("전체를 봅니다 — 놓친 것부터")
        .accessibilityIdentifier("recall-summary")
    }

    /// 「놓친 2 · 오늘 5 · 나중에 3」 — 0 인 조각은 적지 않는다. 놓친 것이 없으면 「오늘 5 · 나중에 3」.
    static func line(_ summary: Recall.Summary) -> String {
        var parts: [String] = []
        if !summary.missed.isEmpty { parts.append(String(localized: "놓친 \(summary.missed.count)")) }
        if !summary.today.isEmpty { parts.append(String(localized: "오늘 \(summary.today.count)")) }
        if !summary.later.isEmpty { parts.append(String(localized: "나중에 \(summary.later.count)")) }
        return parts.joined(separator: " · ")
    }
}

/// 놓친 것·오늘·나중에의 전체 — 원문으로 가는 줄과 그 자리에서 끝내거나 미루거나 넣어 두는 손.
///
/// 「다시 볼 때 원문과 처리 행동을 함께」(인계서 §2). 완료·보관은 파일에 적혀 양 기기가 알고,
/// 「내일 아침」은 다시 볼 시각만 옮긴다 — 일정은 그대로 (§4 「다시 보기 변경」).
struct UnfinishedSheet: View {
    let store: MemoStore
    let now: Date
    let seen: [ULID: Date]
    let open: (Memo) -> Void
    let markDone: (Memo) -> Void
    let archive: (Memo) -> Void
    let postponeToMorning: (Memo) -> Void
    @Environment(\.dismiss) private var dismiss

    private var summary: Recall.Summary { Recall.summary(store.memos, now: now, seen: seen) }

    var body: some View {
        NavigationStack {
            List {
                section(String(localized: "놓친 것"), summary.missed, empty: String(localized: "놓친 것이 없어요"), id: "missed")
                section(String(localized: "오늘"), summary.today, empty: nil, id: "today")
                section(String(localized: "나중에"), summary.later, empty: nil, id: "later")
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Paper.surface)
            .navigationTitle("전체")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ memos: [Memo], empty: String?, id: String) -> some View {
        if !memos.isEmpty || empty != nil {
            Section {
                if memos.isEmpty, let empty {
                    Text(empty).font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(memos) { memo in
                    Button { open(memo); dismiss() } label: { row(memo) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("unfinished-\(id)")
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if memo.isActionable {
                                Button { markDone(memo) } label: { Label("완료", systemImage: "checkmark.circle") }.tint(Theme.accent)
                            }
                            Button { postponeToMorning(memo) } label: { Label("내일 아침", systemImage: "sunrise") }.tint(Theme.highlightInk)
                        }
                        .swipeActions(edge: .trailing) {
                            Button { archive(memo) } label: { Label("보관", systemImage: "archivebox") }.tint(.secondary)
                        }
                        .contextMenu {
                            if memo.isActionable {
                                Button { markDone(memo) } label: { Label("완료", systemImage: "checkmark.circle") }
                            }
                            Button { postponeToMorning(memo) } label: { Label("내일 아침 9시에 다시", systemImage: "sunrise") }
                            Button { archive(memo) } label: { Label("보관", systemImage: "archivebox") }
                        }
                }
            } header: {
                Text("\(title) \(memos.count)")
            }
        }
    }

    private func row(_ memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memo.title).font(.body.weight(.medium)).foregroundStyle(Paper.ink).lineLimit(2)
            HStack(spacing: 8) {
                Text(MemoTimeLabel.text(for: memo, now: now)).monospacedDigit()
                if let lead = memo.surfaceLead { Text(lead) }
                if let place = memo.place { Text("@" + place).lineLimit(1) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// 보관한 것 — 당장 안 볼 기록. 검색에는 있고 목록에는 없다. 여기서 도로 꺼내거나 연다.
struct ArchivedSheet: View {
    let store: MemoStore
    let now: Date
    let open: (Memo) -> Void
    let unarchive: (Memo) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.archivedMemos.isEmpty {
                    Text("보관한 것이 없어요").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.archivedMemos) { memo in
                    Button { open(memo); dismiss() } label: {
                        MemoRowView(memo: memo, now: now)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("archived-row")
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { unarchive(memo) } label: { Label("꺼내기", systemImage: "tray.and.arrow.up") }.tint(Theme.accent)
                    }
                    .contextMenu {
                        Button { unarchive(memo) } label: { Label("보관에서 꺼내기", systemImage: "tray.and.arrow.up") }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Paper.surface)
            .navigationTitle("보관 \(store.archivedMemos.count)장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}
