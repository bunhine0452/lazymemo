import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoReminders

/// OS 큐의 가짜. 무엇을 걸었고 무엇을 뺐는지 기억하고, 읽는 동안 멈춰 설 수 있다.
@MainActor
final class FakeQueue: ReminderQueue {
    var onTap: ((String) -> Void)?
    var status: ReminderAuthorization = .undecided
    var answer = true
    var requests: [ReminderRequest] = []
    var deliveredIDs: [String] = []
    var added: [String] = []
    var removed: [String] = []
    var removedDelivered: [String] = []
    var failing: Set<String> = []
    var authorizationAsked = 0
    /// `pending()` 이 여기서 멈춘다 — 읽는 동안 저장소가 바뀌는 순간을 만든다.
    var holdPending: CheckedContinuation<Void, Never>?
    var holdsPending = false
    var pendingReads = 0

    func authorization() async -> ReminderAuthorization { status }

    func requestAuthorization() async throws -> Bool {
        authorizationAsked += 1
        if status == .undecided { status = answer ? .allowed : .denied }
        return status == .allowed
    }

    func pending() async -> [ReminderRequest] {
        pendingReads += 1
        if holdsPending {
            await withCheckedContinuation { holdPending = $0 }
        }
        return requests
    }

    func add(_ request: ReminderRequest) async throws {
        if failing.contains(request.id) { throw CocoaError(.fileWriteUnknown) }
        requests.removeAll { $0.id == request.id }
        requests.append(request)
        added.append(request.id)
    }

    func removePending(_ ids: [String]) {
        requests.removeAll { ids.contains($0.id) }
        removed += ids
    }

    func delivered() async -> [String] { deliveredIDs }

    func removeDelivered(_ ids: [String]) {
        deliveredIDs.removeAll { ids.contains($0) }
        removedDelivered += ids
    }

    func release() {
        holdPending?.resume()
        holdPending = nil
    }
}

@MainActor
@Suite("ReminderCenter — 저장소와 OS 큐의 대조")
struct ReminderCenterTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-reminders-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoStore(paths: paths), paths)
    }

    /// 임시 폴더와 `UserDefaults` 도메인이 같은 이름을 쓴다 — 폴더를 지울 때 도메인도
    /// 같이 지우려고. 도메인을 남기면 시험 한 번마다 `~/Library/Preferences` 에
    /// plist 가 하나씩 쌓인다 (실제로 아흔여섯 개가 쌓여 있었다). 도메인을 비워도
    /// cfprefsd 는 빈 plist 를 남기므로, 비운 것을 내려쓰게 한 뒤 파일까지 지운다.
    private func cleanUp(_ paths: AppPaths) {
        let root = paths.vault.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: root)
        let name = root.lastPathComponent
        let defaults = UserDefaults(suiteName: name)
        defaults?.removePersistentDomain(forName: name)
        defaults?.synchronize()
        let plist = URL.libraryDirectory.appending(path: "Preferences/\(name).plist")
        try? FileManager.default.removeItem(at: plist)
    }

    private func defaults(for paths: AppPaths) -> UserDefaults {
        let name = paths.vault.deletingLastPathComponent().lastPathComponent
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func soon(_ minutes: Double) -> Date { Date().addingTimeInterval(minutes * 60) }

    private func make(enabled: Bool = true, status: ReminderAuthorization = .allowed) throws
        -> (ReminderCenter, FakeQueue, MemoStore, AppPaths)
    {
        let (store, paths) = try makeStore()
        let queue = FakeQueue()
        queue.status = status
        let defaults = defaults(for: paths)
        defaults.set(enabled, forKey: "recall.notifications.enabled")
        let center = ReminderCenter(queue: queue, defaults: defaults)
        return (center, queue, store, paths)
    }

    @Test("첫 실행에는 묻지 않는다 — 켜지 않으면 권한을 부르지 않고 아무것도 걸지 않는다")
    func doesNotAskUntilEnabled() async throws {
        let (center, queue, store, paths) = try make(enabled: false, status: .undecided)
        defer { cleanUp(paths) }
        _ = try await store.create(body: "회의", at: soon(30))

        center.start(store: store)
        await center.settle()

        #expect(queue.authorizationAsked == 0)
        #expect(queue.requests.isEmpty)
        #expect(center.enabled == false)
        #expect(center.scheduledCount == 0)
    }

    @Test("켜면 묻고, 허용하면 미래의 시각만 건다")
    func enablingAsksAndSchedules() async throws {
        let (center, queue, store, paths) = try make(enabled: false, status: .undecided)
        defer { cleanUp(paths) }
        let coming = try await store.create(body: "회의", at: soon(30))
        _ = try await store.create(body: "지난 것", at: soon(-30))
        _ = try await store.create(body: "날짜만", due: CalendarDate(Date().addingTimeInterval(86_400)))
        center.start(store: store)
        await center.settle()

        await center.setEnabled(true)
        await center.settle()

        #expect(queue.authorizationAsked == 1)
        #expect(center.enabled)
        #expect(center.authorization == .allowed)
        #expect(queue.requests.map(\.id) == ["recall." + coming.id.stringValue])
        #expect(queue.requests.first?.title == "회의")
        #expect(center.scheduledCount == 1)
        #expect(center.trouble == nil)
    }

    @Test("거절하면 켜 둔 뜻은 남고 걸지는 않는다 — 설정에서 허용하면 다음 대조에서 건다")
    func deniedThenAllowed() async throws {
        let (center, queue, store, paths) = try make(enabled: false, status: .undecided)
        defer { cleanUp(paths) }
        queue.answer = false
        _ = try await store.create(body: "회의", at: soon(30))
        center.start(store: store)
        await center.settle()

        await center.setEnabled(true)
        await center.settle()
        #expect(center.enabled)
        #expect(center.denied)
        #expect(queue.requests.isEmpty)

        // 시스템 설정에서 허용하고 돌아왔다.
        queue.status = .allowed
        center.refresh()
        await center.settle()
        #expect(!center.denied)
        #expect(queue.requests.count == 1)
    }

    @Test("끄면 걸어 둔 것과 알림 센터의 것을 전부 뺀다")
    func disablingClearsEverything() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        queue.deliveredIDs = ["recall." + memo.id.stringValue]
        center.start(store: store)
        await center.settle()
        #expect(queue.requests.count == 1)

        await center.setEnabled(false)
        await center.settle()

        #expect(queue.requests.isEmpty)
        #expect(queue.deliveredIDs.isEmpty)
        #expect(center.scheduledCount == 0)
    }

    @Test("시각을 바꾸면 옛 예약이 빠지고 새 예약이 선다 — 같은 id 로")
    func reschedulesOnChange() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        center.start(store: store)
        await center.settle()
        let id = "recall." + memo.id.stringValue
        let first = queue.requests.first?.date

        _ = try await store.update(memo.id, at: .some(soon(90)))
        await center.settle()

        #expect(queue.requests.map(\.id) == [id])
        #expect(queue.requests.first?.date != first)
        #expect(queue.added.filter { $0 == id }.count == 2)
    }

    @Test("같은 것은 다시 걸지 않는다")
    func leavesIdenticalAlone() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        center.start(store: store)
        await center.settle()
        #expect(queue.added.count == 1)

        _ = try await store.update(memo.id, color: .green)
        await center.settle()
        center.refresh()
        await center.settle()

        #expect(queue.added.count == 1)
        #expect(queue.removed.isEmpty)
    }

    @Test("지우기·치우기·다 체크하기는 예약과 알림 센터에서 뺀다")
    func removesFinished() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let deleted = try await store.create(body: "지울 것", at: soon(30))
        let checked = try await store.create(body: "- [ ] 우유", at: soon(40))
        let kept = try await store.create(body: "남을 것", at: soon(50))
        queue.deliveredIDs = ["recall." + deleted.id.stringValue, "recall." + kept.id.stringValue]
        center.start(store: store)
        await center.settle()
        #expect(queue.requests.count == 3)

        try await store.delete(deleted.id)
        _ = try await store.update(checked.id, body: "- [x] 우유")
        await center.settle()

        #expect(queue.requests.map(\.id) == ["recall." + kept.id.stringValue])
        #expect(queue.deliveredIDs == ["recall." + kept.id.stringValue])
    }

    @Test("다시 보기 해제는 따로 정한 시각만 지우고, 일정 시각에 건다")
    func clearingSurfaceFallsBackToEvent() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(60), surface: soon(20))
        center.start(store: store)
        await center.settle()
        #expect(queue.requests.first?.date == memo.surface)

        _ = try await store.update(memo.id, surface: .some(nil))
        await center.settle()

        #expect(queue.requests.count == 1)
        #expect(queue.requests.first?.date == memo.at)
    }

    @Test("가까운 60개만 걸고 나머지 수를 적는다")
    func limitAndOverflow() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        for minute in 1...65 { _ = try await store.create(body: "일 \(minute)", at: soon(Double(minute))) }
        center.start(store: store)
        await center.settle()

        #expect(queue.requests.count == 60)
        #expect(center.scheduledCount == 60)
        #expect(center.overflow == 5)
        #expect(queue.requests.map(\.title).contains("일 60"))
        #expect(!queue.requests.map(\.title).contains("일 61"))
    }

    @Test("걸지 못한 것은 삼키지 않는다 — 말로 남고, 다시 시도하면 선다")
    func failuresSurfaceAndRetry() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        let id = "recall." + memo.id.stringValue
        queue.failing = [id]
        center.start(store: store)
        await center.settle()
        #expect(center.trouble != nil)
        #expect(center.scheduledCount == 0)

        queue.failing = []
        center.refresh()
        await center.settle()
        #expect(center.trouble == nil)
        #expect(center.scheduledCount == 1)
    }

    @Test("OS 를 읽는 동안 저장소가 바뀌면 낡은 집합을 버리고 다시 센다")
    func staleReadIsDiscarded() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let first = try await store.create(body: "먼저", at: soon(30))
        queue.holdsPending = true
        center.start(store: store)
        // 대조가 pending() 에서 멈춰 있다.
        while queue.holdPending == nil { await Task.yield() }

        // 그 사이 저장소가 바뀐다 — 먼저 것은 지워지고 나중 것이 생긴다.
        try await store.delete(first.id)
        let second = try await store.create(body: "나중", at: soon(40))
        queue.holdsPending = false
        queue.release()
        await center.settle()

        #expect(queue.requests.map(\.id) == ["recall." + second.id.stringValue])
        #expect(!queue.added.contains("recall." + first.id.stringValue))
        #expect(queue.pendingReads >= 2)
    }

    @Test("알림을 누르면 화면이 있으면 바로, 없으면 담아 둔다")
    func tapOpensOrHolds() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))

        queue.onTap?(memo.id.stringValue)
        #expect(center.opened == memo.id)

        var opened: ULID?
        center.onOpen = { opened = $0 }
        center.opened = nil
        queue.onTap?(memo.id.stringValue)
        #expect(opened == memo.id)
        #expect(center.opened == nil)

        queue.onTap?("not-a-ulid")
        #expect(opened == memo.id)
    }
}
