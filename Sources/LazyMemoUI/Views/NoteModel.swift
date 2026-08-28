import Foundation
import LazyMemoCore
import Observation

/// 메모 창 하나의 상태와 자동 저장 (설계문서 §8).
///
/// **저장 버튼이 없다.** 입력이 멈추면 디바운스 후 저장하고, 창이 닫히거나
/// 앱이 종료될 때 즉시 flush 한다. "생각 → 저장" 조작 수를 2회 이내로 두는
/// 성능 예산(§11)이 이 클래스에 걸려 있다.
@MainActor
@Observable
final class NoteModel {
    private(set) var memo: Memo
    var text: String

    /// 타자가 멈춘 뒤 이만큼 지나면 쓴다. 짧으면 디스크를 두들기고,
    /// 길면 앱이 죽었을 때 잃는 양이 늘어난다.
    private static let autosaveDelay: Duration = .milliseconds(600)

    private let store: MemoStore
    private var saveTask: Task<Void, Never>?
    private var isDirty = false

    init(memo: Memo, store: MemoStore) {
        self.memo = memo
        self.text = memo.body
        self.store = store
    }

    // MARK: 외부 변경 반영

    /// 파일이 밖에서 바뀌었을 때(MCP·텍스트 에디터) 창에 반영한다.
    /// 사용자가 편집 중이면 덮어쓰지 않는다 — 타이핑을 빼앗기는 것보다
    /// 잠시 어긋나 있는 편이 낫다.
    func adopt(_ updated: Memo) {
        memo = updated
        guard !isDirty else { return }
        if text != updated.body { text = updated.body }
    }

    // MARK: 편집

    func edited(_ newText: String) {
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.persistBody()
        }
    }

    /// 창을 닫거나 앱이 꺼질 때. 기다릴 수 없으므로 지금 쓴다.
    func flush() async {
        saveTask?.cancel()
        saveTask = nil
        await persistBody()
    }

    private func persistBody() async {
        guard isDirty, text != memo.body else {
            isDirty = false
            return
        }
        do {
            memo = try await store.update(memo.id, body: text)
            isDirty = false
        } catch {
            // 저장 실패는 조용히 넘어가면 안 된다. 다음 시도에서 다시 쓰도록
            // dirty 를 유지한다.
        }
    }

    // MARK: 속성 변경 — 즉시 반영

    func setColor(_ color: MemoColor) async {
        memo = (try? await store.update(memo.id, color: color)) ?? memo
    }

    func togglePin() async {
        memo = (try? await store.update(memo.id, pinned: !memo.pinned)) ?? memo
    }

    func clearSchedule() async {
        memo = (try? await store.update(memo.id, due: .some(nil), at: .some(nil))) ?? memo
    }

    func delete() async {
        await flush()
        try? await store.delete(memo.id)
    }
}
