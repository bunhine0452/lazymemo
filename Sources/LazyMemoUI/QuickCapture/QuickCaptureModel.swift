import Foundation
import LazyMemoCore
import Observation

/// 빠른 입력 상자의 상태 (설계문서 §8).
///
/// 한 상자가 **입력과 검색을 겸한다.** 치면 기존 메모가 걸러지고, 그대로
/// Return 을 누르면 새 메모가 된다. 모드 전환이 없어야 조작 수가 줄어든다.
@MainActor
@Observable
final class QuickCaptureModel {
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var matches: [Memo] = []
    /// 화살표로 고른 항목. `nil` 이면 Return 이 새 메모를 만든다.
    var selection: Int?

    private let store: MemoStore
    private var searchTask: Task<Void, Never>?

    /// 타자마다 인덱스를 때리지 않는다. 사람이 한 글자 더 치는 시간보다 짧게 둔다.
    private static let searchDelay: Duration = .milliseconds(120)
    private static let matchLimit = 6

    init(store: MemoStore) {
        self.store = store
    }

    func reset() {
        searchTask?.cancel()
        query = ""
        matches = []
        selection = nil
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            matches = []
            selection = nil
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled, let self else { return }
            let found = await self.store.search(text, limit: Self.matchLimit)
            guard !Task.isCancelled else { return }
            self.matches = found
            // 검색 결과가 줄어들면 선택이 범위를 벗어난다.
            if let selection = self.selection, selection >= found.count {
                self.selection = found.isEmpty ? nil : found.count - 1
            }
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

    /// Return 의 의미. 고른 게 있으면 그 메모, 없으면 새 메모.
    enum Commit {
        case open(ULID)
        case create(String)
        case nothing
    }

    func commit() -> Commit {
        if let selection, matches.indices.contains(selection) {
            return .open(matches[selection].id)
        }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .nothing : .create(query)
    }
}
