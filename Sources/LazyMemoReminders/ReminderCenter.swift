import Foundation
import LazyMemoCore
import Observation

/// 이 기기의 알림 — 켜고 끄는 것도, 걸어 둔 예약도 **이 기기의 것**이다.
///
/// 켜짐은 `UserDefaults` 에 적는다. 메모 파일은 iCloud 로 건너가지만 이 값은
/// 건너가지 않는다 — 폰에서 켰다고 맥이 묻지도 않고 울리기 시작하면 그것은
/// 동의가 아니라 전파다. 양쪽에서 켜면 양쪽에서 울릴 수 있고, 그 사실은
/// 설정 화면이 적어 둔다.
///
/// ## 대조가 전부다
///
/// 예약을 「만든다·지운다」로 다루지 않는다. 저장소가 바뀔 때마다 **있어야 할
/// 예약의 집합**(`Recall.reservations`)을 새로 세고 OS 의 큐를 그것에 맞춘다 —
/// 없어야 할 것은 빼고, 있어야 할 것은 걸고, 같은 것은 둔다. 수정·미루기·삭제·
/// 체크 완료·권한 변경·끄기가 전부 이 한 길을 지나므로 낡은 예약이 남을 자리가
/// 없다. 예약의 id 는 메모의 id 라 같은 메모는 늘 같은 자리를 찾는다.
///
/// ## 읽는 동안 바뀌면 다시 센다
///
/// OS 큐를 읽는 것은 `await` 다. 그 사이 저장소가 바뀌면 방금 센 집합은 이미
/// 낡은 것이라, 큐에 손대기 전에 버리고 처음부터 다시 센다 (`dirty`). 대조는
/// 한 번에 하나만 돌고, 도는 동안 들어온 변경은 다음 회차가 맡는다.
@MainActor @Observable
public final class ReminderCenter {
    public static let shared = ReminderCenter(queue: SystemReminderQueue.ifBundled(), defaults: .standard)

    /// 사람이 「이 기기에서 알림 받기」를 켰나. 시스템 권한과는 별개의 뜻이다 —
    /// 권한을 거절해도 켜 둔 뜻은 남고, 설정에서 도로 허용하면 그때부터 건다.
    public private(set) var enabled: Bool
    public private(set) var authorization: ReminderAuthorization = .undecided
    public var denied: Bool { authorization == .denied }
    /// 지금 OS 에 걸려 있는 예약 수.
    public private(set) var scheduledCount = 0
    /// 한도 밖에 남은 수. 앱이 다시 읽을 때 앞의 것이 지나간 자리를 메운다.
    public private(set) var overflow = 0
    /// 걸지 못한 것이 있다 — 사람의 말로. 삼키지 않는다.
    public private(set) var trouble: String?
    /// 알림을 눌러 열어 달라는 메모. 화면이 읽고 `nil` 로 되돌린다 — 앱이 꺼진 채
    /// 눌렀을 때 화면이 아직 없어서 여기 담아 둔다.
    public var opened: ULID?
    /// 화면이 있으면 바로 부른다 (맥). 없으면 `opened` 에 남긴다 (폰).
    public var onOpen: ((ULID) -> Void)?
    /// 이 실행 파일이 알림을 걸 수 있나. 앱 번들 밖(bare `swift run`·`swift test`)에서는 못 건다.
    public var available: Bool { queue != nil }

    private let queue: ReminderQueue?
    private let defaults: UserDefaults
    private var store: MemoStore?
    private var running = false
    private var dirty = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private static let key = "recall.notifications.enabled"
    nonisolated static let prefix = "recall."

    public init(queue: ReminderQueue?, defaults: UserDefaults) {
        self.queue = queue
        self.defaults = defaults
        enabled = defaults.bool(forKey: Self.key)
        queue?.onTap = { [weak self] raw in
            guard let self, let id = ULID(raw) else { return }
            open(id)
        }
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

    /// 「이 기기에서 알림 받기」. 켤 때만 시스템에 묻는다 — 첫 실행에는 묻지 않는다.
    public func setEnabled(_ value: Bool) async {
        guard let queue else {
            trouble = L("설치된 앱에서만 알림을 켤 수 있어요.")
            return
        }
        if value {
            do {
                let allowed = try await queue.requestAuthorization()
                authorization = allowed ? .allowed : .denied
            } catch {
                trouble = L("알림 권한을 확인하지 못했어요. 다시 시도해 주세요.")
                return
            }
        }
        enabled = value
        defaults.set(value, forKey: Self.key)
        refresh()
    }

    /// 다시 세어 큐를 맞춘다. 돌고 있으면 한 번 더 돌게 표시만 한다.
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
    ///
    /// 저장소 관찰이 띄운 Task 가 먼저 돌도록 한 번 양보한다 — 안 그러면 방금 바꾼
    /// 것이 아직 대조에 들어가기 전이라 「돌고 있지 않다」로 읽는다.
    public func settle() async {
        await Task.yield()
        await Task.yield()
        guard running else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func open(_ id: ULID) {
        if let onOpen { onOpen(id) } else { opened = id }
    }

    private func reconcile() async {
        guard let queue, let store else { return }
        authorization = await queue.authorization()
        guard !dirty else { return }
        let allowed = enabled && authorization == .allowed
        let all = Recall.reservations(store.memos, limit: Int.max)
        let wanted = allowed ? Array(all.prefix(Recall.reservationLimit)) : []
        overflow = allowed ? max(0, all.count - Recall.reservationLimit) : 0
        let liveIDs = Set(store.memos.filter(Recall.eligible).map(\.id.stringValue))

        let pending = await queue.pending().filter { $0.id.hasPrefix(Self.prefix) }
        // OS 를 읽는 동안 저장소가 바뀌었으면 방금 센 집합은 낡았다. 큐에 손대기 전에 버린다.
        guard !dirty else { return }
        let wantedIDs = Set(wanted.map { Self.prefix + $0.id.stringValue })
        queue.removePending(pending.map(\.id).filter { !wantedIDs.contains($0) })

        // 알림 센터에 남은 것도 같은 규칙이다 — 지운 메모·끝낸 목록의 알림은 거짓말이 된다.
        let delivered = await queue.delivered().filter { $0.hasPrefix(Self.prefix) }
        guard !dirty else { return }
        queue.removeDelivered(delivered.filter { id in
            !enabled || !liveIDs.contains(String(id.dropFirst(Self.prefix.count)))
        })

        var count = 0
        var failed = false
        for item in wanted {
            if dirty { return }
            let request = ReminderRequest(
                id: Self.prefix + item.id.stringValue,
                title: item.title,
                body: L("다시 볼 시간이에요. 눌러서 메모를 펼치세요."),
                date: item.date
            )
            if pending.contains(request) { count += 1; continue }
            do {
                try await queue.add(request)
                count += 1
            } catch {
                failed = true
            }
        }
        scheduledCount = count
        trouble = failed ? L("일부 알림을 걸지 못했어요. 다시 시도해 주세요.") : nil
    }
}

/// 시스템 권한. `provisional`·`ephemeral` 도 「허용」으로 친다 — 걸면 온다.
public enum ReminderAuthorization: Sendable, Equatable {
    case undecided, allowed, denied
}

/// OS 에 거는 예약 하나. 같은 값이면 같은 예약이다 — 대조가 이 동등성으로 「둘 것」을 고른다.
public struct ReminderRequest: Sendable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let date: Date

    public init(id: String, title: String, body: String, date: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
    }
}

/// OS 알림 큐의 얇은 문. 실제 앱은 `SystemReminderQueue`, 시험은 가짜가 선다.
@MainActor public protocol ReminderQueue: AnyObject {
    /// 알림을 눌렀다 — 메모 id 문자열.
    var onTap: ((String) -> Void)? { get set }
    func authorization() async -> ReminderAuthorization
    /// 시스템 창을 띄운다. 이미 답했으면 그 답을 그대로 돌려준다.
    func requestAuthorization() async throws -> Bool
    func pending() async -> [ReminderRequest]
    func add(_ request: ReminderRequest) async throws
    func removePending(_ ids: [String])
    /// 알림 센터에 남아 있는 것의 id.
    func delivered() async -> [String]
    func removeDelivered(_ ids: [String])
}
