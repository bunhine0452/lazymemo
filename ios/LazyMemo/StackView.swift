import LazyMemoCore
import SwiftUI

/// 목록 — 위에서 아래로, 고정 → 최근순 (MOBILE_DESIGN §4). 큰 제목 「메모」,
/// 부제는 저장 자리. 새로 적은 줄은 맨 위에 생기고 화면이 그리로 가며 잠깐 밝아진다.
struct StackView: View {
    let session: AppModel.Session
    let pen: PenModel
    let folders: FolderModel
    let reveal: Reveal

    @Environment(\.undoManager) private var undoManager
    @Environment(\.openURL) private var openURL
    @State private var opened: ULID?
    @State private var dating: ULID?
    @State private var showsTrash = false
    @State private var namingFolder = false
    @State private var newFolderName = ""
    @State private var renaming: String?
    @State private var renamedTo = ""
    @State private var removing: String?
    @State private var showsTutorial = false

    private var store: MemoStore { session.store }

    private var listed: [Memo] {
        MemoFolders.filter(pen.found ?? store.active, folder: folders.selected)
    }

    private var searching: Bool { pen.found != nil }

    private var subtitle: String {
        session.usingCloud ? "iCloud · \(store.active.count)장" : "이 기기에만 · iCloud 꺼짐"
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                // 폴더 띠는 목록의 머리다 — 큰 제목 밑에서 내용과 함께 스크롤된다.
                // 안전 영역 인셋으로 두면 큰 제목이 그려지지 않는다.
                folderBand
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if searching {
                    // 찾기의 범위를 적는다 — "Clearly display the current scope of a search".
                    // 폴더를 골라 두었으면 그 폴더 안에서 센다. 하나도 없을 때는 이 한 줄이
                    // 전부다 — 적는 중에 「없어요」라는 큰 제목이 서면 새 메모를 쓰는 사람이
                    // 무언가 틀린 것처럼 읽는다. 펜은 적기가 먼저고 찾기는 곁이다.
                    let scope = MemoFolders.filter(store.active, folder: folders.selected).count
                    Text(listed.isEmpty
                         ? "\(scope)장 중 겹치는 것 없음 · 남기면 새 메모예요"
                         : "\(scope)장 중 \(listed.count)장")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier(listed.isEmpty ? "search-empty" : "scope")
                }

                ForEach(listed) { memo in
                    Button { open(memo) } label: {
                        MemoRowView(memo: memo)
                    }
                    .buttonStyle(.plain)
                    .id(memo.id)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(reveal.target == memo.id ? Color.accentColor.opacity(0.14) : .clear)
                            .padding(.horizontal, 8)
                            .animation(.easeOut(duration: 0.6), value: reveal.target)
                    )
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
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
                                ForEach(folders.names, id: \.self) { name in Button(name) { move(memo, to: name) } }
                                if memo.folder != nil { Button("폴더에서 빼기") { move(memo, to: nil) } }
                            } label: { Label("폴더에 넣기", systemImage: "folder") }
                        }
                        Button { dating = memo.id } label: { Label("달력에 놓기", systemImage: "calendar") }
                        Divider()
                        Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
                    } preview: {
                        MemoRowView(memo: memo).padding(16).frame(width: 340).background(Paper.surface)
                    }
                    .accessibilityActions {
                        Button(memo.pinned ? "고정 해제" : "고정") { pin(memo) }
                        Button("달력에 놓기") { dating = memo.id }
                        Button("지우기") { delete(memo) }
                    }
                }

                if listed.isEmpty, !searching {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Theme.accentInk)
                            .frame(width: 64, height: 64)
                            .background(Theme.accentInk.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        Text(folders.selected == nil ? "가볍게, 한 줄부터" : "아직 비어 있는 폴더예요")
                            .font(.headline).foregroundStyle(Paper.ink)
                        Text("아래에 적으면 이곳에 차곡차곡 쌓여요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .accessibilityIdentifier("stack-empty")
                }

            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Paper.surface)
            // 목록이 짧아 스크롤이 안 될 때도 쓸어 내리면 키보드가 내려가야 한다 —
            // 켜면 키보드가 올라와 탭바를 덮으므로, 이것이 탭바로 가는 길이다.
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: reveal.target) { _, target in
                guard let target else { return }
                withAnimation(.snappy) { proxy.scrollTo(target, anchor: .top) }
            }
        }
        .navigationTitle("메모")
        .navigationSubtitle(subtitle)
        .toolbarTitleDisplayMode(.large)
        .toolbar { toolbar }
        .navigationDestination(item: $opened) { id in
            MemoEditorView(store: store, id: id, reveal: reveal, listedFolders: folders.names)
        }
        .navigationDestination(isPresented: $showsTrash) { TrashView(store: store, reveal: reveal) }
        // 시트는 메모를 **살아 있는 채로** 본다 — 값을 잡아 두면 첫 누름 뒤 격자의
        // 밑줄과 시각 칩이 따라오지 않는다.
        .sheet(isPresented: Binding(get: { dating != nil }, set: { if !$0 { dating = nil } })) {
            if let id = dating, let memo = store.memo(id) {
                DateSheet(schedule: Schedule(memo), onChange: { schedule in
                    Task { _ = try? await store.update(id, due: .some(schedule.due), at: .some(schedule.at)) }
                }, onClear: {
                    Task { _ = try? await store.update(id, due: .some(nil), at: .some(nil)) }
                })
            }
        }
        .sheet(isPresented: $showsTutorial) { TutorialView() }
        // 폴더를 지우는 것은 되돌릴 수 없다 (이름표가 떨어진다) — 한 번 묻는다.
        .confirmationDialog(
            "「\(removing ?? "")」 폴더를 지울까요?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible, presenting: removing
        ) { name in
            Button("폴더 지우기", role: .destructive) { Task { await folders.remove(name) } }
            Button("그만두기", role: .cancel) {}
        } message: { _ in
            Text("메모는 그대로 남고, 폴더 이름표만 떨어집니다.")
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

    // MARK: 툴바 — 휴지통은 늘, More 는 있을 때만

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showsTrash = true } label: { Label("휴지통", systemImage: "trash") }
                .accessibilityIdentifier("trash-button")
        }
        // More 에는 「새 폴더」가 늘 있으므로 늘 보인다. 나머지 둘은 있을 때만.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if !store.tidiedMemos.isEmpty {
                    Button { Task { await store.untidyAll() } } label: {
                        Label("치워 둔 \(store.tidiedMemos.count)장 도로 꺼내기", systemImage: "tray.and.arrow.up")
                    }
                }
                if !session.usingCloud, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Button { openURL(settings) } label: { Label("iCloud 설정 열기", systemImage: "icloud") }
                }
                Button { namingFolder = true } label: { Label("새 폴더", systemImage: "folder.badge.plus") }
                Divider()
                Button { showsTutorial = true } label: { Label("사용법", systemImage: "questionmark.circle") }
                    .accessibilityIdentifier("tutorial-button")
            } label: {
                Label("더 보기", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("more")
        }
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
                            Button("폴더 지우기", role: .destructive) { removing = name }
                        }
                    }
                    Button { namingFolder = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule)
                        .accessibilityLabel("새 폴더")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    private func folderChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "folder.fill" : "folder")
                Text(label)
            }
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(selected ? Theme.onAccent : Theme.accentInk)
            .background(selected ? Theme.accent : Theme.accentInk.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            Undo.register("지우기", on: undoManager, reveal: reveal, id: memo.id) {
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
