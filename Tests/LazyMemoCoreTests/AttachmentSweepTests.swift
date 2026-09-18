import Foundation
import Testing
@testable import LazyMemoCore

/// 아무도 안 쓰는 사진을 치우는 길 (`MemoStore.tidy`).
///
/// `AttachmentStore.orphans()` 는 오래 **구현만 되어 있고 앱 어디서도 부르지
/// 않았다** — 설계문서 §7.3 이 직접 쓴 문장("부를 자리가 없는 기능은 없는
/// 기능이다")에 그대로 걸린다. 그래서 붙였다 지운 사진, 빠른 입력에 붙여
/// 놓고 확정하지 않은 사진이 Vault 에 영원히 쌓였다.
///
/// 이 정리는 **틀리면 사진을 잃는다.** 그래서 안전장치가 셋이고 셋 다 여기서
/// 못 박는다 — 휴지통에 있는 메모의 사진도 참조로 친다 · 갓 붙인 것은
/// 건드리지 않는다 · 지우지 않고 휴지통으로 옮긴다 (D6).
@MainActor
@Suite("첨부 정리")
struct AttachmentSweepTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-sweep-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoStore(paths: paths), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    /// 사진 한 장을 붙이고, 붙인 시각을 원하는 만큼 과거로 돌린다.
    @discardableResult
    private func attach(
        _ store: MemoStore, daysAgo: Int = 0
    ) throws -> (path: String, url: URL) {
        let path = try store.attachments.save(Data("사진".utf8), fileExtension: "png")
        let url = try #require(store.attachments.url(for: path))
        if daysAgo > 0 {
            let when = Date().addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60)
            try FileManager.default.setAttributes(
                [.modificationDate: when], ofItemAtPath: url.path(percentEncoded: false)
            )
        }
        return (path, url)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test("어느 메모도 안 쓰는 오래된 사진은 휴지통으로 간다 — 지우지는 않는다")
    func movesOldOrphansToTrash() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let orphan = try attach(store, daysAgo: 30)

        await store.tidy()

        #expect(!exists(orphan.url))
        let inTrash = store.attachments.trashDirectory
            .appending(path: orphan.url.lastPathComponent, directoryHint: .notDirectory)
        #expect(exists(inTrash))
    }

    @Test("iCloud 가 아직 안 내려받은 자리표는 고아가 아니다 — 옮기면 다른 기기의 사진까지 사라진다")
    func leavesCloudPlaceholdersAlone() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        try FileManager.default.createDirectory(at: store.attachments.directory, withIntermediateDirectories: true)
        let placeholder = store.attachments.directory
            .appending(path: ".01K4ZR0000000000000000AA.png.icloud", directoryHint: .notDirectory)
        try Data("plist".utf8).write(to: placeholder)
        let old = Date().addingTimeInterval(-400 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: placeholder.path(percentEncoded: false))

        await store.tidy()

        #expect(exists(placeholder))
        #expect(try store.attachments.orphans(referencedBy: []).isEmpty)
    }

    @Test("메모가 쓰고 있는 사진은 아무리 오래돼도 그대로 있다")
    func keepsReferencedAttachments() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let used = try attach(store, daysAgo: 400)
        _ = try await store.create(body: "장보기\n\n![](\(used.path))")

        await store.tidy()

        #expect(exists(used.url))
    }

    @Test("휴지통에 있는 메모의 사진도 지키다 — 되돌렸는데 사진만 없으면 안 된다")
    func keepsAttachmentsOfTrashedMemos() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let used = try attach(store, daysAgo: 400)
        let memo = try await store.create(body: "옛 사진\n\n![](\(used.path))")
        try await store.delete(memo.id)

        await store.tidy()

        #expect(exists(used.url))
        try await store.restore(memo.id)
        #expect(exists(used.url))
    }

    @Test("갓 붙인 사진은 건드리지 않는다 — 빠른 입력의 초안이 아직 메모가 아니다")
    func sparesFreshAttachments() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        // 방금 붙였다. 본문은 아직 어느 메모에도 없다.
        let pending = try attach(store)

        await store.tidy()

        #expect(exists(pending.url))
    }

    @Test("휴지통의 사진은 보존 기간이 지나야 사라진다 (D6)")
    func purgesTrashedAttachmentsAfterRetention() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let orphan = try attach(store, daysAgo: 30)
        await store.tidy()

        let inTrash = store.attachments.trashDirectory
            .appending(path: orphan.url.lastPathComponent, directoryHint: .notDirectory)
        #expect(exists(inTrash))

        // 치운 지 얼마 안 됐으므로 다시 정리해도 남아 있다. **옮긴 시각을 새로
        // 찍기 때문이다** — 안 찍으면 400일 된 사진이 치워지자마자 지워진다.
        await store.tidy()
        #expect(exists(inTrash))

        // 보존 기간이 지나면 그때 사라진다.
        let later = Date().addingTimeInterval(MemoVault.trashRetention + 60)
        await store.tidy(now: later)
        #expect(!exists(inTrash))
    }
}
