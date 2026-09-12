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

    /// 마지막으로 실패한 일. 조용히 삼키지 않는다.
    ///
    /// **이 값은 화면까지 나가야 뜻이 있다.** 한동안 여기 적히기만 하고 읽는
    /// 곳이 없었는데, 저장 버튼이 없는 앱에서 그것은 곧 "저장이 안 되고 있어도
    /// 사용자는 영영 모른다" 는 뜻이다. 지금은 메뉴 첫머리가 읽는다.
    public private(set) var trouble: Trouble?

    /// 조용히 지나가면 안 되는 실패 하나.
    public struct Trouble: Sendable, Equatable {
        /// 무엇을 하다 그랬는지 — **사람의 말로.** 메뉴에 그대로 적힌다.
        public let doing: String
        /// 기계의 말. 메뉴에는 안 적고 도움말로만 보인다 — 종이 위에
        /// Swift 오류 문자열이 떠 있으면 그건 이 앱의 화면이 아니다.
        public let detail: String

        public init(doing: String, detail: String) {
            self.doing = doing
            self.detail = detail
        }
    }

    private let paths: AppPaths
    private let service: MemoService
    private var watcher: VaultWatcher?

    public init(paths: AppPaths) throws {
        self.paths = paths
        self.service = try MemoService(paths: paths)
    }

    /// 사진 같은 첨부가 사는 곳. 메모 파일과 같은 Vault 안이다 (D4).
    public var attachments: AttachmentStore { AttachmentStore(paths: paths) }

    // MARK: 생명주기

    /// 기동 시 한 번. 파일을 정본으로 삼아 인덱스를 맞추고 감시를 시작한다.
    public func start() async {
        await reconcile()
        await tidy()
        startWatching()
    }

    /// 시간이 지나야 할 수 있는 정리.
    ///
    /// **기동 시 한 번만 하던 것을 하루 단위로 옮겼다** (`DayClock`). 이 앱은
    /// 바탕화면에 상주하므로 몇 주씩 안 꺼진다 — 그동안 "30일 보존" 은 사실상
    /// 무한 보존이었고, 고아가 된 첨부는 아무도 치우지 않았다.
    public func tidy(now: Date = Date()) async {
        await purgeExpiredTrash()
        await sweepFinished(now: now)
        sweepAttachments(now: now)
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

    /// 지금 눈에 보여야 하는 것 — **치워 둔 것을 뺀 목록** (`Tidy`).
    ///
    /// 바탕화면·메뉴 목록·빠른 입력의 「요즘 메모」가 전부 이것을 본다.
    /// `memos` 를 그대로 두는 이유는 달력과 검색 때문이다 — 지난 일정은
    /// 달력에 그대로 있어야 하고, 치웠다고 못 찾게 되면 그건 삭제다.
    public var active: [Memo] { memos.filter { $0.tidied == nil } }

    /// 스스로 물러난 것. 메뉴가 «치워 둔 N장» 이라고 적는다
    /// (`{#tidy-visible-undo}` — 사라졌다고 오해하면 실패다).
    public var tidiedMemos: [Memo] { memos.filter { $0.tidied != nil } }

    public func memo(_ id: ULID) -> Memo? {
        memos.first { $0.id == id }
    }

    public func search(_ query: String, limit: Int = 50) async -> [Memo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return memos }
        do {
            return try await service.search(trimmed, limit: limit)
        } catch {
            // **경고로 올리지 않는다.** 인덱스가 아프면 파일을 훑는 느린 길로
            // 가지만 사용자가 찾던 것은 나온다. 성공한 일을 실패라고 적으면
            // 그 경고는 다음번에도 읽히지 않는다 — 경고는 할 일이 있을 때만.
            return memos.filter { $0.body.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    /// 캘린더 범위 조회 (설계문서 §10).
    public func scheduled(from: CalendarDate, to: CalendarDate) async -> [Memo] {
        do {
            return try await service.scheduled(from: from, to: to)
        } catch {
            // 검색과 같다 — 느린 길로 가지만 답은 나온다.
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
        every: Recurrence? = nil,
        surface: Date? = nil,
        place: String? = nil,
        geo: Coordinate? = nil,
        tags: [String] = [],
        color: MemoColor = .default,
        folder: String? = nil
    ) async throws -> Memo {
        let memo = try await recording("메모를 만들지 못했습니다") {
            try await service.create(
                body: body, due: due, at: at, every: every, surface: surface, place: place, geo: geo,
                tags: tags, color: color, folder: folder
            )
        }
        insertOrReplace(memo)
        return memo
    }

    @discardableResult
    public func update(
        _ id: ULID,
        body: String? = nil,
        due: CalendarDate?? = nil,
        at: Date?? = nil,
        every: Recurrence?? = nil,
        surface: Date?? = nil,
        place: String?? = nil,
        geo: Coordinate?? = nil,
        tags: [String]? = nil,
        color: MemoColor? = nil,
        pinned: Bool? = nil,
        folder: String?? = nil
    ) async throws -> Memo {
        let memo = try await recording("메모를 저장하지 못했습니다") {
            try await service.update(
                id, body: body, due: due, at: at, every: every, surface: surface, place: place, geo: geo,
                tags: tags, color: color, pinned: pinned, folder: folder
            )
        }
        insertOrReplace(memo)
        return memo
    }

    /// 삭제는 휴지통 이동뿐이다 (D6).
    public func delete(_ id: ULID) async throws {
        let removed = try await recording("메모를 지우지 못했습니다") {
            try await service.delete(id)
        }
        memos.removeAll { $0.id == id }
        trash.insert(removed, at: 0)
    }

    public func restore(_ id: ULID) async throws {
        let restored = try await recording("메모를 되돌리지 못했습니다") {
            try await service.restore(id)
        }
        trash.removeAll { $0.id == id }
        insertOrReplace(restored)
    }

    // MARK: 파일 ↔ 메모리 동기화

    /// 기동 시와 외부 변경(MCP·텍스트 에디터) 감지 시 모두 이 경로를 탄다.
    public func reconcile() async {
        do {
            memos = try await service.reconcile()
            trash = (try? await service.trashed()) ?? []
            trouble = nil
        } catch {
            // 이건 다르다 — 파일을 못 읽으면 보여줄 것 자체가 없다.
            report(error, while: "메모를 읽지 못했습니다")
        }
    }

    /// 아무도 안 쓰는 사진을 치우고, 치운 지 오래된 것은 지운다.
    ///
    /// **휴지통에 있는 메모의 본문도 참조로 친다.** 안 그러면 지운 메모를
    /// 되돌렸을 때 글만 돌아오고 사진은 없다.
    ///
    /// 갓 붙인 파일은 손대지 않는다 — 빠른 입력에 사진을 붙이면 파일이 먼저
    /// 생기고 본문은 아직 어느 메모에도 없기 때문이다. 그 유예가 곧 이
    /// 정리를 안전하게 만드는 유일한 장치라 넉넉히 준다.
    private func sweepAttachments(now: Date) {
        let bodies = memos.map(\.body) + trash.map(\.body)
        let grace = now.addingTimeInterval(-Self.attachmentGrace)
        do {
            try attachments.discardOrphans(referencedBy: bodies, notTouchedSince: grace)
            try attachments.purgeTrashed(now: now)
        } catch {
            report(error, while: "첨부를 정리하지 못했습니다")
        }
    }

    /// 붙인 지 이만큼 안 된 사진은 고아로 치지 않는다.
    private static let attachmentGrace: TimeInterval = 7 * 24 * 60 * 60

    /// 치워 둔 것을 도로 꺼낸다.
    public func untidy(_ id: ULID) async {
        guard let restored = try? await recording("치워 둔 메모를 꺼내지 못했습니다", {
            try await service.untidy(id)
        }) else { return }
        insertOrReplace(restored)
    }

    /// 치워 둔 것을 **한 번에** 전부 꺼낸다 (`{#tidy-visible-undo}`).
    public func untidyAll() async {
        guard let restored = try? await recording("치워 둔 메모를 꺼내지 못했습니다", {
            try await service.untidyAll()
        }) else { return }
        for memo in restored { insertOrReplace(memo) }
    }

    /// 끝난 것을 물러나게 한다 (`Tidy`). 하루가 바뀔 때와 기동 시에 돈다.
    ///
    /// 실패해도 경고로 올리지 않는다 — 못 치웠다는 것은 화면이 어제와 같다는
    /// 뜻일 뿐이라 사람이 할 일이 없다. 경고는 할 일이 있을 때만 (§6).
    private func sweepFinished(now: Date) async {
        // 걸어가는 것이 먼저다 — 치우기가 먼저 돌면 지난 회차가 잠깐
        // 「치워 둔 N장」에 들어갔다 나온다.
        if let rolled = try? await service.rollRecurring(now: now) {
            for memo in rolled { insertOrReplace(memo) }
        }
        guard let tidied = try? await service.tidyFinished(now: now) else { return }
        for memo in tidied { insertOrReplace(memo) }
    }

    private func purgeExpiredTrash() async {
        do {
            let purged = try await service.purgeExpiredTrash()
            if !purged.isEmpty {
                trash.removeAll { purged.contains($0.id) }
            }
        } catch {
            report(error, while: "휴지통을 정리하지 못했습니다")
        }
    }

    // MARK: 내부

    private func insertOrReplace(_ memo: Memo) {
        var updated = memos.filter { $0.id != memo.id }
        updated.append(memo)
        memos = MemoService.sorted(updated)
    }

    /// 실패를 **적어 두고 그대로 던진다.**
    ///
    /// 부르는 쪽의 처리를 뺏지 않으면서(쓰기는 여전히 `throws` 다), 저장 버튼이
    /// 없는 앱에서 조용히 사라지는 실패가 없게 한다. 쓰기 경로가 이 함수를
    /// 지나기 전에는 실패가 오직 호출자의 `try?` 안에서 죽었고 — 종이의
    /// 자동 저장이 정확히 그랬다 — 화면에는 아무 일도 일어나지 않았다.
    private func recording<T>(
        _ doing: String, _ work: () async throws -> T
    ) async throws -> T {
        do {
            let value = try await work()
            trouble = nil
            return value
        } catch {
            report(error, while: doing)
            throw error
        }
    }

    private func report(_ error: Error, while doing: String) {
        trouble = Trouble(doing: doing, detail: "\(error)")
    }
}
