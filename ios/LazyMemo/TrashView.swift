import LazyMemoCore
import SwiftUI

/// 휴지통 — 최근 삭제·되돌리기 (MOBILE_DESIGN §7). 비우기 단추는 없다 —
/// 영구 삭제는 보존 기간이 지난 뒤 앱만 한다 (D6, 규칙이 아니라 배선).
struct TrashView: View {
    let store: MemoStore
    let reveal: Reveal

    /// 마지막으로 되돌린 줄. 휴지통을 나갈 때 목록이 그리로 간다 — 되돌리는
    /// 순간 밝히면 여기서는 안 보이고, 돌아갈 즈음엔 이미 꺼져 있다.
    @State private var lastRestored: ULID?

    var body: some View {
        List {
            ForEach(store.trash) { memo in
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
    }

    /// 돌아온 줄을 목록이 보이게 — 돌아가서 그리로 스크롤하고 밝힌다.
    private func restore(_ memo: Memo) {
        Task {
            try? await store.restore(memo.id)
            lastRestored = memo.id
        }
    }
}
