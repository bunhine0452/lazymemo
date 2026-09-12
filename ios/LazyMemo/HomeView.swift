import LazyMemoCore
import SwiftUI

/// 탭 둘(메모·달력)과 그 위의 펜 (MOBILE_DESIGN §2).
///
/// 펜은 설계상 탭바 액세서리였는데(MOBILE_DESIGN §2), 시뮬레이터에서 확인하니
/// **액세서리는 키보드 위로 오르지 않는다** — 키보드가 탭바와 함께 펜을 덮었다.
/// 그래서 설계가 적어 둔 대로 물러난다: `safeAreaInset(edge: .bottom)` 에 같은
/// 유리 펜. 생김새·동작은 같고 접힘만 없다. 고른 탭에만 앉힌다 — 두 탭에 다
/// 두면 보이지 않는 쪽도 살아 있어 접근성 요소가 둘이 된다.
/// 편집에서는 탭바와 펜이 숨는다: 종이 아래 또 하나의 글 칸이 보이면 「어디에
/// 적는 건가」가 흐려진다.
struct HomeView: View {
    let session: AppModel.Session
    @State private var pen: PenModel
    @State private var folders: FolderModel
    @State private var reveal = Reveal()
    @State private var here = HereFix()
    @State private var tab: Tab = .memos

    enum Tab: Hashable { case memos, calendar }

    init(session: AppModel.Session) {
        self.session = session
        _pen = State(initialValue: PenModel(store: session.store, draft: session.draft))
        _folders = State(initialValue: FolderModel(store: session.store, settings: session.settings))
    }

    private var penBar: some View {
        PenBar(pen: pen, fixing: here.fixing, hereTrouble: here.trouble) {
            Task { if let fix = await here.fix() { pen.here = fix } }
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            SwiftUI.Tab("메모", systemImage: "note.text", value: Tab.memos) {
                NavigationStack {
                    StackView(session: session, pen: pen, folders: folders, reveal: reveal)
                        .safeAreaInset(edge: .bottom, spacing: 0) { if tab == .memos { penBar } }
                }
            }
            SwiftUI.Tab("달력", systemImage: "calendar", value: Tab.calendar) {
                NavigationStack {
                    CalendarView(store: session.store, pen: pen, reveal: reveal)
                        .safeAreaInset(edge: .bottom, spacing: 0) { if tab == .calendar { penBar } }
                }
            }
        }
        .tint(Theme.accentInk)
        .onChange(of: tab) { _, tab in
            // 달력 탭에서는 고른 날이 펜에 미리 물린다. 메모 탭으로 오면 푼다.
            if tab == .memos { pen.presetDay = nil }
        }
        .onChange(of: pen.lastLeft) { _, left in
            // 새 줄이 맨 위에 생기고 화면이 그리로 간다.
            if let left { reveal.show(left) }
        }
    }
}
