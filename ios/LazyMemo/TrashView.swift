import LazyMemoCore
import SwiftUI

/// 휴지통 — 최근 삭제·되돌리기 (MOBILE_DESIGN §7). 비우기 단추는 없다 —
/// 영구 삭제는 보존 기간이 지난 뒤 앱만 한다 (D6, 규칙이 아니라 배선).
struct TrashView: View {
    let store: MemoStore
    let undo: UndoModel

    var body: some View {
        List {
            ForEach(store.trash) { memo in
                HStack(spacing: 8) {
                    MemoRowView(memo: memo, faded: true)
                    Button("되돌리기") { restore(memo) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentInk)
                        .frame(minHeight: 44)
                        .padding(.trailing, 12)
                        .accessibilityIdentifier("restore")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading) {
                    Button { restore(memo) } label: { Label("되돌리기", systemImage: "arrow.uturn.backward") }
                        .tint(Theme.accent)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let deleted = memo.deleted {
                        Text("\(MemoTimeLabel.elapsed(deleted)) 지움")
                            .font(.caption2).foregroundStyle(Paper.fadedInk)
                            .padding(.trailing, 100).padding(.bottom, 2)
                    }
                }
            }
            if store.trash.isEmpty {
                Text("비었습니다").font(.subheadline).foregroundStyle(Paper.fadedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                Text("30일이 지나면 스스로 비웁니다").font(.caption).foregroundStyle(Paper.fadedInk)
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
    }

    private func restore(_ memo: Memo) {
        Task { try? await store.restore(memo.id) }
    }
}
