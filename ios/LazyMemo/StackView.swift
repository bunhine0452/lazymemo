import LazyMemoCore
import SwiftUI

/// 무더기 — 펜 위로 쌓이는 한 목록 (MOBILE_DESIGN §4).
///
/// 고정한 것이 펜에 가장 가깝고, 그 위로 최근순. 찾는 중이면 가장 맞는 것이
/// 펜에 가장 가깝다. 배열을 뒤집고 바닥에 닻을 내려 그렇게 만든다.
struct StackView: View {
    let session: AppModel.Session
    let pen: PenModel
    let undo: UndoModel
    let folders: FolderModel

    @State private var opened: ULID?
    @State private var namingFolder = false
    @State private var newFolderName = ""
    @State private var renaming: String?
    @State private var renamedTo = ""

    private var store: MemoStore { session.store }

    /// 첫째가 펜에 가장 가깝다 — 고정한 것, 그 다음 최근순 (`store.active` 의 차례
    /// 그대로). 찾는 중이면 가장 맞는 것이 첫째다.
    private var listed: [Memo] {
        MemoFolders.filter(pen.found ?? store.active, folder: folders.selected)
    }

    private var searching: Bool { pen.found != nil }

    var body: some View {
        // 펜 위로 쌓는다: 목록을 세로로 뒤집고 줄마다 도로 뒤집는다. 그래야 몇 장
        // 안 될 때도 줄이 펜 바로 위에 앉고, 새 줄이 펜 옆으로 들어온다.
        // 안전 영역은 손으로 준다 — 뒤집힌 목록에는 위아래가 바뀌어 들어가므로.
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            stack
                .scaleEffect(x: 1, y: -1)
                .ignoresSafeArea()
                .contentMargins(.top, insets.bottom + 8, for: .scrollContent)
                .contentMargins(.bottom, insets.top + 8, for: .scrollContent)
        }
        .background(Paper.surface)
        .safeAreaInset(edge: .top, spacing: 0) { folderBand }
        .navigationTitle("메모")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { id in
            MemoEditorView(store: store, id: id, undo: undo)
        }
        .alert("새 폴더", isPresented: $namingFolder) {
            TextField("이름", text: $newFolderName)
            Button("만들기") { folders.add(newFolderName); newFolderName = "" }
            Button("그만두기", role: .cancel) { newFolderName = "" }
        }
        .alert("폴더 이름 바꾸기", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("이름", text: $renamedTo)
            Button("바꾸기") {
                if let old = renaming { Task { await folders.rename(old, to: renamedTo) } }
                renaming = nil
            }
            Button("그만두기", role: .cancel) { renaming = nil }
        }
        .onChange(of: folders.selected) { _, selected in pen.folder = selected }
    }

    private var stack: some View {
        List {
            if listed.isEmpty {
                Text(searching ? "\(store.active.count)장 중 없다" : "적은 것이 여기 쌓입니다")
                    .font(.subheadline)
                    .foregroundStyle(Paper.fadedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .flipped()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("stack-empty")
            }

            ForEach(listed) { memo in
                // 줄에 › 를 달지 않는다 — 점·제목·시각뿐이다.
                Button { open(memo) } label: {
                    MemoRowView(memo: memo).flipped()
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { delete(memo) } label: {
                        Label("지우기", systemImage: "trash")
                    }
                    .tint(Theme.danger)
                }
                .swipeActions(edge: .leading) {
                    Button { pin(memo) } label: {
                        Label(memo.pinned ? "고정 해제" : "고정", systemImage: memo.pinned ? "pin.slash" : "pin")
                    }
                    .tint(Theme.accent)
                }
                .contextMenu {
                    Button { pin(memo) } label: {
                        Label(memo.pinned ? "고정 해제" : "고정", systemImage: memo.pinned ? "pin.slash" : "pin")
                    }
                    if !folders.names.isEmpty || memo.folder != nil {
                        Menu {
                            ForEach(folders.names, id: \.self) { name in
                                Button(name) { move(memo, to: name) }
                            }
                            if memo.folder != nil {
                                Button("폴더에서 빼기") { move(memo, to: nil) }
                            }
                        } label: {
                            Label("폴더에 넣기", systemImage: "folder")
                        }
                    }
                    Button(role: .destructive) { delete(memo) } label: {
                        Label("지우기", systemImage: "trash")
                    }
                } preview: {
                    // 뒤집힌 줄의 스냅샷이 아니라 바로 선 종이를 보인다.
                    MemoRowView(memo: memo)
                        .padding(.vertical, 12)
                        .frame(width: 340)
                        .background(Paper.surface)
                }
            }

            if session.usingCloud, !searching {
                // 무더기 머리 — 끝까지 올려야 보인다. 잘 될 때는 조용하다.
                Text("iCloud 의 LazyMemo 폴더를 맥과 함께 봅니다 · \(store.active.count)장")
                    .font(.caption)
                    .foregroundStyle(Paper.fadedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .flipped()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("cloud-head")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        // 뒤집힌 목록에 유리 바의 가장자리 번짐이 잘못 얹혀 줄 전체가 바래 보인다.
        .scrollEdgeEffectHidden(true, for: .all)
    }

    // MARK: 폴더 띠 — 폴더가 하나도 없으면 띠 자체가 없다

    @ViewBuilder
    private var folderBand: some View {
        let names = folders.names
        if !names.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    folderChip("전부", selected: folders.selected == nil) { folders.selected = nil }
                    ForEach(names, id: \.self) { name in
                        folderChip(name, selected: folders.selected == name) {
                            folders.selected = folders.selected == name ? nil : name
                        }
                        .contextMenu {
                            Button("이름 바꾸기") { renamedTo = name; renaming = name }
                            Button("폴더 지우기", role: .destructive) { Task { await folders.remove(name) } }
                        }
                    }
                    folderChip("＋", selected: false) { namingFolder = true }
                        .accessibilityLabel("새 폴더")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Paper.surface)
        }
    }

    private func folderChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.onAccent : Theme.accentInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: Theme.chipRadius)
                        .fill(selected ? Theme.accent : Theme.accentInk.opacity(0.09))
                )
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: 손짓

    /// 치워 둔 것이었으면 여는 순간 도로 나온다 (맥과 같다).
    private func open(_ memo: Memo) {
        if memo.tidied != nil { Task { await store.untidy(memo.id) } }
        opened = memo.id
    }

    private func delete(_ memo: Memo) {
        Task {
            try? await store.delete(memo.id)
            await pen.refresh()
            undo.offer("지웠습니다") {
                try? await store.restore(memo.id)
                await pen.refresh()
            }
        }
    }

    private func pin(_ memo: Memo) {
        Task { _ = try? await store.update(memo.id, pinned: !memo.pinned) }
    }

    private func move(_ memo: Memo, to folder: String?) {
        Task { _ = try? await store.update(memo.id, folder: .some(folder)) }
    }
}

private extension View {
    /// 뒤집힌 목록 안에서 줄을 도로 세운다.
    func flipped() -> some View { scaleEffect(x: 1, y: -1) }
}
