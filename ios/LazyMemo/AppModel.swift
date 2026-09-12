import Foundation
import LazyMemoCore
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
    }

    private(set) var phase: Phase = .opening

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
            phase = .ready(Session(
                store: store,
                settings: SettingsStore(location: resolved.paths.settings),
                draft: CaptureDraftStore(location: resolved.paths.captureDraft),
                usingCloud: resolved.usingCloud
            ))
        } catch {
            phase = .failed("메모 폴더를 열지 못했습니다 — \(error)")
        }
    }

    /// 앱이 뒤로 물러날 때. 적던 글은 파일에 내려 두고, 다시 앞으로 올 때는
    /// 밖에서 온 변경을 한 번 대조한다 — 폰이 자는 동안 맥에서 적은 것.
    func background() {
        guard case .ready(let session) = phase else { return }
        session.draft.flush()
    }

    func foreground() async {
        guard case .ready(let session) = phase else { return }
        await session.store.reconcile()
    }
}
