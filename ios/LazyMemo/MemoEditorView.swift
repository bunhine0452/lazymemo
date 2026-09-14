import LazyMemoCore
import SwiftUI

/// 편집 — 화면 전체가 종이, 꼬리는 표준 바닥 툴바 (MOBILE_DESIGN §5).
///
/// 저장 버튼은 없다. 글자가 바뀌면 600ms 뒤에 파일로 가고, 뒤로 갈 때는 즉시.
/// 맥에서 같은 파일을 고치면 화면이 따라온다 (`PaperTextView`). 키보드는
/// 열 때 올라오지 않는다 — Notes 도 그렇다.
struct MemoEditorView: View {
    let store: MemoStore
    let id: ULID
    let reveal: Reveal
    /// 설정에 적힌 폴더 차례 — 메모가 한 장도 없는 폴더도 고를 수 있게.
    var listedFolders: [String] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var lastSaved = ""
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var datePicking = false
    @State private var folderPicking = false
    @State private var newFolder = ""

    private static let autosaveDelay: Duration = .milliseconds(600)

    private var memo: Memo? { store.memo(id) }
    private var folderNames: [String] { MemoFolders.names(listed: listedFolders, memos: store.memos) }

    var body: some View {
        Group {
            if memo != nil {
                PaperTextView(text: $text)
            } else {
                // 지워졌거나 다른 기기에서 옮겨 갔다. 빈 종이를 보여 주지 않는다.
                ContentUnavailableView("이 메모는 이제 없습니다", systemImage: "doc")
            }
        }
        .background(Paper.surface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { if let memo { tail(memo) } }
        .onAppear {
            guard !loaded, let memo else { return }
            text = memo.body
            lastSaved = memo.body
            loaded = true
        }
        .onChange(of: text) { _, now in
            guard loaded, now != lastSaved else { return }
            scheduleSave()
        }
        .onChange(of: memo?.body) { _, external in
            // 바깥에서 왔고, 내가 고치던 중이 아니면 따라간다.
            guard let external, external != lastSaved, text == lastSaved else { return }
            text = external
            lastSaved = external
        }
        .onDisappear { flush() }
        // 뒤로 물러날 때도 즉시 — 600ms 안에 앱이 죽으면 마지막 글자가 사라진다.
        .onChange(of: scenePhase) { _, phase in if phase == .background { flush() } }
        .sheet(isPresented: $datePicking) {
            if let memo {
                DateSheet(
                    schedule: Schedule(memo),
                    onChange: { schedule in
                        Task { _ = try? await store.update(id, due: .some(schedule.due), at: .some(schedule.at)) }
                    },
                    onClear: { clearDate(memo) }
                )
            }
        }
        .alert("새 폴더", isPresented: $folderPicking) {
            TextField("이름", text: $newFolder)
            Button("만들고 넣기") {
                // 빈 이름은 아무것도 하지 않는다 — 전에는 있던 폴더에서 빠졌다.
                let name = MemoFolders.normalized(newFolder)
                newFolder = ""
                guard let name else { return }
                move(to: name)
            }
            Button("그만두기", role: .cancel) { newFolder = "" }
        }
    }

    // MARK: 꼬리 — 무엇(날짜·장소·폴더) | 생김새(색·고정) | 끝(지우기)

    @ToolbarContentBuilder
    private func tail(_ memo: Memo) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button { datePicking = true } label: {
                if memo.due != nil || memo.at != nil {
                    Text(MemoTimeLabel.text(for: memo))
                        .font(.footnote.monospacedDigit().weight(.medium))
                        .foregroundStyle(Theme.highlightInk)
                } else {
                    Label("달력에 놓기", systemImage: "calendar")
                }
            }
            .accessibilityLabel(memo.due != nil || memo.at != nil ? "날짜 \(MemoTimeLabel.text(for: memo))" : "달력에 놓기")
            .accessibilityIdentifier("tail-date")

            if let place = memo.place {
                Menu {
                    if let url = MapLink.url(for: memo) { Link("지도 열기", destination: url) }
                    Button("장소 떼기", role: .destructive) {
                        Task { _ = try? await store.update(id, place: .some(nil), geo: .some(nil)) }
                    }
                } label: {
                    Text("@" + place).font(.footnote).lineLimit(1)
                }
            }

            // 있는 폴더는 고르고, 없는 폴더만 이름을 적는다.
            Menu {
                ForEach(folderNames, id: \.self) { name in
                    Button { move(to: name) } label: {
                        Label(name, systemImage: memo.folder == name ? "checkmark" : "folder")
                    }
                }
                Button { folderPicking = true } label: { Label("새 폴더…", systemImage: "folder.badge.plus") }
                if memo.folder != nil {
                    Divider()
                    Button("폴더에서 빼기", role: .destructive) { move(to: nil) }
                }
            } label: {
                if let folder = memo.folder {
                    Text(folder).font(.footnote).lineLimit(1)
                } else {
                    Label("폴더에 넣기", systemImage: "folder")
                }
            }
            .accessibilityLabel(memo.folder.map { "폴더 \($0)" } ?? "폴더에 넣기")
            .accessibilityIdentifier("tail-folder")
        }
        ToolbarSpacer(.fixed, placement: .bottomBar)
        ToolbarItemGroup(placement: .bottomBar) {
            Menu {
                Picker("색", selection: Binding(
                    get: { memo.color },
                    set: { color in Task { _ = try? await store.update(id, color: color) } }
                )) {
                    ForEach(MemoColor.allCases, id: \.self) { color in
                        Text(color.label).tag(color)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Circle().fill(memo.color.ink).frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            }
            .accessibilityLabel("색 \(memo.color.label)")

            Button {
                Task { _ = try? await store.update(id, pinned: !memo.pinned) }
            } label: {
                Label(memo.pinned ? "고정 해제" : "고정", systemImage: memo.pinned ? "pin.fill" : "pin")
            }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button(role: .destructive) { delete(memo) } label: { Label("지우기", systemImage: "trash") }
                .accessibilityIdentifier("tail-delete")
        }
    }

    // MARK: 저장 — 손이 멈춘 뒤에, 뒤로 갈 때는 즉시

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    private func save() async {
        let body = text
        guard body != lastSaved else { return }
        guard (try? await store.update(id, body: body)) != nil else { return }
        lastSaved = body
    }

    private func flush() {
        saveTask?.cancel()
        let body = text
        guard loaded, body != lastSaved else { return }
        lastSaved = body
        Task { _ = try? await store.update(id, body: body) }
    }

    private func move(to folder: String?) {
        Task { _ = try? await store.update(id, folder: .some(folder)) }
    }

    private func clearDate(_ memo: Memo) {
        Task {
            _ = try? await store.update(id, due: .some(nil), at: .some(nil))
            Undo.register("날짜 떼기", on: undoManager, reveal: reveal, id: id) {
                _ = try? await store.update(id, due: .some(memo.due), at: .some(memo.at))
            }
        }
    }

    private func delete(_ memo: Memo) {
        flush()
        Task {
            try? await store.delete(id)
            dismiss()
            Undo.register("지우기", on: undoManager, reveal: reveal, id: id) { try? await store.restore(id) }
        }
    }
}
