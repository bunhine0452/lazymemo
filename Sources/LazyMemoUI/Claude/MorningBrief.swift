import Foundation
import LazyMemoCore

/// 아침마다 Claude 가 종이 한 장을 놓는다 (`{#claude-morning-brief}`).
///
/// 토의가 「`{#opt-agent-surface}` 의 완성형」이라고 적은 것이다 — 사용자가
/// 아무것도 하지 않아도 매일 앱이 정리를 대신 해 준다 (§1 의 약속 ②).
///
/// ## 기본은 꺼져 있다
///
/// 이 앱에서 **사용자가 누르지 않았는데 토큰을 쓰는 유일한 기능**이다. 링크
/// 카드나 업데이트 확인이 네트워크를 쓰는 것과는 무게가 다르다 — 그쪽은 주소
/// 하나가 나가지만 여기는 **메모 본문이 나가고 값이 든다.** 그래서 §9.3 의
/// 조건 셋(끌 수 있다·나가는 것이 적다·켜진 것이 보인다)으로는 모자라고,
/// **켜는 것을 사람이 직접 해야 한다**로 한 단계 더 잠근다.
///
/// ## 종이는 한 장이다
///
/// 매일 새 메모를 만들면 한 달에 서른 장이 쌓이고, 그건 정리가 아니라 치울
/// 거리다. 같은 종이를 다시 쓴다 — 「오늘의 브리핑」은 기록이 아니라 오늘의 것이다.
@MainActor
final class MorningBrief {
    private let store: MemoStore
    private let settings: SettingsStore
    private let windows: NoteWindowManager
    private let now: () -> Date
    private var task: Task<Void, Never>?

    init(
        store: MemoStore,
        settings: SettingsStore,
        windows: NoteWindowManager,
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.settings = settings
        self.windows = windows
        self.now = now
    }

    var isEnabled: Bool { settings.current.morningBrief ?? false }

    func setEnabled(_ enabled: Bool) {
        settings.update { $0.morningBrief = enabled }
        enabled ? start() : stop()
    }

    func start() {
        stop()
        guard isEnabled else { return }
        guard let next = BriefClock.next(after: now()) else { return }

        task = Task { [weak self] in
            let seconds = max(next.timeIntervalSince(self?.now() ?? Date()), 0)
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await self?.write()
            // 다음 아침을 다시 건다. 이 앱은 몇 주씩 안 꺼진다.
            self?.start()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// 오늘의 종이를 짓거나 다시 쓴다.
    func write() async {
        guard isEnabled, let claude = windows.claude else { return }

        let today = CalendarDate(now())
        let scheduled = await store.scheduled(from: today, to: today)
        let loose = store.active.filter { !$0.isScheduled }.prefix(Self.looseLimit)
        let material = (scheduled + loose).map(Self.line).joined(separator: "\n")
        guard !material.isEmpty else { return }

        guard let answer = try? await claude.ask(ClaudePrompts.morningBrief, about: material),
              !answer.isEmpty
        else { return }

        await place(answer)
    }

    /// 훑어 보내는 날짜 없는 메모의 수. 전부 보내면 값도 시간도 는다.
    private static let looseLimit = 20

    private static func line(_ memo: Memo) -> String {
        let when = memo.at.map { "\($0.formatted(.dateTime.hour().minute())) " } ?? ""
        let place = memo.place.map { " (\($0))" } ?? ""
        return "- \(when)\(memo.title)\(place)"
    }

    /// 같은 종이를 다시 쓴다. 없어졌으면(사람이 지웠으면) 새로 짓는다.
    private func place(_ body: String) async {
        let text = "## 오늘\n\n" + body

        if let raw = settings.current.briefMemoID, let id = ULID(raw),
           let existing = try? await store.update(id, body: text) {
            windows.announce(existing)
            return
        }

        guard let memo = try? await store.create(body: text) else { return }
        settings.update { $0.briefMemoID = memo.id.stringValue }
        windows.announce(memo)
    }
}
