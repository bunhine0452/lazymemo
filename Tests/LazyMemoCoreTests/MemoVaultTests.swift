import Foundation
import Testing
@testable import LazyMemoCore

/// 테스트마다 격리된 임시 Vault 를 만든다.
private func makeTemporaryPaths() throws -> AppPaths {
    let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
        .appending(path: "lazymemo-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    let paths = AppPaths(
        vault: root.appending(path: "vault", directoryHint: .isDirectory),
        support: root.appending(path: "support", directoryHint: .isDirectory)
    )
    try paths.createDirectories()
    return paths
}

private func remove(_ paths: AppPaths) {
    try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
}

@Suite("MemoVault")
struct MemoVaultTests {
    @Test("저장한 메모를 그대로 읽는다")
    func savesAndLoads() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        let memo = Memo(tags: ["병원"], color: .blue, body: "치과 예약")
        try await vault.save(memo)

        let loaded = try await vault.load(memo.id)
        #expect(loaded.body == "치과 예약")
        #expect(loaded.tags == ["병원"])
        #expect(loaded.color == .blue)
    }

    @Test("사람이 다른 폴더로 옮겨 둔 파일은 그 자리에 되쓴다 — 같은 메모가 두 파일이 되지 않는다")
    func modifiesMovedFileInPlace() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)
        let memo = Memo(body: "치과 예약")
        try await vault.save(memo)

        // Finder 로 다른 달 폴더에 옮겼다.
        let elsewhere = paths.notes.appending(path: "2020/01", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let moved = elsewhere.appending(path: MemoFile.fileName(for: memo.id), directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: vault.url(for: memo.id), to: moved)

        try await vault.modify(memo.id, expectedHash: nil) { $0.body = "치과 예약 — 3시" }

        #expect(try await vault.loadAll().count == 1)
        #expect(try await vault.load(memo.id).body == "치과 예약 — 3시")
        #expect(!FileManager.default.fileExists(atPath: vault.url(for: memo.id).path(percentEncoded: false)))
    }

    @Test("파일 경로는 ULID 의 생성 시각에서 나온다")
    func pathComesFromIdentifierTimestamp() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let created = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12))!
        let memo = Memo(id: ULID(timestamp: created), body: "본문")

        let result = try await vault.save(memo)
        #expect(result.relativePath.hasPrefix("notes/2026/08/"))
    }

    @Test("frontmatter 의 created 를 고쳐도 파일을 찾는다")
    func survivesEditedCreatedField() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        var memo = Memo(body: "본문")
        try await vault.save(memo)

        // 사용자가 created 를 2년 전으로 고친 상황
        memo.created = Date(timeIntervalSince1970: 1_600_000_000)
        try await vault.save(memo)

        #expect(try await vault.load(memo.id).body == "본문")
    }

    @Test("삭제는 파일을 지우지 않고 휴지통으로 옮긴다")
    func deleteMovesToTrash() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        let memo = Memo(body: "지울 메모")
        try await vault.save(memo)
        let noteURL = await vault.url(for: memo.id)

        let trashed = try await vault.moveToTrash(memo.id)

        #expect(!FileManager.default.fileExists(atPath: noteURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: await vault.trashURL(for: memo.id).path(percentEncoded: false)))
        #expect(trashed.deleted != nil)
        #expect(try await vault.trashedMemos().count == 1)
    }

    @Test("휴지통에서 되돌리면 삭제 표시가 지워진다")
    func restoreClearsDeletionStamp() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        let memo = Memo(body: "되돌릴 메모")
        try await vault.save(memo)
        try await vault.moveToTrash(memo.id)
        try await vault.restore(memo.id)

        let restored = try await vault.load(memo.id)
        #expect(restored.deleted == nil)
        #expect(restored.body == "되돌릴 메모")
        #expect(try await vault.trashedMemos().isEmpty)
    }

    @Test("보존 기간이 지난 것만 실제로 지운다")
    func purgeOnlyRemovesExpired() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        let old = Memo(body: "오래된 삭제")
        let recent = Memo(body: "방금 삭제")
        try await vault.save(old)
        try await vault.save(recent)

        let now = Date()
        try await vault.moveToTrash(old.id, now: now.addingTimeInterval(-40 * 24 * 3600))
        try await vault.moveToTrash(recent.id, now: now)

        let purged = try await vault.purgeExpired(now: now)

        #expect(purged == [old.id])
        #expect(try await vault.trashedMemos().map(\.id) == [recent.id])
    }

    @Test("삭제 시각이 없는 휴지통 파일은 건드리지 않는다")
    func purgeSkipsFilesWithoutDeletionStamp() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        // 사용자가 직접 넣어둔 파일이라고 가정한다
        let memo = Memo(body: "직접 넣은 파일")
        let target = await vault.trashURL(for: memo.id)
        try Data(MemoFile.encode(memo).utf8).write(to: target)

        let purged = try await vault.purgeExpired(now: Date().addingTimeInterval(10 * 365 * 24 * 3600))

        #expect(purged.isEmpty)
        #expect(FileManager.default.fileExists(atPath: target.path(percentEncoded: false)))
    }

    @Test("전체 스캔이 모든 메모를 찾는다 — 인덱스 재생성의 근거")
    func fullScanFindsEverything() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        let timestamps = [
            Date(timeIntervalSince1970: 1_700_000_000),
            Date(timeIntervalSince1970: 1_750_000_000),
            Date(timeIntervalSince1970: 1_787_000_000),
        ]
        for (offset, timestamp) in timestamps.enumerated() {
            try await vault.save(Memo(id: ULID(timestamp: timestamp), body: "메모 \(offset)"))
        }

        let all = try await vault.loadAll()
        #expect(all.count == 3)
        #expect(Set(all.map(\.memo.body)) == ["메모 0", "메모 1", "메모 2"])
    }

    @Test("없는 메모를 읽으면 실패한다")
    func loadingMissingMemoFails() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)

        await #expect(throws: MemoVault.Failure.self) {
            try await vault.load(ULID())
        }
    }
}

@Suite("MemoService")
struct MemoServiceTests {
    @Test("수정 시각은 다음 초에 앞으로 간다")
    func updatedAdvancesAcrossSeconds() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let service = try MemoService(paths: paths)

        let created = try await service.create(body: "본문", now: Date(timeIntervalSince1970: 1_787_000_000))
        let updated = try await service.update(
            created.id, body: "고친 본문", now: Date(timeIntervalSince1970: 1_787_000_005)
        )

        #expect(updated.updated > created.updated)
        #expect(updated.created == created.created)
    }

    @Test("삭제는 휴지통 이동이고 하드 삭제 API 가 노출되지 않는다")
    func deleteOnlyMovesToTrash() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let service = try MemoService(paths: paths)

        let memo = try await service.create(body: "지울 메모")
        try await service.delete(memo.id)

        #expect(try await service.all().isEmpty)
        #expect(try await service.trashed().map(\.id) == [memo.id])
    }

    @Test("update 는 이중 옵셔널로 비우기와 건드리지 않기를 가른다")
    func distinguishesClearingFromLeavingAlone() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let service = try MemoService(paths: paths)

        let memo = try await service.create(
            body: "약속", due: CalendarDate(year: 2026, month: 9, day: 1), tags: ["병원"]
        )

        // 건드리지 않음 — due 가 남는다
        let untouched = try await service.update(memo.id, body: "약속 수정")
        #expect(untouched.due == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(untouched.tags == ["병원"])

        // 비움 — due 가 사라진다
        let cleared = try await service.update(memo.id, due: .some(nil))
        #expect(cleared.due == nil)
        #expect(cleared.tags == ["병원"])
    }

    // MARK: iCloud 가 자리만 잡아 둔 파일

    @Test("숨은 .icloud 자리에서 진짜 파일 이름을 되읽는다")
    func placeholderRevealsRealFile() {
        let directory = URL(filePath: "/v/notes/2026/09", directoryHint: .isDirectory)
        let placeholder = directory.appending(path: ".01K4ZQ8F7N2R4M6X8B0V5T9WQY.md.icloud")

        #expect(MemoVault.realFile(behindPlaceholder: placeholder) == directory.appending(path: "01K4ZQ8F7N2R4M6X8B0V5T9WQY.md"))
        #expect(MemoVault.realFile(behindPlaceholder: directory.appending(path: "01K4ZQ8F7N2R4M6X8B0V5T9WQY.md")) == nil)
        #expect(MemoVault.realFile(behindPlaceholder: directory.appending(path: ".pic.png.icloud")) == nil, "메모가 아닌 것은 청하지 않는다")
    }

    @Test("보통 폴더에는 청할 것이 없다")
    func nothingToDownloadLocally() async throws {
        let paths = try makeTemporaryPaths()
        defer { remove(paths) }
        let vault = MemoVault(paths: paths)
        try await vault.save(Memo(body: "여기 있는 것"))

        #expect(await vault.requestMissingDownloads() == 0)
    }
}
