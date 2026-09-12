import LazyMemoCore
import SwiftUI

/// 탭 둘(메모·달력)과 그 위의 펜 (MOBILE_DESIGN §2).
///
/// 펜은 `safeAreaInset` 으로 두 탭의 바닥에 같은 것을 앉힌다 — 탭을 바꿔도
/// 펜은 남고, 키보드가 오르면 키보드 위에 붙는다. `tabViewBottomAccessory`
/// 는 탭바가 접힐 때 한 줄로 눌리고 키보드 위로 오르는지 확인할 수 없어
/// 쓰지 않았다.
struct HomeView: View {
    let session: AppModel.Session
    @State private var pen: PenModel
    @State private var undo = UndoModel()
    @State private var folders: FolderModel
    @State private var tab: Tab = .memos
    @State private var showsTrash = false

    enum Tab: Hashable { case memos, calendar }

    init(session: AppModel.Session) {
        self.session = session
        _pen = State(initialValue: PenModel(store: session.store, draft: session.draft))
        _folders = State(initialValue: FolderModel(store: session.store, settings: session.settings))
    }

    var body: some View {
        TabView(selection: $tab) {
            SwiftUI.Tab("메모", systemImage: "note.text", value: Tab.memos) {
                NavigationStack {
                    StackView(session: session, pen: pen, undo: undo, folders: folders)
                        .toolbar { menu }
                        .safeAreaInset(edge: .bottom, spacing: 0) { if tab == .memos { penBar } }
                        .navigationDestination(isPresented: $showsTrash) {
                            TrashView(store: session.store, undo: undo)
                        }
                }
            }
            SwiftUI.Tab("달력", systemImage: "calendar", value: Tab.calendar) {
                NavigationStack {
                    CalendarView(store: session.store, pen: pen, undo: undo)
                        .safeAreaInset(edge: .bottom, spacing: 0) { if tab == .calendar { penBar } }
                }
            }
        }
        .tint(Theme.accentInk)
        .onChange(of: tab) { _, tab in
            // 달력 탭에서는 고른 날이 펜에 미리 물린다. 메모 탭으로 오면 푼다.
            if tab == .memos { pen.presetDay = nil }
        }
    }

    /// 펜은 하나다 — 고른 탭에만 앉힌다. 두 탭에 다 두면 보이지 않는 쪽도 살아
    /// 있어 초점과 접근성이 둘로 갈린다.
    private var penBar: some View {
        PenBar(pen: pen, undo: undo, usingCloud: session.usingCloud)
    }

    /// ⋯ 메뉴 — 저장 자리 한 줄 · 휴지통 · 치워 둔 N장.
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section(session.usingCloud ? "iCloud · LazyMemo" : "⚠︎ 이 기기에만") {
                    Button {
                        showsTrash = true
                    } label: {
                        Label("휴지통 (\(session.store.trash.count))", systemImage: "trash")
                    }
                    if !session.store.tidiedMemos.isEmpty {
                        Button {
                            Task { await session.store.untidyAll() }
                        } label: {
                            Label("치워 둔 \(session.store.tidiedMemos.count)장 도로 꺼내기", systemImage: "tray.and.arrow.up")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityIdentifier("more")
        }
    }
}
