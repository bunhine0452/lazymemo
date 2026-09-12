import LazyMemoCore
import SwiftUI

/// 편집 — 화면 전체가 종이 + 꼬리 한 줄 (MOBILE_DESIGN §5).
///
/// 저장 버튼은 없다. 글자가 바뀌면 600ms 뒤에 파일로 가고, 뒤로 갈 때는 즉시.
/// 맥에서 같은 파일을 고치면 화면이 따라온다 — 조합 중이 아니고, 내가 고치던
/// 중이 아닐 때만 (`PaperTextView`).
struct MemoEditorView: View {
    let store: MemoStore
    let id: ULID
    let undo: UndoModel

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var lastSaved = ""
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var datePicking = false
    @State private var folderPicking = false
    @State private var colorPicking = false
    @State private var newFolder = ""

    private static let autosaveDelay: Duration = .milliseconds(600)

    private var memo: Memo? { store.memo(id) }

    var body: some View {
        Group {
            if let memo {
                PaperTextView(text: $text)
                    .safeAreaInset(edge: .bottom, spacing: 0) { tail(memo) }
            } else {
                // 지워졌거나 다른 기기에서 옮겨 갔다. 빈 종이를 보여 주지 않는다.
                ContentUnavailableView("이 메모는 이제 없습니다", systemImage: "doc")
            }
        }
        .background(Paper.surface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
        .alert("폴더", isPresented: $folderPicking) {
            TextField("새 폴더 이름", text: $newFolder)
            Button("넣기") {
                let name = MemoFolders.normalized(newFolder)
                newFolder = ""
                Task { _ = try? await store.update(id, folder: .some(name)) }
            }
            if memo?.folder != nil {
                Button("폴더에서 빼기", role: .destructive) {
                    Task { _ = try? await store.update(id, folder: .some(nil)) }
                }
            }
            Button("그만두기", role: .cancel) { newFolder = "" }
        }
    }

    // MARK: 꼬리 — 날짜 · 장소 · 폴더 · 색 · 고정 | 지우기

    private func tail(_ memo: Memo) -> some View {
        HStack(spacing: 4) {
            Button { datePicking = true } label: {
                if memo.due != nil || memo.at != nil {
                    Text(MemoTimeLabel.text(for: memo))
                        .font(.footnote.monospacedDigit().weight(.medium))
                        .foregroundStyle(Theme.highlightInk)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 32)
                        .background(Theme.highlightWash, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
                } else {
                    Image(systemName: "calendar")
                        .foregroundStyle(Theme.accentInk.opacity(0.4))
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(memo.due != nil || memo.at != nil ? "날짜 \(MemoTimeLabel.text(for: memo))" : "달력에 놓기")
            .accessibilityIdentifier("tail-date")

            if let place = memo.place {
                Menu {
                    if let url = MapLink.url(for: memo) {
                        Link("지도 열기", destination: url)
                    }
                    Button("장소 떼기", role: .destructive) {
                        Task { _ = try? await store.update(id, place: .some(nil), geo: .some(nil)) }
                    }
                } label: {
                    Text("@" + place)
                        .font(.footnote)
                        .foregroundStyle(Paper.fadedInk)
                        .lineLimit(1)
                        .frame(minHeight: 44)
                }
            }

            Button { folderPicking = true } label: {
                if let folder = memo.folder {
                    Text(folder).font(.footnote).foregroundStyle(Paper.fadedInk).lineLimit(1)
                } else {
                    Image(systemName: "folder").foregroundStyle(Theme.accentInk.opacity(0.4))
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(memo.folder.map { "폴더 \($0)" } ?? "폴더에 넣기")

            colorDots(memo)

            Button {
                Task { _ = try? await store.update(id, pinned: !memo.pinned) }
            } label: {
                Image(systemName: memo.pinned ? "pin.fill" : "pin")
                    .foregroundStyle(memo.pinned ? Theme.accentInk : Theme.accentInk.opacity(0.4))
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel(memo.pinned ? "고정 해제" : "고정")

            Spacer(minLength: 0)

            Button { delete(memo) } label: {
                Image(systemName: "trash").foregroundStyle(Theme.danger.opacity(0.8))
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel("지우기")
            .accessibilityIdentifier("tail-delete")
        }
        .padding(.horizontal, 12)
        .background(Paper.surface)
        .overlay(alignment: .top) { Rectangle().fill(Paper.ink.opacity(0.12)).frame(height: 0.5) }
    }

    /// 색 — 점 하나. 누르면 그 자리에서 여섯 점이 펼쳐진다.
    private func colorDots(_ memo: Memo) -> some View {
        HStack(spacing: 2) {
            ForEach(colorPicking ? MemoColor.allCases : [memo.color], id: \.self) { color in
                Button {
                    if colorPicking {
                        Task { _ = try? await store.update(id, color: color) }
                    }
                    colorPicking.toggle()
                } label: {
                    Circle()
                        .fill(color.ink)
                        .frame(width: color == memo.color ? 14 : 11, height: color == memo.color ? 14 : 11)
                        .overlay(Circle().stroke(Paper.ink.opacity(color == memo.color ? 0.35 : 0), lineWidth: 1))
                        .frame(width: colorPicking ? 30 : 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(colorPicking ? color.label : "색 \(memo.color.label)")
            }
        }
        .animation(.snappy(duration: 0.15), value: colorPicking)
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

    private func clearDate(_ memo: Memo) {
        Task {
            _ = try? await store.update(id, due: .some(nil), at: .some(nil))
            undo.offer("날짜를 뗐습니다") {
                _ = try? await store.update(id, due: .some(memo.due), at: .some(memo.at))
            }
        }
    }

    private func delete(_ memo: Memo) {
        flush()
        Task {
            try? await store.delete(id)
            dismiss()
            undo.offer("지웠습니다") { try? await store.restore(id) }
        }
    }
}
