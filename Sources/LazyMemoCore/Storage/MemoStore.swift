import Foundation
import Observation

/// 앱이 데이터를 만지는 출입구 (설계문서 §4).
///
/// 규칙은 `MemoService` 에 있고, 여기는 **화면이 볼 수 있는 상태**를 얹을 뿐이다.
/// MCP 서버는 같은 `MemoService` 를 다른 프로세스에서 쓴다 — 두 경로가 규칙을
/// 따로 구현하지 않게 하기 위한 배치다.
@MainActor
@Observable
public final class MemoStore {
    /// 화면에 보이는 메모. 고정된 것이 먼저, 그 다음 최근 수정 순.
    public private(set) var memos: [Memo] = []
    /// 최근 삭제 (D6 의 되돌리기 동선).
    public private(set) var trash: [Memo] = []
    /// 마지막으로 실패한 작업의 설명. 조용히 삼키지 않는다.
    public private(set) var lastError: String?

    private let paths: AppPaths
    private let service: MemoService
    private var watcher: VaultWatcher?

    public init(paths: AppPaths) throws {
        self.paths = paths
        self.service = try MemoService(paths: paths)
    }

    // MARK: 생명주기

    /// 기동 시 한 번. 파일을 정본으로 삼아 인덱스를 맞추고 감시를 시작한다.
    public func start() async {
        await reconcile()
        await purgeExpiredTrash()
        startWatching()
    }

    public func stop() {
        watcher?.stop()
        watcher = nil
    }

    private func startWatching() {
        guard watcher == nil else { return }
        let watcher = VaultWatcher(directories: [paths.notes, paths.trash]) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reconcile()
            }
        }
        watcher.start()
        self.watcher = watcher
    }

    // MARK: 조회

    public func memo(_ id: ULID) -> Memo? {
        memos.first { $0.id == id }
    }

    public func search(_ query: String, limit: Int = 50) async -> [Memo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return memos }
        do {
            return try await service.search(trimmed, limit: limit)
        } catch {
            report(error, while: "검색")
            return memos.filter { $0.body.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    /// 캘린더 범위 조회 (설계문서 §10).
    public func scheduled(from: CalendarDate, to: CalendarDate) async -> [Memo] {
        do {
            return try await service.scheduled(from: from, to: to)
        } catch {
            report(error, while: "일정 조회")
            return memos.filter {
                guard let date = $0.scheduledDate() else { return false }
                return date >= from && date <= to
            }
        }
    }

    // MARK: 변경

    @discardableResult
    public func create(
        body: String = "",
        due: CalendarDate? = nil,
        at: Date? = nil,
        tags: [String] = [],
        color: MemoColor = .default
    ) async throws -> Memo {
        let memo = try await service.create(body: body, due: due, at: at, tags: tags, color: color)
        insertOrReplace(memo)
        return memo
    }

    @discardableResult
    public func update(
        _ id: ULID,
        body: String? = nil,
        due: CalendarDate?? = nil,
        at: Date?? = nil,
        tags: [String]? = nil,
        color: MemoColor? = nil,
        pinned: Bool? = nil
    ) async throws -> Memo {
        let memo = try await service.update(
            id, body: body, due: due, at: at, tags: tags, color: color, pinned: pinned
        )
        insertOrReplace(memo)
        return memo
    }

    /// 삭제는 휴지통 이동뿐이다 (D6).
    public func delete(_ id: ULID) async throws {
        let removed = try await service.delete(id)
        memos.removeAll { $0.id == id }
        trash.insert(removed, at: 0)
    }

    public func restore(_ id: ULID) async throws {
        let restored = try await service.restore(id)
        trash.removeAll { $0.id == id }
        insertOrReplace(restored)
    }

    // MARK: 파일 ↔ 메모리 동기화

    /// 기동 시와 외부 변경(MCP·텍스트 에디터) 감지 시 모두 이 경로를 탄다.
    public func reconcile() async {
        do {
            memos = try await service.reconcile()
            trash = (try? await service.trashed()) ?? []
            lastError = nil
        } catch {
            report(error, while: "메모 읽기")
        }
    }

    private func purgeExpiredTrash() async {
        do {
            let purged = try await service.purgeExpiredTrash()
            if !purged.isEmpty {
                trash.removeAll { purged.contains($0.id) }
            }
        } catch {
            report(error, while: "휴지통 정리")
        }
    }

    // MARK: 내부

    private func insertOrReplace(_ memo: Memo) {
        var updated = memos.filter { $0.id != memo.id }
        updated.append(memo)
        memos = MemoService.sorted(updated)
    }

    private func report(_ error: Error, while action: String) {
        lastError = "\(action) 실패: \(error)"
    }
}
