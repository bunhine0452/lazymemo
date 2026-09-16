import LazyMemoCore
import LazyMemoPlaces
import LazyMemoReminders
import LazyMemoSpotlight
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
    @State private var reminders = ReminderCenter.shared
    @State private var spotlight = SpotlightCenter.shared
    /// 알림을 눌러 열 메모. 시트로 띄운다 — 어느 탭에 있든, 무엇을 보고 있든 같은 길.
    @State private var notified: NotifiedMemo?
    /// 첫 실행의 안내. 본 뒤로는 More 메뉴의 「사용법」으로만.
    @State private var showsTutorial = false

    enum Tab: Hashable { case memos, calendar }

    /// `sheet(item:)` 은 `Identifiable` 을 원하고 `ULID` 는 값이라 — 얇게 감싼다.
    private struct NotifiedMemo: Identifiable { let id: ULID }

    init(session: AppModel.Session) {
        self.session = session
        let pen = PenModel(store: session.store, draft: session.draft)
        pen.holdsLaunchFocus = !Tutorial.seen
        _pen = State(initialValue: pen)
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
        .environment(\.assistant, session.assistant)
        .sheet(item: $notified) { item in
            NavigationStack {
                MemoEditorView(store: session.store, id: item.id, reveal: reveal, listedFolders: folders.names) { pen.adopt(target: $0) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("닫기") { notified = nil } }
                }
            }
        }
        // 꺼진 채 눌렀으면 화면이 생기기 전에 담겨 있다 (`initial`). 열면 비운다.
        .onChange(of: reminders.opened, initial: true) { _, id in
            guard let id else { return }
            showsTutorial = false
            notified = NotifiedMemo(id: id)
            reminders.opened = nil
        }
        // Spotlight 에서 눌러 온 것도 같은 시트로 연다 — 어디서 왔든 「그 메모」다.
        .onChange(of: spotlight.opened, initial: true) { _, id in
            guard let id else { return }
            showsTutorial = false
            notified = NotifiedMemo(id: id)
            spotlight.opened = nil
        }
        // 남기면 손끝에 한 번 — 글 칸이 비는 것 말고도 「됐다」는 신호가 있어야 한다.
        .sensoryFeedback(.success, trigger: pen.lastLeft) { _, new in new != nil }
        .onAppear {
            // 펜이 비서를 겸한다 — 묻기·시키기·되묻기 (docs/research/quick-capture-assistant-2026-09-15.md 를 폰에 그대로).
            // `init` 에서 잇지 않는다: SwiftUI 는 이 뷰를 다시 만들 수 있고, 그때의 펜은 화면이 쥔 펜이 아니다 —
            // 비서의 「끝났다」 신호가 버려진 펜으로 가서 답이 목록에 서지 않았다 (2026-09-16 시뮬레이터에서 봤다).
            pen.assistant = session.assistant
            // 약속을 남기면 가는 길을 묻는다 — 「지금 여기」는 펜의 위치 단추와 같은 길로 잰다.
            if pen.planner == nil {
                let planner = RoutePlanner(store: session.store, settings: { [settings = session.settings] in settings.current })
                planner.here = { [here] in
                    guard let fix = await here.fix(), let geo = fix.geo else { return nil }
                    return LocatedPlace(name: fix.place, geo: geo)
                }
                planner.onWritten = { memo, _ in reveal.show(memo.id) }
                pen.planner = planner
            }
            if !Tutorial.seen { showsTutorial = true }
        }
        .sheet(isPresented: $showsTutorial, onDismiss: {
            Tutorial.markSeen()
            pen.releaseLaunchFocus()
        }) {
            TutorialView()
        }
        .onChange(of: tab) { _, tab in
            // 달력 탭에서는 고른 날이 펜에 미리 물린다. 메모 탭으로 오면 푼다.
            if tab == .memos { pen.presetDay = nil }
        }
        .onChange(of: pen.lastLeft) { _, left in
            // 새 줄이 맨 위에 생기고 화면이 그리로 간다.
            if let left { reveal.show(left) }
        }
        // 「이 메모에게 시키기」는 메모 탭의 펜에서 — 답·결과 줄이 서는 목록이 거기에 있다.
        .onChange(of: pen.target) { _, target in
            if target != nil { tab = .memos }
        }
    }
}
