import LazyMemoCore
import SwiftUI

/// 휴지통 — 최근 삭제·되돌리기 (MOBILE_DESIGN §7). 비우기 단추는 없다 —
/// 영구 삭제는 보존 기간이 지난 뒤 앱만 한다 (D6, 규칙이 아니라 배선).
///
/// **다른 기기의 판은 위에 따로 선다** (`MemoStore.conflicts`). 두 기기가 따로 고쳐 만나면 앱이
/// 늦은 판을 자리에 두고 진 판을 여기 앉히는데(`ConflictSettlement`), 지운 메모 사이에 섞이면
/// 사람은 그런 일이 있었는지조차 모른다. 줄을 누르면 두 글을 나란히 견주고, **이 판으로**(맞바꾼다)
/// 또는 **둘 다 남기기**(되돌린다)를 고른다 — 맥 메뉴와 같은 낱말이고, 어느 쪽도 글을 없애지 않는다.
struct TrashView: View {
    let store: MemoStore
    let reveal: Reveal

    /// 마지막으로 되돌린 줄. 휴지통을 나갈 때 목록이 그리로 간다 — 되돌리는
    /// 순간 밝히면 여기서는 안 보이고, 돌아갈 즈음엔 이미 꺼져 있다.
    @State private var lastRestored: ULID?
    /// 견주는 중인 다른 판.
    @State private var comparing: Memo?

    private var conflicts: [Memo] { store.conflicts }
    private var deleted: [Memo] {
        let conflictIDs = Set(conflicts.map(\.id))
        return store.trash.filter { !conflictIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if !conflicts.isEmpty {
                Section {
                    ForEach(conflicts) { memo in conflictRow(memo) }
                } header: {
                    Text("다른 기기의 판 \(conflicts.count)장 — 따로 고친 글이 만났습니다")
                        .font(.footnote).foregroundStyle(.secondary).textCase(nil)
                } footer: {
                    Text("늦게 고친 쪽이 자리에 있습니다. 눌러서 견주고 고르세요 — 어느 쪽도 없어지지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(deleted) { memo in
                HStack(spacing: 8) {
                    MemoRowView(memo: memo, retired: true)
                    Button("되돌리기") { restore(memo) }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("restore")
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading) {
                    Button { restore(memo) } label: { Label("되돌리기", systemImage: "arrow.uturn.backward") }
                        .tint(Theme.accent)
                }
            }
            if store.trash.isEmpty {
                Text("비었습니다").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                Text("30일이 지나면 스스로 비웁니다").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Paper.surface)
        .navigationTitle("휴지통")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onDisappear { if let lastRestored { reveal.show(lastRestored) } }
        .sheet(item: $comparing) { loser in
            if let winner = loser.conflictOf.flatMap(store.memo) {
                ConflictCompareSheet(winner: winner, loser: loser, adopt: { adopt(loser) }, keepBoth: { restore(loser) })
            }
        }
    }

    /// 다른 판 한 줄 — 어느 메모의 것인지와 다른 판의 첫 줄. 누르면 견준다.
    private func conflictRow(_ loser: Memo) -> some View {
        let winner = loser.conflictOf.flatMap(store.memo)
        return Button { comparing = loser } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("「\(winner?.title ?? loser.title)」의 다른 판")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Paper.ink)
                Text(loser.title)
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("conflict")
        .accessibilityHint("눌러서 두 글을 견주고 고릅니다")
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading) {
            Button { adopt(loser) } label: { Label("이 판으로", systemImage: "arrow.left.arrow.right") }
                .tint(Theme.accent)
            Button { restore(loser) } label: { Label("둘 다 남기기", systemImage: "arrow.uturn.backward") }
        }
    }

    /// 돌아온 줄을 목록이 보이게 — 돌아가서 그리로 스크롤하고 밝힌다.
    private func restore(_ memo: Memo) {
        comparing = nil
        Task {
            try? await store.restore(memo.id)
            lastRestored = memo.id
        }
    }

    /// 다른 판을 이 판으로 — 자리의 메모가 그 글을 받으니 돌아가서 그 메모를 밝힌다.
    private func adopt(_ loser: Memo) {
        comparing = nil
        Task {
            try? await store.adoptConflict(loser.id)
            lastRestored = loser.conflictOf
        }
    }
}

/// 두 글을 나란히 — 지금 자리의 것과 다른 판. 고르는 단추 둘은 맥 메뉴와 같은 낱말이다.
private struct ConflictCompareSheet: View {
    let winner: Memo
    let loser: Memo
    let adopt: () -> Void
    let keepBoth: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    version("지금 자리", winner)
                    version("다른 판", loser)
                }
                .padding()
            }
            .background(Paper.surface)
            .navigationTitle("어느 쪽으로 할까요")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("그만두기") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button(action: adopt) {
                        Text("이 판으로").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentInk)
                    .accessibilityIdentifier("adopt-conflict")
                    Button(action: keepBoth) {
                        Text("둘 다 남기기").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("keep-both")
                    Text("이 판으로: 자리의 글과 맞바꿉니다 — 밀려난 글은 휴지통에 남아 한 번 더 바꿀 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private func version(_ label: LocalizedStringKey, _ memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(MemoTimeLabel.elapsed(memo.updated) + " 고침").font(.caption).foregroundStyle(.tertiary)
            }
            Text(memo.body.isEmpty ? "(빈 글)" : memo.body)
                .font(.body)
                .foregroundStyle(Paper.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
