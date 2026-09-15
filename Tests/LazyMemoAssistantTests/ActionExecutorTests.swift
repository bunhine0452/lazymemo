import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

@Suite("ActionExecutor")
struct ActionExecutorTests {
    func makeService() throws -> (MemoService, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-executor-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        return (try MemoService(paths: paths), paths)
    }
    func cleanUp(_ paths: AppPaths) { try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent()) }

    let friday10 = ISO8601DateFormatter().date(from: "2026-09-18T01:00:00Z")!
    let dentistAt = ISO8601DateFormatter().date(from: "2026-09-18T05:00:00Z")!

    @Test("setRecall 은 surface 만 바꾸고 due·at 은 그대로")
    func setRecallPreserves() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "치과", due: CalendarDate(year: 2026, month: 9, day: 18), at: dentistAt)
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .setRecall, memoID: memo.id, expectedContentHash: memo.contentHash,
                                    patch: FieldPatch(surface: .set(friday10)))
        let receipt = try await executor.execute(action)
        #expect(receipt.after.surface == friday10)
        #expect(receipt.after.at == dentistAt)
        #expect(receipt.after.due == memo.due)
        let onDisk = try await service.get(memo.id)
        #expect(onDisk.surface == friday10)
    }

    @Test("모델이 본 글과 다르면 아무것도 쓰지 않는다")
    func hashMismatchRefuses() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "원본")
        _ = try await service.update(memo.id, body: "사용자가 고침")
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .moveToFolder, memoID: memo.id, expectedContentHash: memo.contentHash,
                                    patch: FieldPatch(folder: .set("일")))
        await #expect(throws: ActionError.memoChanged(memo.id)) { try await executor.execute(action) }
        let onDisk = try await service.get(memo.id)
        #expect(onDisk.folder == nil)
        #expect(onDisk.body == "사용자가 고침")
    }

    @Test("같은 요청을 두 번 실행해도 메모는 하나만 생긴다")
    func duplicateRequestIsIdempotent() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .createMemo, patch: FieldPatch(body: "내일 회의", at: .set(friday10)))
        let first = try await executor.execute(action)
        let second = try await executor.execute(action)
        #expect(first == second)
        #expect(try await service.all().count == 1)
        #expect(first.after.at == friday10)
    }

    @Test("clear 는 비우고 keep 은 건드리지 않는다")
    func clearVersusKeepOnDisk() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "치과", at: dentistAt, surface: friday10)
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .setRecall, memoID: memo.id, expectedContentHash: memo.contentHash,
                                    patch: FieldPatch(surface: .clear))
        let receipt = try await executor.execute(action)
        #expect(receipt.after.surface == nil)
        #expect(receipt.after.at == dentistAt)
    }

    @Test("휴지통은 확인 없이는 안 가고, 확인하면 가고, 되돌리면 돌아온다")
    func trashNeedsConfirmationAndUndoes() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "지울 것")
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .trash, memoID: memo.id, expectedContentHash: memo.contentHash)
        await #expect(throws: ActionError.needsConfirmation) { try await executor.execute(action) }
        let receipt = try await executor.execute(action, confirmedTrash: true)
        #expect(receipt.after.deleted != nil)
        #expect(try await service.all().isEmpty)
        _ = try await executor.undo(receipt)
        #expect(try await service.all().map(\.id) == [memo.id])
    }

    @Test("되돌리기는 그 뒤에 고친 메모를 덮어쓰지 않는다")
    func undoRefusesWhenEditedAfter() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let memo = try await service.create(body: "치과", at: dentistAt)
        let executor = ActionExecutor(service: service)
        let action = ProposedAction(requestID: UUID(), kind: .reschedule, memoID: memo.id, expectedContentHash: memo.contentHash,
                                    patch: FieldPatch(at: .set(friday10)))
        let receipt = try await executor.execute(action)
        _ = try await service.update(memo.id, body: "치과 — 주차 확인")
        await #expect(throws: ActionError.undoStale(memo.id)) { try await executor.undo(receipt) }
        let onDisk = try await service.get(memo.id)
        #expect(onDisk.at == friday10)
        #expect(onDisk.body == "치과 — 주차 확인")

        // 손대지 않았으면 되돌아간다.
        let memo2 = try await service.create(body: "은행", at: dentistAt)
        let action2 = ProposedAction(requestID: UUID(), kind: .reschedule, memoID: memo2.id, expectedContentHash: memo2.contentHash,
                                     patch: FieldPatch(at: .set(friday10)))
        let receipt2 = try await executor.execute(action2)
        let restored = try await executor.undo(receipt2)
        #expect(restored?.at == dentistAt)
    }

    @Test("ask·none 은 실행할 것이 없다")
    func askIsNotExecutable() async throws {
        let (service, paths) = try makeService(); defer { cleanUp(paths) }
        let executor = ActionExecutor(service: service)
        await #expect(throws: ActionError.nothingToExecute) {
            try await executor.execute(ProposedAction(requestID: UUID(), kind: .ask, question: "어느 메모?"))
        }
        #expect(try await service.all().isEmpty)
    }
}
