import Foundation
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoReminders
import LazyMemoSpotlight
import LazyMemoWidgetsCore
import Observation

/// 폰이 켜질 때 하는 일 — 자리를 정하고 저장소를 연다.
///
/// 자리는 둘 중 하나다. **iCloud 컨테이너의 `Documents/`** 면 맥과 같은 폴더를
/// 보는 것이고, 컨테이너가 없으면(iCloud 가 꺼져 있거나 entitlement 없는 빌드)
/// 이 기기 안 Documents 다. 어느 쪽인지를 화면이 한 줄로 적는다 — 조용히
/// 로컬로 떨어지면 사용자는 「맥에 안 나타난다」만 보고 왜인지는 영영 모른다.
@Observable
final class AppModel {
    enum Phase {
        case opening
        case ready(Session)
        /// 저장소를 열지 못했다. 사람의 말로.
        case failed(String)
    }

    /// 열린 뒤 화면이 손에 쥐는 것 전부.
    struct Session {
        let store: MemoStore
        let settings: SettingsStore
        let draft: CaptureDraftStore
        let usingCloud: Bool
        /// 이 기기의 모델 — 묻기·시키기·오늘. 모델은 vault 밖 support 에 산다.
        let assistant: AssistantModel
    }

    private(set) var phase: Phase = .opening
    /// 이 기기의 알림. delegate 는 `PhoneDelegate` 가 먼저 세웠다.
    private let reminders = ReminderCenter.shared
    /// 저장소가 서기 전에 `lazymemo://add` 로 들어온 글. 서면 들여보낸다.
    private var pendingInbound: [InboundNote] = []

    func start() async {
        guard case .opening = phase else { return }

        // 컨테이너 찾기는 첫 호출에 iCloud 데몬과 이야기하는 막히는 호출이라
        // 메인 밖에서 한다.
        let container = await Task.detached(priority: .userInitiated) {
            AppPaths.ubiquityContainer()
        }.value
        // iCloud 가 없으면 App Group 폴더 — 공유 확장이 같은 곳에 떨구려면 앱의
        // 샌드박스 안이어서는 안 된다.
        let resolved = AppPaths.resolveCloud(container: container, shared: AppPaths.sharedContainer())

        do {
            try resolved.paths.createDirectories()
            let store = try MemoStore(paths: resolved.paths)
            await store.start()
            // 메모를 다 읽은 뒤에 붙인다 — 빈 목록에 대조하면 걸어 둔 것을 전부 지운다.
            reminders.start(store: store)
            // 시스템 검색도 같다 — 빈 목록에 대조하면 올려 둔 것을 전부 내린다.
            SpotlightCenter.shared.start(store: store)
            // 홈 화면의 위젯도 같은 파일을 본다 — 바뀌면 다시 그리게 한다.
            WidgetRefresher.shared.start(store: store)
            phase = .ready(Session(
                store: store,
                settings: SettingsStore(location: resolved.paths.settings),
                draft: CaptureDraftStore(location: resolved.paths.captureDraft),
                usingCloud: resolved.usingCloud,
                assistant: AssistantModel(service: store.service, support: resolved.paths.support)
            ))
            let waiting = pendingInbound
            pendingInbound = []
            for inbound in waiting { receive(inbound) }
        } catch {
            phase = .failed(String(localized: "메모 폴더를 열지 못했습니다 — \(String(describing: error))"))
        }
    }

    /// 앱이 뒤로 물러날 때. 적던 글은 파일에 내려 두고, 다시 앞으로 올 때는
    /// 밖에서 온 변경을 한 번 대조한다 — 폰이 자는 동안 맥에서 적은 것.
    func background() {
        guard case .ready(let session) = phase else { return }
        session.draft.flush()
        // 미뤄 둔 위젯 갱신도 지금 — 2초 뒤에는 멈춰 있을 수 있다.
        WidgetRefresher.shared.flush()
        // 시스템이 곧 멈출 수 있다 — 생성을 끊고 모델을 내린다. 끝나기를 기다리지 않는다 (명세 §6).
        Task { await session.assistant.suspend() }
    }

    /// `lazymemo://…` — 위젯·단축어가 두드리는 문 (`LazyMemoApp` 의 `onOpenURL`).
    ///
    /// 메모는 알림·Spotlight 와 **같은 자리**에 담아 같은 시트로 열리고(`HomeView` 가
    /// `SpotlightCenter.opened` 를 읽는다), 적기는 펜이 받아 간다(`AppLinks`·`PenBar`).
    /// 그 밖의 주소는 맥과 같은 문(`InboundLink`) — `lazymemo://add?text=…` 가 새 메모가 된다.
    /// 모르는 주소는 조용히 버린다.
    func open(url: URL) {
        switch WidgetLink.destination(of: url) {
        case .memo(let id):
            SpotlightCenter.shared.opened = id
        case .write:
            AppLinks.shared.requestWrite()
        case nil:
            guard let inbound = InboundLink.note(from: url) else { return }
            receive(inbound)
        }
    }

    /// 맥의 `InboundDoor` 와 같은 규칙 — `내일 3시` 는 일정, `@강남역` 은 장소 (`NoteReader`).
    private func receive(_ inbound: InboundNote) {
        guard case .ready(let session) = phase else {
            pendingInbound.append(inbound)
            return
        }
        let note = NoteReader.read(inbound)
        Task {
            _ = try? await session.store.create(
                body: note.body, due: note.due, at: note.at, every: note.every, place: note.place, geo: note.geo
            )
        }
    }

    func foreground() async {
        guard case .ready(let session) = phase else { return }
        await session.store.reconcile()
        reminders.refresh()
    }
}
