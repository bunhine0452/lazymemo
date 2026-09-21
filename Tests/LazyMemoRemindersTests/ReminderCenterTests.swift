import Foundation
import LazyMemoCore
import LazyMemoWidgetsCore
import Testing
@testable import LazyMemoReminders

/// OS 큐의 가짜. 무엇을 걸었고 무엇을 뺐는지 기억하고, 읽는 동안 멈춰 설 수 있다.
@MainActor
final class FakeQueue: ReminderQueue {
    var onTap: ((String) -> Void)?
    var onAskRoute: ((String) -> Void)?
    var onAction: ((ReminderAction, String, Date) -> Void)?
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

    // MARK: 배너의 단추

    @Test("가는 길이 적힌 약속은 출발 알림이고, 나머지는 다시 보기 알림이다 — 단추가 다르다")
    func categoryFollowsDepartureLine() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let at = soon(90)
        let plain = try await store.create(body: "회의", at: at)
        let hour = Calendar.current.component(.hour, from: at), minute = Calendar.current.component(.minute, from: at)
        let clock = String(format: "%02d:%02d", hour, minute)
        let routed = try await store.create(
            body: "밥약속\n\n## 가는 길\n강남역 → 잠실 · 14분 · \(clock) 출발 · \(clock) 도착 · 1,550원\n- 지하철 2호선 강남역 → 잠실새내역 · 9분 · 5정거장 · 외선순환 방면 · \(clock) 승차\n",
            at: at
        )
        #expect(Recall.departureLine(routed) != nil)
        center.start(store: store)
        await center.settle()

        let byID = Dictionary(uniqueKeysWithValues: queue.requests.map { ($0.id, $0) })
        #expect(byID["recall." + plain.id.stringValue]?.category == .recall)
        #expect(byID["recall." + routed.id.stringValue]?.category == .departure)
        #expect(ReminderCategory.recall.actions == [.hourLater, .tomorrowMorning, .seen])
        #expect(ReminderCategory.departure.actions == [.tenMinutesLater, .openMap])
    }

    @Test("「한 시간 뒤」는 다시 볼 시각을 파일에 적고 예약을 그 시각으로 옮긴다")
    func snoozeMovesSurface() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        center.start(store: store)
        await center.settle()

        let pressed = Date()
        queue.onAction?(.hourLater, memo.id.stringValue, soon(30))
        await center.settle()
        // `apply` 의 Task 가 저장소를 고친 뒤 refresh 를 부른다 — 그것까지 기다린다.
        for _ in 0..<50 where store.memo(memo.id)?.surface == nil { await Task.yield() }
        await center.settle()

        let surface = try #require(store.memo(memo.id)?.surface)
        #expect(abs(surface.timeIntervalSince(pressed.addingTimeInterval(3600))) < 5)
        let request = try #require(queue.requests.first { $0.id == "recall." + memo.id.stringValue })
        #expect(abs(request.date.timeIntervalSince(surface)) < 1)
    }

    @Test("저장소가 붙기 전에 누른 「내일 아침」은 누른 시각 기준으로 담아 두었다가 붙는 순간 적용한다")
    func snoozeBeforeStoreIsKeptWithItsTime() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))

        queue.onAction?(.tomorrowMorning, memo.id.stringValue, soon(30))
        #expect(store.memo(memo.id)?.surface == nil)
        let expected = Snooze.tomorrowMorning()

        center.start(store: store)
        for _ in 0..<50 where store.memo(memo.id)?.surface == nil { await Task.yield() }
        await center.settle()
        #expect(store.memo(memo.id)?.surface == expected)
    }

    @Test("「봤어요」는 이 기기의 기억에 그 등장의 이름표를 적고 화면의 손을 부른다")
    func seenMarksNowSeen() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        // 배너가 들고 있는 시각은 걸 때의 `surfacesAt` 그대로다 (`SystemReminderQueue` 의 userInfo).
        let fired = try #require(memo.surfacesAt)
        var lowered: ULID?
        center.onSeen = { lowered = $0 }
        defer { NowSeen.save([:]) }

        queue.onAction?(.seen, memo.id.stringValue, fired)

        #expect(lowered == memo.id)
        let stamp = try #require(NowSeen.load()[memo.id])
        #expect(abs(stamp.timeIntervalSince(fired)) < 1)
        // 띠가 그 카드를 내려놓는 값과 같다 — 시각이 있는 카드의 이름표는 그 시각이다.
        let cards = Recall.nowCards(store.memos, now: Date(), seen: NowSeen.load())
        #expect(!cards.contains { $0.id == memo.id })
    }

    @Test("「지도 열기」는 화면의 손이 설 때까지 기다린다")
    func openMapWaitsForScreen() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "밥약속", at: soon(30))

        queue.onAction?(.openMap, memo.id.stringValue, soon(30))
        var opened: ULID?
        center.onOpenMap = { opened = $0 }
        #expect(opened == memo.id)

        // 손이 서 있으면 바로.
        opened = nil
        queue.onAction?(.openMap, memo.id.stringValue, soon(30))
        #expect(opened == memo.id)
    }

    // MARK: 영수증 — 저장 직후 화면이 적는 「이 기기에서 확인한 사실」

    @Test("영수증은 이 기기에서 확인한 사실만 말한다 — 예약됨·시각 없음·꺼짐·거절·실패·한도 밖")
    func receiptTellsOnlyWhatThisDeviceConfirmed() async throws {
        let (center, queue, store, paths) = try make()
        defer { cleanUp(paths) }
        let timed = try await store.create(body: "견적 보내기", at: soon(30))
        let dateOnly = try await store.create(body: "날짜만", due: CalendarDate(Date().addingTimeInterval(86_400)))
        let plain = try await store.create(body: "그냥 글")
        let passed = try await store.create(body: "지난 것", at: soon(-30))
        let finished = try await store.create(body: "- [x] 우유", at: soon(40))

        // 대조가 돌기 전에는 「확인 중」이다 — 앞 메모의 결과를 새 메모에 붙이지 않는다.
        #expect(center.receipt(for: timed) == .pending)
        center.start(store: store)
        await center.settle()

        #expect(center.receipt(for: timed) == .scheduled(timed.at!))
        #expect(center.receipt(for: timed).line() != nil)
        #expect(center.receipt(for: dateOnly) == .dateOnly)
        #expect(center.receipt(for: dateOnly).line() != nil, "날짜만 있으면 알림이 없다는 것을 말해 준다")
        #expect(center.receipt(for: dateOnly).mark == nil)
        #expect(center.receipt(for: plain) == .noTime)
        #expect(center.receipt(for: plain).line() == nil, "그냥 글에는 알림 이야기를 꺼내지 않는다")
        #expect(center.receipt(for: passed) == .passed)
        #expect(center.receipt(for: finished) == .notWanted)

        // 새로 적은 메모 — 대조가 다시 돌기 전까지는 「확인 중」, 돈 뒤에 「예약됨」.
        let fresh = try await store.create(body: "새 약속", at: soon(60))
        let before = center.receipt(for: fresh)
        #expect(before == .pending || before == .scheduled(fresh.at!))
        await center.settle()
        #expect(center.receipt(for: fresh) == .scheduled(fresh.at!))

        // OS 가 받지 않았다.
        let broken = try await store.create(body: "안 걸리는 것", at: soon(90))
        queue.failing = ["recall." + broken.id.stringValue]
        center.refresh()
        await center.settle()
        #expect(center.receipt(for: broken) == .failed)
        #expect(center.receipt(for: fresh) == .scheduled(fresh.at!), "하나가 실패해도 나머지는 그대로 예약됨")

        // 꺼져 있으면 꺼짐 — 예약이 있었어도.
        await center.setEnabled(false)
        await center.settle()
        #expect(center.receipt(for: fresh) == .off)
    }

    @Test("권한이 거절돼 있으면 영수증은 「권한 없음」이고, 한도 밖은 「대기」다")
    func receiptDeniedAndOverflow() async throws {
        let (center, queue, store, paths) = try make(status: .denied)
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "회의", at: soon(30))
        center.start(store: store)
        await center.settle()
        #expect(center.receipt(for: memo) == .denied)

        queue.status = .allowed
        var last: Memo?
        for minute in 1...(Recall.reservationLimit + 1) {
            last = try await store.create(body: "약속 \(minute)", at: soon(Double(minute + 60)))
        }
        center.refresh()
        await center.settle()
        #expect(center.receipt(for: memo) == .scheduled(memo.at!))
        #expect(center.receipt(for: last!) == .overflow)
        #expect(center.receipt(for: last!).mark == "알림 대기")
    }

    @Test("설치된 앱 밖에서는 「설치된 앱에서만」이다")
    func receiptWithoutQueue() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let center = ReminderCenter(queue: nil, defaults: defaults(for: paths))
        let memo = try await store.create(body: "회의", at: soon(30))
        center.start(store: store)
        await center.settle()
        #expect(center.receipt(for: memo) == .unavailable)
    }

    @Test("앱 밖이 거는 알림과 이름·종류가 같다 — 공유 시트가 건 것을 대조가 자기 것으로 알아본다")
    func externalWritersShareTheNames() {
        #expect(ReminderCenter.prefix == Recall.notificationPrefix)
        #expect(ReminderCategory.recall.rawValue == Recall.recallCategory)
        #expect(ReminderCategory.departure.rawValue == Recall.departureCategory)
    }

    @Test("켜고 끄면 앱 그룹의 표가 따라간다 — 공유 시트가 읽는 것")
    func togglingWritesTheGroupMarker() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let group = paths.vault.deletingLastPathComponent().appending(path: "group", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        let queue = FakeQueue()
        queue.status = .allowed
        let center = ReminderCenter(queue: queue, defaults: defaults(for: paths), group: group)
        center.start(store: store)
        #expect(RecallSwitch.isEnabled(in: group) == false)

        await center.setEnabled(true)
        #expect(RecallSwitch.isEnabled(in: group) == true)
        await center.setEnabled(false)
        #expect(RecallSwitch.isEnabled(in: group) == false)
        #expect(RecallSwitch.isEnabled(in: nil) == nil, "폴더를 모르면 꺼짐이 아니라 모름이다")
    }

    @Test("미루기의 시각 — 배너와 창이 같은 값을 쓴다")
    func snoozePresets() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(Snooze.date(for: .hourLater, now: now) == now.addingTimeInterval(3600))
        #expect(Snooze.date(for: .tenMinutesLater, now: now) == now.addingTimeInterval(600))
        let morning = try? #require(Snooze.date(for: .tomorrowMorning, now: now))
        if let morning {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: morning)
            #expect(parts.hour == 9 && parts.minute == 0)
            #expect(morning > now && morning.timeIntervalSince(now) <= 33 * 3600)
        }
        #expect(Snooze.date(for: .seen, now: now) == nil)
        #expect(Snooze.date(for: .openMap, now: now) == nil)
    }
}
