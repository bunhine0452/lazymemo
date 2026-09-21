import Foundation

/// 파일과 인덱스를 함께 다루는 도메인 서비스.
///
/// 앱(`MemoStore`, @MainActor)과 MCP 서버(별도 프로세스)가 **같은 규칙**으로
/// 데이터를 만지도록 로직을 여기 한 곳에 둔다. 특히 D6 — "삭제는 휴지통
/// 이동뿐" — 이 두 경로에서 따로 구현되면 그 순간 약속이 깨진다.
///
/// AppKit·Observation 비의존이라 런루프 없는 CLI 에서도 돈다.
public actor MemoService {
    public let paths: AppPaths
    private let vault: MemoVault
    private let index: MemoIndex

    public init(paths: AppPaths) throws {
        self.paths = paths
        self.vault = MemoVault(paths: paths)
        self.index = try MemoIndex(path: paths.index)
    }

    // MARK: 조회

    /// 파일을 정본으로 삼아 인덱스를 맞추고, 정렬된 전체 목록을 돌려준다.
    ///
    /// mtime 이 그대로면 아무것도 쓰지 않는다 — 앱이 방금 저장한 파일에 대한
    /// 파일 감시 이벤트가 여기로 되돌아와도 할 일이 없다.
    @discardableResult
    public func reconcile() async throws -> [Memo] {
        // 밖에서 떨어진 낯선 이름의 파일을 먼저 받아 앉힌다. 이 한 줄이
        // 아이폰 단축어·Hazel·Finder 끌어놓기를 전부 입력 경로로 만든다.
        try? await vault.adopt()
        // iCloud 가 자리만 잡아 둔 파일은 내려받기를 청한다. 내려오면 감시가 다시 부른다.
        await vault.requestMissingDownloads()
        // 두 기기가 따로 고친 것이 만났으면 정리한다 — 진 쪽은 휴지통에 남는다.
        try? await vault.settleConflicts()

        let files = try await vault.loadAll()
        let known = (try? await index.fingerprints()) ?? [:]

        for file in files where known[file.memo.id] != file.modifiedAt {
            try? await index.upsert(
                file.memo, relativePath: file.relativePath, modifiedAt: file.modifiedAt
            )
        }
        for staleID in Set(known.keys).subtracting(files.map(\.memo.id)) {
            try? await index.remove(staleID)
        }

        return Self.sorted(files.map(\.memo))
    }

    public func all() async throws -> [Memo] {
        Self.sorted(try await vault.loadAll().map(\.memo))
    }

    public func trashed() async throws -> [Memo] {
        try await vault.trashedMemos()
    }

    public func get(_ id: ULID) async throws -> Memo {
        try await vault.load(id)
    }

    /// 전문 검색. 인덱스가 죽어 있어도 파일 스캔으로 답한다 — 정본은 파일이다.
    public func search(_ query: String, limit: Int = 50) async throws -> [Memo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(try await all().prefix(limit)) }

        do {
            let entries = try await index.search(trimmed, limit: limit)
            return try await hydrate(entries)
        } catch {
            return Array(
                try await all()
                    .filter { $0.body.localizedCaseInsensitiveContains(trimmed) }
                    .prefix(limit)
            )
        }
    }

    public func scheduled(from: CalendarDate, to: CalendarDate) async throws -> [Memo] {
        do {
            return try await hydrate(try await index.scheduled(from: from, to: to))
        } catch {
            return try await all().filter {
                guard let date = $0.scheduledDate() else { return false }
                return date >= from && date <= to
            }
        }
    }

    /// 인덱스 결과를 정본 파일로 되읽는다. 인덱스에 본문을 신뢰하지 않는다는 뜻이다.
    private func hydrate(_ entries: [MemoIndexEntry]) async throws -> [Memo] {
        var result: [Memo] = []
        for entry in entries {
            if let memo = try? await vault.load(entry.id) { result.append(memo) }
        }
        return result
    }

    // MARK: 변경 — 항상 파일 먼저, 그 다음 인덱스

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
        folder: String? = nil,
        now: Date = Date()
    ) async throws -> Memo {
        let memo = Memo(
            id: ULID(timestamp: now), created: now, updated: now,
            due: due, at: at, every: every, surface: surface, place: place, geo: geo,
            tags: tags, color: color, body: body, folder: folder
        )
        return try await persist(memo)
    }

    /// 미지정 필드는 보존한다 — MCP `update_memo` 의 계약이다 (§9.2).
    /// 이중 옵셔널은 "건드리지 않음"(nil)과 "비움"(.some(nil))을 가르기 위한 것이다.
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
        folder: String?? = nil,
        now: Date = Date()
    ) async throws -> Memo {
        // 읽고 고치고 쓰기를 vault 의 한 호출 안에서 — 파일이 규격 밖 자리에 있어도 그 자리에 되쓴다.
        let result = try await vault.modify(id, expectedHash: nil) { memo in
            if let body { memo.body = body }
            // 사람이 날을 옮기면 그 날이 되풀이의 새 처음이다 (`Memo.anchor`).
            if let due { memo.due = due; memo.anchor = nil }
            if let at { memo.at = at; memo.anchor = nil }
            if let every { memo.every = every }
            if let surface { memo.surface = surface }
            // 때를 옮긴 것은 새 회차다 — 도로 꺼낸 뜻(`kept`)도 끝냈다는 표시(`done`)도 그 회차까지였다.
            if due != nil || at != nil || surface != nil { memo.kept = nil; memo.done = nil }
            if let place { memo.place = place }
            if let geo { memo.geo = geo }
            if let tags { memo.tags = tags }
            if let color { memo.color = color }
            if let pinned { memo.pinned = pinned }
            if let folder { memo.folder = MemoFolders.normalized(folder) }
            memo.updated = now.truncatingSubsecond
            // 손댄 것은 다시 산 것이다. 치워 둔 메모를 고쳤는데 여전히 목록에
            // 없으면, 사람은 자기가 고친 글이 어디로 갔는지 알 길이 없다.
            memo.tidied = nil
        }
        try? await index.upsert(
            result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt
        )
        return result.memo
    }

    /// 조건부 변경 — `expectedHash` 가 지금 본문과 다르면 `MemoVault.Failure.changed`, 아무것도 안 쓴다.
    ///
    /// 비서가 제안한 변경은 이 길로만 들어온다: 모델이 본 글과 저장 직전의 글이 같아야
    /// 「그 메모를 그렇게 바꾼다」는 뜻이 지켜진다. `update` 와 같은 후처리(`updated`·`tidied`)를 한다.
    @discardableResult
    public func modify(
        _ id: ULID, expectedHash: String?, now: Date = Date(), _ change: @Sendable (inout Memo) throws -> Void
    ) async throws -> Memo {
        let result = try await vault.modify(id, expectedHash: expectedHash) { memo in
            let schedule = (memo.due, memo.at)
            let surface = memo.surface
            try change(&memo)
            // 날을 옮겼으면 되풀이의 처음 날도 그 날이다 (`update` 와 같다).
            if (memo.due, memo.at) != schedule { memo.anchor = nil }
            // 때를 옮겼으면 도로 꺼낸 뜻도, 끝냈다는 표시도 그 회차까지였다 (`update` 와 같다).
            if (memo.due, memo.at) != schedule || memo.surface != surface { memo.kept = nil; memo.done = nil }
            memo.folder = MemoFolders.normalized(memo.folder)
            memo.updated = now.truncatingSubsecond
            memo.tidied = nil
        }
        try? await index.upsert(
            result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt
        )
        return result.memo
    }

    /// **휴지통 이동만 한다.** 하드 삭제로 가는 공개 경로가 이 타입에 없다 (D6).
    /// `expectedHash` 를 주면 그 사이 바뀐 메모는 옮기지 않는다.
    @discardableResult
    public func delete(_ id: ULID, expectedHash: String? = nil) async throws -> Memo {
        let removed = try await vault.moveToTrash(id, expectedHash: expectedHash)
        try? await index.remove(id)
        return removed
    }

    @discardableResult
    public func restore(_ id: ULID) async throws -> Memo {
        let result = try await vault.restore(id)
        try? await index.upsert(
            result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt
        )
        return result.memo
    }

    /// 충돌의 진 판을 이 판으로 (`MemoVault.adoptConflict`). 돌려주는 것은 글을 받은 자리의 메모.
    @discardableResult
    public func adoptConflict(_ id: ULID, now: Date = Date()) async throws -> Memo {
        let result = try await vault.adoptConflict(id, now: now)
        try? await index.upsert(
            result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt
        )
        return result.memo
    }

    // MARK: 끝내기·보관 (인계서 §4 — 사람의 뜻은 파일에 적혀 동기화되고, 되돌릴 수 있다)

    /// 끝냈다 — `done` 을 찍는다. 알림·「지금」에서 빠지고, 사흘 뒤 물러난다 (`Tidy`). 도로 꺼낸 뜻(`kept`)은
    /// 끝냄이 이긴다 — 「다시 보겠다」보다 「끝냈다」가 나중의 말이다.
    @discardableResult
    public func markDone(_ id: ULID, now: Date = Date()) async throws -> Memo {
        let result = try await vault.modify(id, expectedHash: nil) { memo in
            memo.done = now.truncatingSubsecond
            memo.kept = nil
            memo.updated = now.truncatingSubsecond
        }
        try? await index.upsert(result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt)
        return result.memo
    }

    /// 끝낸 것을 되돌린다 — 다시 할 일이다. 규칙이 그 사이 치웠으면 도로 꺼낸다.
    @discardableResult
    public func markUndone(_ id: ULID, now: Date = Date()) async throws -> Memo {
        let result = try await vault.modify(id, expectedHash: nil) { memo in
            memo.done = nil
            memo.tidied = nil
            memo.updated = now.truncatingSubsecond
        }
        try? await index.upsert(result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt)
        return result.memo
    }

    /// 보관 — 당장 안 볼 기록. 목록·알림·「지금」에서 빠지고 검색·원문은 그대로. 완료도 삭제도 아니다.
    @discardableResult
    public func archive(_ id: ULID, now: Date = Date()) async throws -> Memo {
        let result = try await vault.modify(id, expectedHash: nil) { memo in
            memo.archived = now.truncatingSubsecond
            memo.updated = now.truncatingSubsecond
        }
        try? await index.upsert(result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt)
        return result.memo
    }

    /// 보관에서 꺼낸다 — 사람의 뜻이라 규칙이 다시 치우지 않게 `kept` 도 찍는다 (`untidy` 와 같다).
    @discardableResult
    public func unarchive(_ id: ULID, now: Date = Date()) async throws -> Memo {
        let result = try await vault.modify(id, expectedHash: nil) { memo in
            memo.archived = nil
            memo.tidied = nil
            memo.kept = now.truncatingSubsecond
            memo.updated = now.truncatingSubsecond
        }
        try? await index.upsert(result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt)
        return result.memo
    }

    // MARK: 스스로 물러나기 (`Tidy`)

    /// 규칙에 걸리는 메모를 전부 치운다. **파일에 `tidied:` 를 적을 뿐이다** —
    /// 옮기지도, 지우지도 않는다.
    ///
    /// `updated` 는 건드리지 않는다. 치우는 것은 사람이 손댄 일이 아니므로,
    /// 여기서 시각을 새로 찍으면 목록의 차례가 통째로 뒤집히고 "다 체크한 지
    /// 사흘" 이라는 셈도 그 자리에서 초기화된다.
    ///
    /// - Returns: 새로 치운 메모들.
    @discardableResult
    public func tidyFinished(now: Date = Date()) async throws -> [Memo] {
        var tidied: [Memo] = []
        for memo in try await vault.loadAll().map(\.memo) {
            // 사람이 꺼낸 것(`kept`)을 이 필드를 모르는 판의 앱이 도로 치웠으면 다시 세운다 —
            // 파일에 적힌 사람의 뜻이 어느 기기의 규칙보다 앞선다.
            if memo.kept != nil, memo.tidied != nil {
                var back = memo
                back.tidied = nil
                _ = try await persist(back)
                continue
            }
            guard Tidy.reason(for: memo, now: now) != nil else { continue }
            var moved = memo
            moved.tidied = now.truncatingSubsecond
            tidied.append(try await persist(moved))
        }
        return tidied
    }

    /// 지난 회차의 되풀이 일정을 **다음 회차로 걸어 보낸다** (`Tidy.rolled`).
    ///
    /// 치우기와 짝이지만 방향이 반대다 — 치우기는 물러나게 하고 이것은 앞으로
    /// 보낸다. 그래서 `tidyFinished` 보다 **먼저** 돌아야 한다: 순서가 바뀌면
    /// 지난 회차가 치워진 뒤에 걸어가게 되고, 그 사이에 사람이 메뉴를 열면
    /// 분리수거가 「치워 둔 N장」에 잠깐 들어가 있다.
    ///
    /// - Returns: 걸어간 메모들.
    @discardableResult
    public func rollRecurring(now: Date = Date()) async throws -> [Memo] {
        var rolled: [Memo] = []
        for memo in try await vault.loadAll().map(\.memo) {
            guard let moved = Tidy.rolled(memo, now: now) else { continue }
            rolled.append(try await persist(moved))
        }
        return rolled
    }

    /// 치워 둔 것을 도로 꺼낸다.
    ///
    /// **`kept` 를 지금으로 찍는다** — 규칙이 다시 치우지 않는다는 표시다. 안 그러면 다음
    /// 정리가 도로 치운다: 지난 일정은 `updated` 를 보지 않으므로 꺼낸 그 날 저녁에
    /// 없어졌고, 사람이 꺼낸 것을 앱이 되돌리면 그건 고장으로 보인다. `updated` 도
    /// 지금으로 찍는다 — 방금 꺼낸 것은 실제로 지금 관심 있는 메모라 목록 맨 위가 제자리다.
    @discardableResult
    public func untidy(_ id: ULID, now: Date = Date()) async throws -> Memo {
        let memo = try await vault.load(id)
        guard memo.tidied != nil else { return memo }
        return try await persist(Self.broughtBack(memo, now: now))
    }

    /// 치워 둔 것을 전부 도로 꺼낸다 (`{#tidy-visible-undo}`).
    @discardableResult
    public func untidyAll(now: Date = Date()) async throws -> [Memo] {
        var restored: [Memo] = []
        for memo in try await vault.loadAll().map(\.memo) where memo.tidied != nil {
            restored.append(try await persist(Self.broughtBack(memo, now: now)))
        }
        return restored
    }

    /// 도로 꺼낸 모습 — `untidy` 와 `untidyAll` 이 같은 것을 적는다.
    private static func broughtBack(_ memo: Memo, now: Date) -> Memo {
        var back = memo
        back.tidied = nil
        back.kept = now.truncatingSubsecond
        back.updated = now.truncatingSubsecond
        return back
    }

    /// 보존 기간이 지난 휴지통 정리. **앱만 부른다** — MCP 도구로 노출되지 않는다.
    @discardableResult
    public func purgeExpiredTrash(now: Date = Date()) async throws -> [ULID] {
        try await vault.purgeExpired(now: now)
    }

    private func persist(_ memo: Memo) async throws -> Memo {
        let result = try await vault.save(memo)
        try? await index.upsert(
            result.memo, relativePath: result.relativePath, modifiedAt: result.modifiedAt
        )
        return result.memo
    }

    /// 고정된 것이 먼저, 그 다음 최근 수정 순.
    static func sorted(_ list: [Memo]) -> [Memo] {
        list.sorted { left, right in
            if left.pinned != right.pinned { return left.pinned }
            return left.updated > right.updated
        }
    }
}
