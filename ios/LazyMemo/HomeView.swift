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
        _pen = State(initialValue: pen)
        _folders = State(initialValue: FolderModel(store: session.store, settings: session.settings))
    }

    /// 펜이 비서를 겸한다 — 묻기·시키기·되묻기 (docs/research/quick-capture-assistant-2026-09-15.md 를 폰에 그대로).
    /// `init` 에서 잇지 않는다: SwiftUI 는 이 뷰를 다시 만들 수 있고, 그때의 펜은 화면이 쥔 펜이 아니다 —
    /// 비서의 「끝났다」 신호가 버려진 펜으로 가서 답이 목록에 서지 않았다 (2026-09-16 시뮬레이터에서 봤다).
    private func attachAssistant() {
        pen.assistant = session.assistant
        // 남긴 직후의 알림 영수증 — 대조가 끝난 뒤 **이 기기에서 확인한 사실**만 (`ReservationReceipt`).
        pen.receiptFor = { [reminders] memo in
            await reminders.settle()
            return reminders.receipt(for: memo)
        }
        // 배너의 「지도 열기」 — 앱이 앞으로 온 뒤 종이의 카드와 같은 길로 지도 앱을 연다.
        // 화면이 서기 전에 눌렀으면 센터가 담아 두었다가 이 손이 서는 순간 연다.
        reminders.onOpenMap = { [store = session.store] id in
            guard let memo = store.memo(id) else { return }
            MapApp.openRoute(in: memo)
        }
        // 약속을 남기면 가는 길을 묻는다 — 「지금 여기」는 펜의 위치 단추와 같은 길로 잰다.
        guard pen.planner == nil else { return }
        let planner = RoutePlanner(store: session.store, settings: { [settings = session.settings] in settings.current })
        planner.here = { [here] in
            guard let fix = await here.fix(), let geo = fix.geo else { return nil }
            return LocatedPlace(name: fix.place, geo: geo)
        }
        planner.onWritten = { memo, _ in reveal.show(memo.id) }
        pen.planner = planner
    }

    /// 앱 밖에서 적힌 약속 메모의 가는 길을 **권한다** — 가장 나중 것 하나. 묻지 않는다: 결과 줄의 「가는 길」을 누르면
    /// 그때 묻는다 (인계서 묶음 3). 이미 묻고 있으면 그대로 둔다.
    /// 파일은 공유 시트가 떨군 것이라 저장소가 아직 모를 수 있다 — 한 번 대조한 뒤 찾는다.
    private func askRoute(for ids: [ULID]) {
        guard !ids.isEmpty else { return }
        attachAssistant()
        Task {
            await session.store.reconcile()
            // 물을 것이 아니게 된 메모(지웠거나, 이미 길이 있거나)의 알림은 거둔다.
            for id in ids { reminders.clearRouteAsk(id) }
            guard let planner = pen.planner, !planner.isActive,
                  let memo = ids.reversed().lazy.compactMap({ session.store.memo($0) }).first(where: { RouteAsk.applies($0) })
            else { return }
            showsTutorial = false
            notified = nil
            tab = .memos
            pen.offerRoute(for: memo)
        }
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
        // 「어디서 출발하시나요?」 알림을 눌렀다 — 편집 화면이 아니라 펜이 그 질문을 세운다 (`RouteAsk`).
        .onChange(of: reminders.askedRoute, initial: true) { _, id in
            guard let id else { return }
            reminders.askedRoute = nil
            askRoute(for: [id])
        }
        // 공유 시트가 남긴 질문 — 알림을 안 눌렀어도, 권한이 없어도, 앱을 열면 펜이 묻는다.
        .onAppear { askRoute(for: RouteAsk.takePending(in: AppPaths.sharedContainer())) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            askRoute(for: RouteAsk.takePending(in: AppPaths.sharedContainer()))
        }
        // 남기면 손끝에 한 번 — 글 칸이 비는 것 말고도 「됐다」는 신호가 있어야 한다.
        .sensoryFeedback(.success, trigger: pen.lastLeft) { _, new in new != nil }
        // 첫 실행에 안내를 띄우지 않는다 — 펜이 바로 서고, 첫 메모 뒤에 필요한 조작 하나만 듣는다 (`PenModel.finishLeaving`,
        // 인계서 묶음 3 `#first-real-note`). 다섯 장 안내는 더 보기 → 「사용법」에 그대로 있다 (`StackView`).
        .onAppear { attachAssistant() }
        .sheet(isPresented: $showsTutorial, onDismiss: { pen.releaseLaunchFocus() }) {
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
