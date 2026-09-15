import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoReminders
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
    @State private var showsReminders = false
    @State private var reminders = ReminderCenter.shared
    /// 「지금」 띠의 시계. 분이 바뀌면 다시 재고, 자정을 넘기면 「오늘」이 바뀐다.
    @State private var clock = Date()
    /// 「봤어요」로 내려놓은 카드 — 이 기기의 기억 (`NowSeen`).
    @State private var seen: [ULID: Date] = NowSeen.load()

    private var store: MemoStore { session.store }

    private var searching: Bool { pen.results != nil }
    private var assistant: AssistantModel? { pen.assistant }

    /// 찾는 중이거나 폴더를 골랐으면 없다 — 범위 밖의 카드가 범위를 흐린다.
    private var nowCards: [Recall.Card] {
        guard !searching, folders.selected == nil else { return [] }
        return Recall.nowCards(store.memos, now: clock, seen: seen)
    }

    /// 「지금」에 오른 것은 목록에서 뺀다 — 같은 줄이 두 번 서면 화면이 무겁다.
    private var listed: [Memo] {
        // 비서가 목록을 정했으면(근거·관련·후보) 폴더로 거르지 않는다 — 그 목록은 답의 일부다.
        let all = pen.shown ?? MemoFolders.filter(pen.found ?? store.active, folder: folders.selected)
        let risen = Set(nowCards.map(\.id))
        return risen.isEmpty ? all : all.filter { !risen.contains($0.id) }
    }

    private var subtitle: String {
        session.usingCloud ? String(localized: "iCloud · \(store.active.count)장") : String(localized: "이 기기에만 · iCloud 꺼짐")
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

                if !nowCards.isEmpty {
                    NowBand(cards: nowCards, now: clock, open: open, putDown: putDown, pin: pin, delete: delete)
                }

                // 조용히 지나가면 안 되는 실패 — 저장이 안 되고 있으면 여기 선다.
                if let trouble = store.trouble {
                    NoticeRow(title: trouble.doing, detail: trouble.detail)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                if reminders.enabled, let trouble = reminders.trouble {
                    NoticeRow(title: trouble) { reminders.refresh() }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // 비서의 답·결과 — 목록 위에 선다. 목록은 그 답의 근거·후보로 갈려 있다 (`PenModel.reflectAssistant`).
                if let assistant, pen.pendingQuestion == nil { assistantBlock(assistant) }

                if let heading = listingHeading {
                    Text(heading)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier("listing")
                } else if searching {
                    // 찾기의 범위를 적는다 — "Clearly display the current scope of a search".
                    // 폴더를 골라 두었으면 그 폴더 안에서 센다. 하나도 없을 때는 이 한 줄이
                    // 전부다 — 적는 중에 「없어요」라는 큰 제목이 서면 새 메모를 쓰는 사람이
                    // 무언가 틀린 것처럼 읽는다. 펜은 적기가 먼저고 찾기는 곁이다.
                    let scope = MemoFolders.filter(store.active, folder: folders.selected).count
                    Text(listed.isEmpty
                         ? String(localized: "\(scope)장 중 겹치는 것 없음 · 남기면 새 메모예요")
                         : String(localized: "\(scope)장 중 \(listed.count)장"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier(listed.isEmpty ? "search-empty" : "scope")
                }

                // 띠가 서 있으면 아래는 「나머지」다 — 머리와 몸이 다른 것임을 한 줄이 적는다.
                if !nowCards.isEmpty, !listed.isEmpty {
                    Text("나머지 \(listed.count)장")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("rest")
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                ForEach(listed) { memo in
                    // 후보 목록의 줄은 여는 것이 아니라 고르는 것 — 그 메모에게 같은 말을 한다 (D10).
                    Button { if pen.listing == .candidates, pen.shown != nil { pen.pick(memo.id) } else { open(memo) } } label: {
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
                            Label(memo.pinned ? String(localized: "고정 해제") : String(localized: "고정"), systemImage: memo.pinned ? "pin.slash" : "pin")
                        }
                        .tint(Theme.accent)
                    }
                    .contextMenu {
                        Button { pin(memo) } label: {
                            Label(memo.pinned ? String(localized: "고정 해제") : String(localized: "고정"), systemImage: memo.pinned ? "pin.slash" : "pin")
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
                        Button(memo.pinned ? String(localized: "고정 해제") : String(localized: "고정")) { pin(memo) }
                        Button("달력에 놓기") { dating = memo.id }
                        Button("지우기") { delete(memo) }
                    }
                }

                if listed.isEmpty, !searching, nowCards.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Theme.accentInk)
                            .frame(width: 64, height: 64)
                            .background(Theme.accentInk.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        Text(folders.selected == nil ? String(localized: "가볍게, 한 줄부터") : String(localized: "아직 비어 있는 폴더예요"))
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
        .sheet(isPresented: $showsReminders) {
            NavigationStack {
                ScrollView { ReminderSettingsView().padding(20) }
                    .background(Paper.surface)
                    .navigationTitle("알림")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("닫기") { showsReminders = false } }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        // 분이 바뀔 때마다 「지금」을 다시 잰다. 앞으로 올 때·시계가 크게 뛸 때도.
        .task {
            while !Task.isCancelled {
                let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(60)
                try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
                clock = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in clock = Date() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in clock = Date() }
        // 폴더를 지우는 것은 되돌릴 수 없다 (이름표가 떨어진다) — 한 번 묻는다.
        .confirmationDialog(
            String(localized: "「\(removing ?? "")」 폴더를 지울까요?"),
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
                Button { showsReminders = true } label: { Label("알림", systemImage: "bell") }
                    .accessibilityIdentifier("reminders-button")
                Button { showsTutorial = true } label: { Label("사용법", systemImage: "questionmark.circle") }
                    .accessibilityIdentifier("tutorial-button")
            } label: {
                Label("더 보기", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("more")
        }
    }

    // MARK: 비서 — 답·결과·되물음이 목록 위에 선다 (quick-capture-assistant D8·D9·D10·D11)

    /// 비서가 정한 목록의 이름. 검색이면 nil — 그때는 범위 줄이 선다.
    private var listingHeading: String? {
        guard pen.shown != nil else { return nil }
        switch pen.listing {
        case .search: return nil
        case .evidence: return String(localized: "근거 \(listed.count)장")
        case .related: return String(localized: "관련 메모")
        case .candidates: return String(localized: "어느 메모? 누르면 그 메모에게 합니다")
        }
    }

    @ViewBuilder
    private func assistantBlock(_ assistant: AssistantModel) -> some View {
        switch assistant.phase {
        case .idle, .thinking:
            EmptyView()
        case .failed(let message):
            if !assistant.isReady { modelRow(assistant) } else { noticeRow(message, symbol: "exclamationmark.circle") }
        case .done:
            if let answer = assistant.answer { answerRow(answer) }
            if let proposal = assistant.proposal {
                if proposal.kind == .ask { noticeRow(ActionWords.describe(proposal, memoTitle: nil), symbol: "questionmark.circle") }
                else if proposal.kind == .trash { trashRow(proposal, assistant) }
            }
            if let applied = assistant.applied { resultRow(applied, assistant) }
            if let error = assistant.applyError { noticeRow(error, symbol: "exclamationmark.circle") }
        }
    }

    private func answerRow(_ answer: AssistantAnswer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(answer.found ? ActionWords.soft(answer.text) : String(localized: "메모에서 찾지 못했습니다"))
                .font(.body)
                .textSelection(.enabled)
            ForEach(answer.quotes, id: \.self) { line in
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) { Rectangle().frame(width: 2).foregroundStyle(.tertiary) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentInk.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityIdentifier("answer")
    }

    /// 「「치과 예약」을 9월 18일 (금) 10:00 에 다시 보여 줍니다 · 되돌리기」— 확인 대신 되돌리기 (D8).
    private func resultRow(_ applied: ProposedAction, _ assistant: AssistantModel) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(ActionWords.describe(applied, memoTitle: applied.memoID.flatMap { store.memo($0)?.title }))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("되돌리기") { Task { await assistant.undo(); await pen.refresh() } }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accentInk)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityIdentifier("applied")
    }

    /// 휴지통만 되묻는다 (D8).
    private func trashRow(_ proposal: ProposedAction, _ assistant: AssistantModel) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(ActionWords.describe(proposal, memoTitle: proposal.memoID.flatMap { store.memo($0)?.title }))
                .font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("휴지통으로", role: .destructive) { Task { await assistant.apply(confirmedTrash: true); await pen.refresh() } }
                .font(.footnote.weight(.semibold)).buttonStyle(.plain)
            Button("아니요") { assistant.dismissProposal() }
                .font(.footnote.weight(.semibold)).buttonStyle(.plain).foregroundStyle(Theme.accentInk)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// 「모델을 받으면 답합니다 · 받기 2.6GB」— 묻기만 막힌다. 받는 동안은 진행 막대 (D11).
    private func modelRow(_ assistant: AssistantModel) -> some View {
        HStack(spacing: 10) {
            if let download = assistant.download {
                ProgressView(value: download.fraction).controlSize(.small)
                Text(download.verifying ? String(localized: "확인 중") : String(localized: "받는 중 \(Int(download.fraction * 100))%"))
                    .font(.footnote).foregroundStyle(.secondary)
                Button("취소") { assistant.cancelDownload() }.font(.footnote.weight(.semibold)).buttonStyle(.plain).foregroundStyle(Theme.accentInk)
            } else {
                Text("모델을 받으면 답합니다").font(.footnote).foregroundStyle(.secondary)
                if let error = assistant.downloadError { Text(error).font(.footnote).foregroundStyle(.red).lineLimit(1) }
                Spacer(minLength: 8)
                Button(String(localized: "받기 \(ByteCountFormatter.string(fromByteCount: assistant.manifest.file.bytes, countStyle: .file))")) { assistant.startDownload() }
                    .font(.footnote.weight(.semibold)).buttonStyle(.plain).foregroundStyle(Theme.accentInk)
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityIdentifier("model-row")
    }

    private func noticeRow(_ text: String, symbol: String) -> some View {
        Label(ActionWords.soft(text), systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    // MARK: 폴더 띠 — 폴더가 하나도 없으면 띠 자체가 없다

    @ViewBuilder
    private var folderBand: some View {
        let names = folders.names
        if !names.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    folderChip(String(localized: "전부"), selected: folders.selected == nil) { folders.selected = nil }
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
            Undo.register(String(localized: "지우기"), on: undoManager, reveal: reveal, id: memo.id) {
                try? await store.restore(memo.id)
                await pen.refresh()
            }
        }
    }

    private func pin(_ memo: Memo) {
        Task { _ = try? await store.update(memo.id, pinned: !memo.pinned) }
    }

    /// 「봤어요」 — 이 등장의 이름표를 적어 둔다. 시각을 미루거나 날이 바뀌면 다시 오른다.
    private func putDown(_ card: Recall.Card) {
        withAnimation(.snappy) { seen[card.id] = card.stamp }
        NowSeen.save(seen, now: clock)
    }

    private func move(_ memo: Memo, to folder: String?) {
        Task { _ = try? await store.update(memo.id, folder: .some(folder)) }
    }
}
