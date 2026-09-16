import CoreSpotlight
import Foundation
import LazyMemoCore
import Observation

/// 메모를 시스템 검색에 — 앱을 열지 않고도 찾힌다 (철학 4 — 앱은 자기를 드러내지 않는다).
///
/// 켜짐은 `UserDefaults` 에 적는다. 색인은 **이 기기의 것**이라 iCloud 로 건너가지
/// 않고, 켜고 끄는 값도 건너가지 않는다. 기본은 켜짐 — 기기 밖으로 나가는 것이 없고
/// 묻는 권한도 없다. 맥은 설정에서 끌 수 있다.
///
/// ## 대조가 전부다
///
/// `ReminderCenter` 와 같은 모양이다. 저장소가 바뀔 때마다 **올라가 있어야 할 것의
/// 집합**(`SpotlightEntry`)을 새로 세고 시스템 색인을 그것에 맞춘다 — 없어진 것은
/// 내리고, 바뀐 것은 다시 올리고, 같은 것은 둔다. 시스템 색인은 «지금 무엇이 있나»
/// 를 물을 길이 없어 올려 둔 것의 지문을 `UserDefaults` 에 함께 적는다 — 껐다 켜도
/// 바뀐 것만 다시 올린다.
@MainActor @Observable
public final class SpotlightCenter {
    public static let shared = SpotlightCenter(index: SystemSpotlightIndex.ifBundled(), defaults: .standard)

    /// 「Spotlight 에서 찾기」 — 이 기기의 값.
    public private(set) var enabled: Bool
    /// 지금 올라가 있는 수.
    public private(set) var indexedCount = 0
    /// 올리지 못한 것이 있다 — 사람의 말로. 삼키지 않는다.
    public private(set) var trouble: String?
    /// 검색 결과를 눌러 열어 달라는 메모. 화면이 읽고 `nil` 로 되돌린다 —
    /// 앱이 꺼진 채 눌렀을 때 화면이 아직 없어서 여기 담아 둔다.
    public var opened: ULID?
    /// 이 실행 파일이 색인을 올릴 수 있나. 앱 번들 밖에서는 못 올린다.
    public var available: Bool { index != nil }

    /// 검색 결과를 눌렀을 때 시스템이 건네는 활동의 종류 — 화면이 `CoreSpotlight` 를 들지 않게 여기 둔다.
    public nonisolated static let activityType = CSSearchableItemActionType

    private let index: SpotlightIndex?
    private let defaults: UserDefaults
    private var store: MemoStore?
    private var running = false
    private var dirty = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    /// 올려 둔 것의 지문 — id → fingerprint.
    private var indexed: [String: String]
    private static let enabledKey = "spotlight.enabled"
    private static let indexedKey = "spotlight.indexed"

    public init(index: SpotlightIndex?, defaults: UserDefaults) {
        self.index = index
        self.defaults = defaults
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        indexed = defaults.dictionary(forKey: Self.indexedKey) as? [String: String] ?? [:]
        indexedCount = indexed.count
    }

    /// 저장소를 붙이고 첫 대조를 돈다. 두 번 불러도 붙인 저장소는 그대로다.
    public func start(store: MemoStore) {
        guard self.store == nil else { refresh(); return }
        self.store = store
        observe()
        refresh()
    }

    private func observe() {
        guard let store else { return }
        withObservationTracking { _ = store.memos } onChange: {
            Task { @MainActor [weak self] in
                self?.observe()
                self?.refresh()
            }
        }
    }

    /// 「Spotlight 에서 찾기」. 끄면 올려 둔 것을 전부 내린다 — 켠 적 없는 것처럼.
    public func setEnabled(_ value: Bool) {
        enabled = value
        defaults.set(value, forKey: Self.enabledKey)
        refresh()
    }

    /// 다시 세어 색인을 맞춘다. 돌고 있으면 한 번 더 돌게 표시만 한다.
    public func refresh() {
        dirty = true
        guard !running else { return }
        running = true
        Task { [self] in
            while dirty {
                dirty = false
                await reconcile()
            }
            running = false
            let resumed = waiting
            waiting.removeAll()
            for continuation in resumed { continuation.resume() }
        }
    }

    /// 돌고 있는 대조가 끝날 때까지 기다린다. 시험이 쓴다.
    public func settle() async {
        await Task.yield()
        await Task.yield()
        guard running else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// 검색 결과를 눌러 앱이 깨어났다 — 그 활동이 가리키는 메모. 다른 활동이면 `nil`.
    public nonisolated static func memoID(from activity: NSUserActivity) -> ULID? {
        guard activity.activityType == CSSearchableItemActionType,
              let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return ULID(raw)
    }

    private func reconcile() async {
        guard let index, let store else { return }

        guard enabled else {
            guard !indexed.isEmpty else { return }
            do {
                try await index.removeAll()
                indexed = [:]
                remember()
                trouble = nil
            } catch {
                trouble = L("Spotlight 색인을 갱신하지 못했어요.")
            }
            return
        }
        guard index.available else {
            trouble = L("이 기기에서는 Spotlight 색인을 쓸 수 없어요.")
            return
        }

        // 저장소의 지금 모습. `await` 를 지나는 동안 바뀌면 `dirty` 가 서서 한 번 더 돈다 —
        // 그때 이 스냅샷으로 한 일은 다음 회차가 바로잡는다 (올리기·내리기는 몇 번 해도 같다).
        let wanted = Dictionary(
            SpotlightEntry.entries(store.memos).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let stale = indexed.keys.filter { wanted[$0] == nil }
        let changed = wanted.values.filter { indexed[$0.id] != $0.fingerprint }

        do {
            if !stale.isEmpty {
                try await index.remove(ids: stale)
                for id in stale { indexed[id] = nil }
            }
            if !changed.isEmpty {
                try await index.index(changed)
                for entry in changed { indexed[entry.id] = entry.fingerprint }
            }
            trouble = nil
        } catch {
            trouble = L("Spotlight 색인을 갱신하지 못했어요.")
        }
        remember()
    }

    private func remember() {
        defaults.set(indexed, forKey: Self.indexedKey)
        indexedCount = indexed.count
    }
}
