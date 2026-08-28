import Foundation
import LazyMemoCore
import Observation

/// 빠른 입력 상자의 상태 (설계문서 §8).
///
/// 한 상자가 **입력과 검색과 일정 인식을 겸한다.** 치면 기존 메모가 걸러지고,
/// 날짜 표현이 보이면 칩으로 떠오르며, 그대로 Return 을 누르면 새 메모가 된다.
/// 모드 전환이 없어야 조작 수가 줄어든다.
@MainActor
@Observable
final class QuickCaptureModel {
    var query: String = "" {
        didSet {
            // 날짜 인식은 로컬 문자열 처리라 즉시 한다. 타자마다 칩이 따라와야
            // 사용자가 "아, 얘가 읽고 있구나" 를 알 수 있다.
            schedule = KoreanDateParser.parse(query)
            scheduleSearch()
        }
    }

    private(set) var matches: [Memo] = []
    /// 입력에서 알아낸 일정. 없으면 그냥 메모다.
    private(set) var schedule: KoreanDateParser.Result?
    /// 화살표로 고른 항목. `nil` 이면 Return 이 새 메모를 만든다.
    var selection: Int?

    /// 결과 수가 바뀌면 창 높이를 다시 잡아야 한다.
    var onLayoutChange: () -> Void = {}

    private let store: MemoStore
    private var searchTask: Task<Void, Never>?

    /// 타자마다 인덱스를 때리지 않는다. 사람이 한 글자 더 치는 시간보다 짧게 둔다.
    private static let searchDelay: Duration = .milliseconds(120)
    private static let matchLimit = 5

    init(store: MemoStore) {
        self.store = store
    }

    func reset() {
        searchTask?.cancel()
        query = ""
        matches = []
        schedule = nil
        selection = nil
    }

    /// 칩에 보여줄 글. 인식한 원문이 아니라 **해석한 결과**를 보인다 —
    /// "내일" 이라고 되쓰면 제대로 읽었는지 확인할 수 없다.
    var scheduleLabel: String? {
        guard let schedule else { return nil }
        if let at = schedule.at {
            return at.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
        }
        if let due = schedule.due, let start = due.startOfDay() {
            return start.formatted(.dateTime.month().day().weekday(.abbreviated))
        }
        return nil
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            matches = []
            selection = nil
            onLayoutChange()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled, let self else { return }
            let found = await self.store.search(text, limit: Self.matchLimit)
            guard !Task.isCancelled else { return }
            self.matches = found
            if let selection = self.selection, selection >= found.count {
                self.selection = found.isEmpty ? nil : found.count - 1
            }
            self.onLayoutChange()
        }
    }

    // MARK: 키보드 이동

    func moveSelection(_ delta: Int) {
        guard !matches.isEmpty else { return }
        switch selection {
        case nil:
            selection = delta > 0 ? 0 : matches.count - 1
        case let current?:
            let next = current + delta
            // 위로 벗어나면 "선택 없음"(= 새 메모)으로 되돌아간다.
            selection = (next < 0 || next >= matches.count) ? nil : next
        }
    }

    // MARK: 확정

    struct Draft {
        let text: String
        let due: CalendarDate?
        let at: Date?
    }

    enum Commit {
        case open(ULID)
        case create(Draft)
        case nothing
    }

    func commit() -> Commit {
        if let selection, matches.indices.contains(selection) {
            return .open(matches[selection].id)
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .nothing }

        guard let schedule else {
            return .create(Draft(text: text, due: nil, at: nil))
        }
        return .create(Draft(
            text: KoreanDateParser.strip(schedule.phrases, from: text),
            due: schedule.due,
            at: schedule.at
        ))
    }
}
