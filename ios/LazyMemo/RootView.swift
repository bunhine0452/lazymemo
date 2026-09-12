import LazyMemoCore
import SwiftUI

/// 첫 화면. 지금은 **스모크** — 적으면 파일이 되고, 파일이 목록에 보인다.
/// 빠른 입력·달력·폴더는 다음 단계에서 이 자리를 채운다.
struct RootView: View {
    let model: AppModel

    var body: some View {
        switch model.phase {
        case .opening:
            ProgressView()
        case .failed(let reason):
            ContentUnavailableView(reason, systemImage: "folder.badge.questionmark")
        case .ready(let store, let usingCloud):
            MemoListView(store: store, usingCloud: usingCloud)
        }
    }
}

private struct MemoListView: View {
    let store: MemoStore
    let usingCloud: Bool

    @State private var draft = ""
    @FocusState private var composing: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // ⏎ 는 다음 줄이다 — 메모는 한 줄로 끝나지 않는다 (맥과 같다).
                    // 적기 끝은 아래 단추.
                    TextField("여기에 적기", text: $draft, axis: .vertical)
                        .accessibilityIdentifier("capture")
                        .focused($composing)
                    Button(leaveLabel, action: leave)
                        .accessibilityIdentifier("leave")
                        .disabled(InboundNote.make(text: draft) == nil)
                }
                Section {
                    ForEach(store.active) { memo in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(memo.title)
                            if let day = Schedule(memo).day() {
                                Text(day.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text(usingCloud ? "iCloud 의 LazyMemo 폴더를 맥과 함께 봅니다" : "이 기기에만 남습니다 — iCloud 가 꺼져 있습니다")
                }
            }
            .navigationTitle("lazymemo")
            .onAppear { composing = true }
        }
    }

    /// 날짜가 읽혔으면 단추가 그렇게 말한다 — 맥의 「달력에 남기기」와 같다.
    private var leaveLabel: String {
        guard let inbound = InboundNote.make(text: draft) else { return "메모 남기기" }
        let note = NoteReader.read(inbound)
        return note.due == nil && note.at == nil ? "메모 남기기" : "달력에 남기기"
    }

    /// 적기 끝. 맥의 빠른 입력과 **같은 규칙**으로 읽는다 — `내일 3시` 는 일정이
    /// 되고 `@강남역` 은 장소가 된다 (`NoteReader`).
    private func leave() {
        guard let inbound = InboundNote.make(text: draft) else { return }
        let note = NoteReader.read(inbound)
        draft = ""
        Task {
            try? await store.create(
                body: note.body, due: note.due, at: note.at, every: note.every, place: note.place
            )
        }
    }
}
