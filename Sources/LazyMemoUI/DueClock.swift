import Foundation
import LazyMemoCore
import Observation

/// 적힌 시각이 오면 알리는 시계 (`DayClock` 의 짝).
///
/// **보는 값은 `Memo.surfacesAt` 하나다.** 「일정 시각에 나온다」와 「따로 정한
/// 시각에 나온다」(`surface`)를 두 갈래로 두면 한쪽만 고쳐지는 날이 온다 —
/// 자다 깬 기계, 하루가 바뀐 순간, 앱을 늦게 켠 저녁이 전부 두 번씩 있게 된다.
///
/// **§7.2 는 지키지 못한 약속을 하나 하고 있었다** — "언제 볼지 이미 정해졌다.
/// 그 날이 오면 달력이 꺼내 준다." 꺼내 주는 쪽이 없었다. `at` 이 적힌 메모가
/// 그 시각에 하는 일이 아무것도 없었고, 그러면 "적었는데 그냥 지나갔다" 가
/// 남는다. 그것이 한 번 반복되면 사용자는 중요한 것을 이 앱에 맡기지 않는다.
///
/// ## 첫 실행에 알림 권한을 요구하지 않는다
///
/// 시스템 알림 배너를 기본으로 쓰면 첫 실행에서 사용자를 시스템 설정으로 보내야
/// 하고, 그것은 §8 의 원칙("설정으로 보내지 않는다")을 깬다. 그래서 기본은 이미
/// 있는 것을 쓴다 — **종이가 바탕화면으로 나온다.** 재질도 같고 배울 것도 없다.
/// 시스템 알림은 사용자가 이 기기에서 「알림 받기」를 켰을 때만 **더해진다**
/// (`ReminderCenter`) — 같은 `surfacesAt` 을 보므로 종이와 배너가 같은 순간에 온다.
///
/// ## 잠깐 떠올랐다 사라지지 않는다
///
/// 그 시각에 자리를 비운 사람이 바로 이 기능이 구하려는 사람이다. 1.6초 뒤
/// 내려앉으면 그 사람에게는 아무 일도 일어나지 않은 것과 같다. 그래서 종이는
/// 나와서 **그대로 있고**, 하루가 끝나면 스스로 물러난다
/// (`NoteWindowManager.clearSurfaced`). 놓친 것을 따로 모아 두는 목록을 만들지
/// 않은 이유가 이것이다 — 놓친 것이 곧 화면에 놓인 종이다.
@MainActor
final class DueClock {
    /// 이 메모의 시각이 왔다.
    var onDue: (ULID) -> Void = { _ in }

    /// 앱을 켰을 때 오늘 이미 지나간 일정을 몇 장까지 꺼내 볼지.
    ///
    /// 저녁에 컴퓨터를 열었다고 하루치 일정이 통째로 바탕화면을 덮으면, 그건
    /// 알림이 아니라 치울 거리다. 가장 가까운 것부터 몇 장만 꺼낸다.
    private static let catchUpLimit = 3

    private let store: MemoStore
    private let now: () -> Date
    private let calendar: Calendar
    private var task: Task<Void, Never>?
    /// 이미 꺼내 준 것 — **어느 시각으로** 꺼냈는지까지. 같은 일정을 두 번 꺼내지 않는다.
    ///
    /// id 만 기억하면 같은 날 다시 볼 시각을 미룬 종이가 영영 안 나온다 — 시스템
    /// 배너(`ReminderCenter`)는 새 시각에 다시 울리는데 종이는 조용한 날이 온다.
    /// 시각이 바뀌면 다른 약속이다.
    private var announced: [ULID: Date] = [:]

    init(store: MemoStore, now: @escaping () -> Date = { Date() }, calendar: Calendar = .current) {
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    func start() {
        catchUpOnToday()
        observeStore()
        arm()
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// 하루가 바뀌었다 (`DayClock`). 어제 꺼낸 것은 잊고 오늘로 다시 센다.
    func dayChanged() {
        announced.removeAll()
        arm()
    }

    // MARK: 안쪽

    /// 일정은 메모의 필드다 (§10). 메모가 바뀌면 다음에 울릴 시각도 바뀐다 —
    /// 새로 적었거나, 미뤘거나, 날짜를 뗐거나.
    private func observeStore() {
        withObservationTracking {
            _ = store.memos
        } onChange: {
            Task { @MainActor [weak self] in
                self?.arm()
                self?.observeStore()
            }
        }
    }

    /// 앱이 꺼져 있는 동안 지나간 **오늘의** 일정을 꺼내 놓는다.
    ///
    /// 어제 것까지 꺼내지 않는다. 지난 일정을 언제까지 눈앞에 세워 둘지는
    /// 「미루기」와 「종이로」가 정할 일이고(§7.3), 시계가 할 일이 아니다.
    private func catchUpOnToday() {
        let moment = now()
        let today = CalendarDate(moment, calendar: calendar)
        let passed = store.memos
            .filter { memo in
                guard let at = memo.surfacesAt, at <= moment else { return false }
                return CalendarDate(at, calendar: calendar) == today
            }
            .sorted { ($0.surfacesAt ?? .distantPast) > ($1.surfacesAt ?? .distantPast) }

        // 지나간 것은 전부 "알린 것" 으로 친다 — 꺼내지 않은 것까지 포함해서.
        // 안 그러면 잠시 뒤 `arm` 이 그것들을 다시 지금 울릴 것으로 읽는다.
        for memo in passed { announced[memo.id] = memo.surfacesAt }
        for memo in passed.prefix(Self.catchUpLimit).reversed() { onDue(memo.id) }
    }

    /// 다음에 울릴 시각까지 잔다.
    private func arm() {
        task?.cancel()
        let moment = now()
        guard let next = upcoming(after: moment), let at = next.surfacesAt else { return }

        let seconds = max(at.timeIntervalSince(moment), 0)
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.fire()
        }
    }

    /// 시각이 지난 것을 전부 꺼내고 다시 잔다.
    ///
    /// 하나만 보지 않는 이유: 같은 분에 둘이 걸려 있을 수 있고, 기계가 자다
    /// 깨면 여러 개가 한꺼번에 지나 있다.
    func fire() {
        let moment = now()
        let due = store.memos
            .filter { memo in
                guard let at = memo.surfacesAt, !isAnnounced(memo) else { return false }
                return at <= moment
            }
            .sorted { ($0.surfacesAt ?? .distantPast) < ($1.surfacesAt ?? .distantPast) }

        for memo in due {
            announced[memo.id] = memo.surfacesAt
            onDue(memo.id)
        }
        arm()
    }

    /// 아직 안 울린 것 중 가장 가까운 것.
    private func upcoming(after moment: Date) -> Memo? {
        store.memos
            .filter { memo in
                guard let at = memo.surfacesAt, !isAnnounced(memo) else { return false }
                return at > moment
            }
            .min { ($0.surfacesAt ?? .distantFuture) < ($1.surfacesAt ?? .distantFuture) }
    }

    /// 이 메모를 **지금 적힌 시각으로** 이미 꺼냈는가. 시각을 미뤘으면 아니다.
    private func isAnnounced(_ memo: Memo) -> Bool {
        announced[memo.id] == memo.surfacesAt
    }
}
