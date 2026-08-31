import AppKit
import Foundation
import LazyMemoCore

/// 앱이 시간을 아는 유일한 자리.
///
/// **v1 에는 이것이 없었다.** `Sources` 전체에 타이머가 하나도 없었고, 그래서
/// 바탕화면에 상주하면서도 시간에 따라 스스로 하는 일이 하나도 없었다. 결과는
/// 조용한 거짓말 여럿이다.
///
/// - 자정이 지나도 달력의 손그림 동그라미가 **어제 칸**에 남는다. 「오늘」
///   버튼도 어제로 간다.
/// - 「미루기」가 어제를 기준으로 세어 **오늘로 미룬다** — 달력에서 가장 자주
///   쓰는 동사가 조용히 하루 어긋나 있었다 (`Schedule.postponed(notBefore:)`).
/// - 어제 손댄 메모가 계속 `fresh` 로 남아 바래지 않는다 (`MemoAge`).
/// - 휴지통의 30일이 영영 안 온다. 정리가 기동 시 한 번뿐이라, 안 끄면 무한 보존이다.
///
/// **깨우는 길을 둘 둔다.** 시스템의 `NSCalendarDayChanged` 는 잠자기와 시각
/// 변경까지 알아서 다뤄 주지만, 그 하나에만 기대지 않는다. 우리가 잰 다음
/// 자정까지의 잠도 나란히 두어 어느 한쪽이 안 와도 하루는 넘어간다. 두 번
/// 깨어도 해가 없다 — **날짜가 실제로 바뀌었을 때만** 일하기 때문이다.
///
/// 잠은 `Task.sleep` 이므로 `ContinuousClock` 을 탄다. 기계가 자는 동안에도
/// 시간이 흐르는 시계라, 뚜껑을 열면 밀린 자정이 곧바로 온다.
@MainActor
final class DayClock {
    /// 하루가 바뀌었다. **여러 번 불려도 안전해야 한다.**
    var onNewDay: (CalendarDate) -> Void = { _ in }

    private(set) var today: CalendarDate

    private let now: () -> Date
    private let calendar: Calendar
    private var task: Task<Void, Never>?
    private var observer: (any NSObjectProtocol)?

    /// - Parameter now: 지금 몇 시인지 묻는 곳. 시험이 시계를 손으로 돌린다.
    init(now: @escaping () -> Date = { Date() }, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
        self.today = CalendarDate(now(), calendar: calendar)
    }

    func start() {
        guard task == nil, observer == nil else { return }

        // 시스템이 알려 주는 길. 잠자기·시각 변경·타임존 변경을 포함한다.
        observer = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }

        // 우리가 재는 길. 알림이 안 와도 하루는 넘어가야 한다.
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let seconds = self.secondsUntilMidnight()
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// 지금 날짜를 보고, 어제와 다르면 알린다.
    ///
    /// 두 길이 같은 자정에 함께 도착할 수 있으므로 **한 번만 일한다.**
    func tick() {
        let current = CalendarDate(now(), calendar: calendar)
        guard current != today else { return }
        today = current
        onNewDay(current)
    }

    /// 다음 자정까지 몇 초인가. 최소 1초를 둔다 — 0을 주면 자정 언저리에서
    /// 잠들지 않는 고리가 된다.
    private func secondsUntilMidnight() -> Double {
        let reference = now()
        guard let midnight = CalendarDate.nextMidnight(after: reference, calendar: calendar)
        else { return 60 * 60 }
        return max(midnight.timeIntervalSince(reference), 1)
    }
}
