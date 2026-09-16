import LazyMemoCore
import LazyMemoPlaces
import LazyMemoReminders
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
    /// ✦ 「이 메모에게 시키기」— 이 메모를 「이거」로 펜에 넘긴다. 시키는 자리는 펜 하나다 (맥의 상자와 같다,
    /// quick-capture-assistant D1·D10): 여기 또 하나의 글 칸을 띄우면 같은 일을 하는 자리가 둘이 된다. 없으면 ✦ 도 없다.
    var onCommand: ((ULID) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var lastSaved = ""
    @State private var loaded = false
    /// 키보드가 올라와 있다. 그동안은 위에 「완료」 — 키보드가 바닥 꼬리를 덮으니
    /// 내려 보낼 길이 하나는 손에 잡혀야 한다 (Notes 와 같다).
    @State private var editing = false
    @State private var saveTask: Task<Void, Never>?
    @State private var datePicking = false
    @State private var recallPicking = false
    /// ✦ 를 눌렀다 — 화면이 다 물러난 뒤(`onDisappear`) 펜에 넘긴다. 물러나는 중에는 펜이 포커스를 받지 못한다.
    @State private var handingOff = false
    @Environment(\.assistant) private var assistant
    @State private var folderPicking = false
    @State private var newFolder = ""
    /// 자리 카드 — 지도와 가는 길. 자리가 없는 메모에는 없다.
    @State private var resolver = PlaceResolver()
    /// 사진 — 맥이 붙인 것을 본다. 사진이 없는 메모에는 없다.
    @State private var photos = PhotoLoader()

    private static let autosaveDelay: Duration = .milliseconds(600)

    private var memo: Memo? { store.memo(id) }
    private var folderNames: [String] { MemoFolders.names(listed: listedFolders, memos: store.memos) }
    private var places: [MemoPlaces.Place] { memo.map(MemoPlaces.of) ?? [] }
    private var imagePaths: [String] { memo.map { MarkdownScanner.imagePaths(in: $0.body) } ?? [] }
    /// 본문 끝의 「## 가는 길」— 비서가 적은 길 (`RouteNote`). 파일을 본다.
    private var route: TransitRoute? {
        guard let memo, let at = memo.at else { return nil }
        return RouteNote.read(memo.body, day: at)
    }

    var body: some View {
        Group {
            if memo != nil {
                PaperTextView(text: $text, editing: $editing)
            } else {
                // 지워졌거나 다른 기기에서 옮겨 갔다. 빈 종이를 보여 주지 않는다.
                ContentUnavailableView("이 메모는 이제 없습니다", systemImage: "doc")
            }
        }
        .background(Paper.surface)
        // 자리 카드는 종이 머리에 앉는다 — 지도가 먼저 보이고 글은 그 아래로 이어진다.
        // 키보드가 올라와 있는 동안은 접는다: 지도 밑에 글 칸이 세 줄 남으면 적을 수 없다.
        .safeAreaInset(edge: .top, spacing: 0) {
            if !editing {
                VStack(spacing: 0) {
                    if !places.isEmpty { PlaceCardsView(resolver: resolver) }
                    // 가는 길도 머리에 — 지도 아래, 글 위. 맥과 같은 카드다 (`RouteCard`).
                    if let route { routeCard(route) }
                    // 사진도 머리에 앉는다 — 폰의 종이는 화면 전체가 글 칸이라 아래가 없다.
                    if !imagePaths.isEmpty { PhotoCardsView(loader: photos) }
                }
            }
        }
        // 참조가 바뀔 때만 다시 읽는다. iCloud 에서 오는 중이면 이 task 가 기다린다.
        .task(id: imagePaths) {
            guard !imagePaths.isEmpty else { return }
            await photos.load(paths: imagePaths, store: store.attachments)
        }
        // 이름이 바뀔 때만 다시 짓는다. 좌표는 카드가 스스로 알아내 파일에 적는 것이라
        // 그것까지 열쇠에 넣으면 적는 순간 자기 자신을 다시 시작한다.
        .task(id: places.map(\.name)) {
            guard !places.isEmpty else { return }
            await resolver.load(places: places) { geo in
                // 첫 자리의 좌표를 파일에 적어 둔다 — 다음엔 묻지 않고, 맥도 같은 점을 본다.
                Task { _ = try? await store.update(id, geo: .some(geo)) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { if let memo { tail(memo) } }
        .toolbar {
            if assistant != nil, let onCommand {
                ToolbarItem(placement: .topBarTrailing) {
                    // 화면이 물러나고 펜이 올라온다 — 적던 글도 `onDisappear` 가 내린다.
                    Button { handingOff = true; dismiss() } label: { Label("이 메모에게 시키기", systemImage: "sparkles") }
                        .accessibilityIdentifier("assistant-command-button")
                }
            }
            // 다시 보기 — 일정은 두고 이 메모를 다시 펼칠 시각. 정해 두었으면 종이 있는 종.
            ToolbarItem(placement: .topBarTrailing) {
                Button { recallPicking = true } label: {
                    Label("다시 보기", systemImage: memo?.surface == nil ? "bell" : "bell.badge.fill")
                }
                .accessibilityLabel(memo?.surface.map { String(localized: "다시 보기 \($0.formatted(date: .abbreviated, time: .shortened))") } ?? String(localized: "다시 보기"))
                .accessibilityIdentifier("recall-button")
            }
            if editing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { editing = false }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("done-editing")
                }
            }
        }
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
        .onDisappear {
            flush()
            if handingOff { handingOff = false; onCommand?(id) }
        }
        // 뒤로 물러날 때도 즉시 — 600ms 안에 앱이 죽으면 마지막 글자가 사라진다.
        .onChange(of: scenePhase) { _, phase in if phase == .background { flush() } }
        .sheet(isPresented: $datePicking) {
            if let memo {
                DateSheet(
                    schedule: Schedule(memo),
                    onChange: { schedule in
                        Task { _ = try? await store.update(id, due: .some(schedule.due), at: .some(schedule.at)) }
                    },
                    // 시트가 열린 뒤 바뀐 자리를 되돌리려면 그때의 메모를 봐야 한다.
                    onClear: { if let live = store.memo(id) { clearDate(live) } }
                )
            }
        }
        .sheet(isPresented: $recallPicking) { RecallEditor(store: store, id: id) }
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

    // MARK: 가는 길 카드

    private func routeCard(_ route: TransitRoute) -> some View {
        RouteCard(
            route: route,
            style: RouteCardStyle(
                ink: Paper.ink, faded: Color.secondary, accent: Theme.accentInk, softAccent: Theme.accentInk.opacity(0.08),
                surface: Paper.card, edge: Paper.ink.opacity(0.08), radius: Theme.controlRadius
            ),
            open: { route in openRoute(route) },
            remove: { removeRoute(route) }
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// 깔린 지도 앱으로 — 네이버 → 카카오 → 웹의 카카오맵. 애플 지도는 한국의 대중교통을 모른다.
    private func openRoute(_ route: TransitRoute) {
        let app = UIApplication.shared
        let appName = Bundle.main.bundleIdentifier ?? "lazymemo"
        if let geo = memo?.geo {
            if let probe = URL(string: "nmap://open"), app.canOpenURL(probe),
               let url = RouteLinks.naverApp(route, destination: geo, appName: appName) { app.open(url); return }
            if let probe = URL(string: "kakaomap://open"), app.canOpenURL(probe),
               let url = RouteLinks.kakaoApp(route, destination: geo) { app.open(url); return }
        }
        if let url = RouteLinks.kakaoWeb(route) { app.open(url) }
    }

    /// 절을 떼고, 그 길의 출발 알림이었던 다시 보기도 함께.
    private func removeRoute(_ route: TransitRoute) {
        guard let memo else { return }
        let alarm = route.depart.addingTimeInterval(-RoutePlanner.lead)
        let surface: Date?? = memo.surface == alarm ? .some(nil) : nil
        let body = RouteNote.remove(from: memo.body)
        flush()
        Task {
            guard let updated = try? await store.update(id, body: body, surface: surface) else { return }
            text = updated.body
            lastSaved = updated.body
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
            .accessibilityLabel(memo.due != nil || memo.at != nil
                ? String(localized: "날짜 \(MemoTimeLabel.text(for: memo))") : String(localized: "달력에 놓기"))
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
            .accessibilityLabel(memo.folder.map { String(localized: "폴더 \($0)") } ?? String(localized: "폴더에 넣기"))
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
                Label(memo.pinned ? String(localized: "고정 해제") : String(localized: "고정"), systemImage: memo.pinned ? "pin.fill" : "pin")
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
            Undo.register(String(localized: "날짜 떼기"), on: undoManager, reveal: reveal, id: id) {
                _ = try? await store.update(id, due: .some(memo.due), at: .some(memo.at))
            }
        }
    }

    private func delete(_ memo: Memo) {
        // 적던 글을 먼저 **기다려서** 내린다 — 따로 던지면 지운 뒤에 도착해
        // 휴지통의 글과 되돌린 글이 어긋난다.
        saveTask?.cancel()
        Task {
            await save()
            try? await store.delete(id)
            dismiss()
            Undo.register(String(localized: "지우기"), on: undoManager, reveal: reveal, id: id) { try? await store.restore(id) }
        }
    }
}
