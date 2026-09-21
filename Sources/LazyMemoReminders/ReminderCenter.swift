import Foundation
import LazyMemoCore
import LazyMemoWidgetsCore
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
///
/// ## 배너에서 끝난다
///
/// 배너가 울린 순간이 곧 「지금 볼까, 나중에 볼까」를 정하는 순간인데, 할 수 있는 것이
/// 열기뿐이면 미루는 데 다섯 번의 손이 든다 — 열고, 우클릭하고, 창을 띄우고, 칩을 누르고,
/// 저장한다 (2026-09-17 편의성 감사 §2.1). 그래서 배너에 단추를 단다 (`ReminderAction`):
/// 「한 시간 뒤」「내일 아침 9시」「봤어요」, 출발 알림에는 「10분 뒤」「지도 열기」.
/// 미루기는 `surface` 를 고치는 것이라 파일에 적히고 다른 기기도 같은 것을 본다.
///
/// 앱이 꺼진 채 단추를 눌렀을 수 있다 — 폰은 배경에서 잠깐 깨우고 저장소는 열리지 않는다.
/// 그래서 저장소가 필요한 것은 **정해진 시각째로** 적어 두었다가(`pendingActions`, defaults)
/// 저장소가 붙을 때 그대로 적용한다. 「한 시간 뒤」는 누른 순간의 한 시간 뒤이지 앱을 다시
/// 연 시각의 한 시간 뒤가 아니다.
@MainActor @Observable
public final class ReminderCenter {
    public static let shared = ReminderCenter(
        queue: SystemReminderQueue.ifBundled(), defaults: .standard, group: AppPaths.sharedContainer()
    )

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
    /// 마지막 대조가 메모마다 낸 결과 — 영수증(`receipt(for:)`)의 재료. 대조가 한 번은 돌아야 채워진다.
    private var outcomes: [ULID: Outcome] = [:]
    /// 대조를 한 번이라도 끝냈나. 그 전의 영수증은 「확인 중」이다.
    private var reconciled = false

    private enum Outcome: Equatable {
        case scheduled(Date), failed, overflow
    }
    /// 알림을 눌러 열어 달라는 메모. 화면이 읽고 `nil` 로 되돌린다 — 앱이 꺼진 채
    /// 눌렀을 때 화면이 아직 없어서 여기 담아 둔다.
    public var opened: ULID?
    /// 화면이 있으면 바로 부른다 (맥). 없으면 `opened` 에 남긴다 (폰).
    public var onOpen: ((ULID) -> Void)?
    /// 「어디서 출발하시나요?」 알림을 눌렀다 — 편집 화면이 아니라 펜의 질문이 설 메모 (`RouteAsk`). 화면이 읽고 `nil` 로.
    public var askedRoute: ULID?
    /// 배너의 「봤어요」 — 이 기기의 기억(`NowSeen`)에는 여기서 적고, 화면이 할 일이 더 있으면 부른다:
    /// 맥은 나온 종이를 내리고, 폰은 띠의 기억을 다시 읽는다.
    public var onSeen: ((ULID) -> Void)?
    /// 「봤어요」가 한 번 적힐 때마다 오른다 — 폰의 띠가 이것을 보고 `NowSeen` 을 다시 읽는다
    /// (앱이 앞에 있는 동안 배너에서 눌렀을 때는 앞으로 오는 순간이 없다).
    public private(set) var seenVersion = 0
    /// 배너의 「지도 열기」 — 어느 지도를 어떻게 열지는 화면이 정한다 (맥은 웹, 폰은 깔린 앱).
    /// 화면이 아직 없으면 담아 두었다가 이 손이 서는 순간 연다.
    public var onOpenMap: ((ULID) -> Void)? { didSet { drainPending() } }
    /// 이 실행 파일이 알림을 걸 수 있나. 앱 번들 밖(bare `swift run`·`swift test`)에서는 못 건다.
    public var available: Bool { queue != nil }

    private let queue: ReminderQueue?
    private let defaults: UserDefaults
    /// 앱 그룹 폴더 — 「켜짐」의 표를 여기 한 벌 더 적어 앱 밖(공유 시트·인텐트)이 읽게 한다 (`RecallSwitch`).
    /// 시험은 `nil` 을 준다 — 진짜 그룹 폴더에 표를 남기지 않는다.
    private let group: URL?
    private var store: MemoStore?
    private var running = false
    private var dirty = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    /// 저장소나 화면이 없어서 아직 못 한 단추 — defaults 에도 적어 둔다 (배경에서 깬 폰은 곧 잠든다).
    private var pendingActions: [PendingAction] = [] { didSet { persistPending() } }
    private static let key = "recall.notifications.enabled"
    private static let pendingKey = "recall.pending-actions"
    /// OS 예약의 id 머리 — 앱 밖(공유 시트·인텐트)도 같은 이름을 쓴다 (`Recall.notificationPrefix`).
    nonisolated static let prefix = Recall.notificationPrefix

    public init(queue: ReminderQueue?, defaults: UserDefaults, group: URL? = nil) {
        self.queue = queue
        self.defaults = defaults
        self.group = group
        enabled = defaults.bool(forKey: Self.key)
        // 이 판 전에 켜 둔 사람의 표도 서게 — 켤 때만 적으면 그 사람의 공유 시트는 영영 「앱을 열면」이다.
        RecallSwitch.write(enabled: enabled, in: group)
        queue?.onTap = { [weak self] raw in
            guard let self, let id = ULID(raw) else { return }
            open(id)
        }
        queue?.onAskRoute = { [weak self] raw in
            guard let self, let id = ULID(raw) else { return }
            askedRoute = id
        }
        queue?.onAction = { [weak self] action, raw, fired in
            guard let self, let id = ULID(raw) else { return }
            handle(action, for: id, fired: fired)
        }
        pendingActions = Self.loadPending(from: defaults)
    }

    /// 저장소를 붙이고 첫 대조를 돈다. 두 번 불러도 붙인 저장소는 그대로다.
    public func start(store: MemoStore) {
        guard self.store == nil else { refresh(); return }
        self.store = store
        observe()
        drainPending()
        refresh()
    }

    // MARK: 배너의 단추

    /// 단추 하나를 받는다. 지금 할 수 있으면 하고, 아니면 담아 둔다.
    ///
    /// `fired` 는 그 알림이 걸려 있던 시각 — 「봤어요」의 이름표다 (`Recall.Card.stamp` 와 같은 값이라
    /// 폰의 「지금」 띠와 위젯이 그 카드를 내려놓는다). 저장소 없이도 적을 수 있어 배경에서 깬 폰도 된다.
    public func handle(_ action: ReminderAction, for id: ULID, fired: Date, now: Date = Date()) {
        switch action {
        case .seen:
            var seen = NowSeen.load()
            seen[id] = fired
            NowSeen.save(seen, now: now)
            seenVersion += 1
            onSeen?(id)
        case .openMap:
            if let onOpenMap { onOpenMap(id) } else { pendingActions.append(.init(action: action, memo: id, until: nil)) }
        case .hourLater, .tenMinutesLater, .tomorrowMorning:
            guard let until = Snooze.date(for: action, now: now) else { return }
            apply(.init(action: action, memo: id, until: until))
        }
    }

    /// 담아 둔 것 중 지금 할 수 있는 것을 한다 — 저장소가 붙거나 화면의 손이 설 때.
    private func drainPending() {
        guard !pendingActions.isEmpty else { return }
        let waiting = pendingActions
        pendingActions.removeAll()
        for item in waiting { apply(item) }
    }

    private func apply(_ item: PendingAction) {
        guard let id = item.memo else { return }
        switch item.action {
        case .openMap:
            if let onOpenMap { onOpenMap(id) } else { pendingActions.append(item) }
        case .hourLater, .tenMinutesLater, .tomorrowMorning:
            guard let until = item.until else { return }
            guard let store else { pendingActions.append(item); return }
            // 지운 메모의 단추는 늦게 온 것일 수 있다 — 조용히 버린다.
            guard store.memo(id) != nil else { return }
            Task {
                _ = try? await store.update(id, surface: .some(until))
                refresh()
            }
        case .seen:
            break
        }
    }

    private struct PendingAction: Codable, Equatable {
        let action: ReminderAction
        /// 메모 id 문자열 — `ULID` 는 Codable 이 아니라 글자로 둔다.
        let memoID: String
        /// 미룰 시각 — 누른 순간에 정한 것. 지도는 없다.
        let until: Date?

        init(action: ReminderAction, memo: ULID, until: Date?) {
            self.action = action
            self.memoID = memo.stringValue
            self.until = until
        }

        var memo: ULID? { ULID(memoID) }
    }

    private func persistPending() {
        if pendingActions.isEmpty {
            defaults.removeObject(forKey: Self.pendingKey)
        } else if let data = try? JSONEncoder().encode(pendingActions) {
            defaults.set(data, forKey: Self.pendingKey)
        }
    }

    private static func loadPending(from defaults: UserDefaults) -> [PendingAction] {
        guard let data = defaults.data(forKey: pendingKey) else { return [] }
        return (try? JSONDecoder().decode([PendingAction].self, from: data)) ?? []
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

    /// 「어디서 출발하시나요?」 알림을 거둔다 — 펜이 그 질문을 세웠거나 그 메모가 더는 물을 것이 아닐 때.
    public func clearRouteAsk(_ id: ULID) {
        let identifier = RouteAsk.notificationPrefix + id.stringValue
        queue?.removePending([identifier])
        queue?.removeDelivered([identifier])
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
        RecallSwitch.write(enabled: value, in: group)
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
        var results: [ULID: Outcome] = [:]
        for item in all.dropFirst(wanted.count) where allowed { results[item.id] = .overflow }
        for item in wanted {
            if dirty { return }
            let request = ReminderRequest(
                id: Self.prefix + item.id.stringValue,
                title: item.title,
                body: item.body ?? Recall.defaultNotificationBody,
                date: item.date,
                // 가는 길이 적힌 약속의 알림은 출발 알림이다 — 단추가 다르다.
                category: item.body == nil ? .recall : .departure
            )
            if pending.contains(request) { count += 1; results[item.id] = .scheduled(item.date); continue }
            do {
                try await queue.add(request)
                count += 1
                results[item.id] = .scheduled(item.date)
            } catch {
                failed = true
                results[item.id] = .failed
            }
        }
        scheduledCount = count
        outcomes = results
        reconciled = true
        trouble = failed ? L("일부 알림을 걸지 못했어요. 다시 시도해 주세요.") : nil
    }

    // MARK: 영수증 — 저장 직후 화면이 적는 「이 기기에서 확인한 사실」

    /// 이 메모의 알림이 **이 기기에서** 어떻게 됐는가. 저장 직후의 화면이 이것을 적는다 — 「예약됨」이라
    /// 적을 수 있는 것은 OS 큐에 실제로 넣은 뒤뿐이고, 그 전까지는 「확인 중」이다. 다른 기기의 사정은
    /// 여기서 모른다: 그쪽이 켜 두었으면 그쪽도 울린다는 것은 설정 화면이 적는다.
    ///
    /// 대조는 저장소가 바뀐 뒤 비동기로 돈다. 방금 만든 메모의 답을 받으려면 `settle()` 뒤에 부른다 —
    /// 안 그러면 **앞 메모의 결과를 새 메모에 붙이는** 것이 아니라 그냥 「확인 중」이 온다 (id 로 찾으므로).
    public func receipt(for memo: Memo, now: Date = Date()) -> ReservationReceipt {
        guard Recall.eligible(memo) else { return .notWanted }
        guard let at = memo.surfacesAt else { return memo.due == nil ? .noTime : .dateOnly }
        guard at > now else { return .passed }
        guard available else { return .unavailable }
        guard enabled else { return .off }
        if authorization == .denied { return .denied }
        guard reconciled else { return .pending }
        switch outcomes[memo.id] {
        case .scheduled(let date): return .scheduled(date)
        case .failed: return .failed
        case .overflow: return .overflow
        case nil: return .pending
        }
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
    /// 어떤 단추를 다는가.
    public let category: ReminderCategory

    public init(id: String, title: String, body: String, date: Date, category: ReminderCategory = .recall) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.category = category
    }
}

/// 배너의 단추 — 앱을 열지 않고 그 자리에서 끝나는 것.
///
/// HIG Notifications: "Prefer actions that let people perform common, time-saving tasks that eliminate
/// the need to open your app." / "Avoid providing an action that merely opens your app." 그래서 「열기」
/// 단추는 없다 — 배너를 누르는 것이 열기다.
public enum ReminderAction: String, CaseIterable, Sendable, Codable {
    /// 한 시간 뒤에 다시.
    case hourLater = "hour-later"
    /// 10분 뒤에 다시 — 출발 알림의 「조금만 더」.
    case tenMinutesLater = "ten-minutes-later"
    /// 내일 아침 9시에 다시.
    case tomorrowMorning = "tomorrow-morning"
    /// 봤어요 — 폰의 「지금」 띠와 위젯에서 내려가고, 맥은 나온 종이가 내려간다.
    case seen
    /// 지도 열기 — 출발 알림에서 길을 지도 앱으로. 폰은 앱이 앞으로 와야 다른 앱을 열 수 있다.
    case openMap = "open-map"

    /// 단추에 적히는 말. 짧게 — 길면 잘린다.
    public var title: String {
        switch self {
        case .hourLater: L("한 시간 뒤")
        case .tenMinutesLater: L("10분 뒤")
        case .tomorrowMorning: L("내일 아침 9시")
        case .seen: L("봤어요")
        case .openMap: L("지도 열기")
        }
    }

    /// 단추의 그림 — "An interface icon reinforces an action's meaning" (HIG Notifications).
    public var symbol: String {
        switch self {
        case .hourLater: "clock.arrow.circlepath"
        case .tenMinutesLater: "clock"
        case .tomorrowMorning: "sunrise"
        case .seen: "checkmark"
        case .openMap: "map"
        }
    }

    /// 앱을 앞으로 데려와야 하는가. 지도는 다른 앱을 여는 일이라 폰에서는 앞에 있어야 한다.
    public var opensApp: Bool { self == .openMap }
}

/// 알림의 종류 — 단추 묶음이 다르다.
public enum ReminderCategory: String, CaseIterable, Sendable {
    /// 다시 볼 시각.
    case recall
    /// 출발 시각 — 가는 길이 적힌 약속 (`Recall.departureLine`).
    case departure

    public var actions: [ReminderAction] {
        switch self {
        case .recall: [.hourLater, .tomorrowMorning, .seen]
        case .departure: [.tenMinutesLater, .openMap]
        }
    }
}

/// 미루기의 시각 — 배너의 단추와 「다시 보기」 창의 칩이 같은 값을 쓴다.
public enum Snooze {
    public static func tomorrowMorning(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    /// 이 단추가 정하는 시각. 미루는 단추가 아니면 nil.
    public static func date(for action: ReminderAction, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch action {
        case .hourLater: now.addingTimeInterval(3600)
        case .tenMinutesLater: now.addingTimeInterval(600)
        case .tomorrowMorning: tomorrowMorning(now: now, calendar: calendar)
        case .seen, .openMap: nil
        }
    }
}

/// OS 알림 큐의 얇은 문. 실제 앱은 `SystemReminderQueue`, 시험은 가짜가 선다.
@MainActor public protocol ReminderQueue: AnyObject {
    /// 알림을 눌렀다 — 메모 id 문자열.
    var onTap: ((String) -> Void)? { get set }
    /// 「어디서 출발하시나요?」 알림을 눌렀다 — 메모 id 문자열 (`RouteAsk`).
    var onAskRoute: ((String) -> Void)? { get set }
    /// 배너의 단추를 눌렀다 — 단추, 메모 id 문자열, 그 알림이 걸려 있던 시각.
    var onAction: ((ReminderAction, String, Date) -> Void)? { get set }
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
