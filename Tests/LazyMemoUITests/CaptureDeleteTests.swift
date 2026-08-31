import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 빠른 입력에서 지우는 길 (설계문서 §6).
///
/// 메뉴 목록은 여덟 장까지만 보인다. 그 너머는 이 상자에서만 만날 수 있으므로,
/// **여기서 못 지우면 아홉 번째 메모부터는 지울 길이 없다** — 바탕화면에서 그
/// 종이를 찾아내는 것 말고는. 화면을 봐서는 "지워졌는데 목록에 남아 있다" 나
/// "⌘⌫ 가 글자를 지웠다" 를 구별할 수 없어 여기서 못 박는다.
@MainActor
@Suite("빠른 입력 — 목록에서 지우기")
struct CaptureDeleteTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-capture-delete-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    /// 빈 상자가 들고 있는 요즘 메모 — 여기서 지우는 것이 가장 흔한 길이다.
    private func makeBrowsing(_ store: MemoStore) -> QuickCaptureModel {
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        return model
    }

    @Test("지우면 목록에서 빠지고 휴지통으로 간다 — 파일은 남는다 (D6)")
    func deleteMovesToTrash() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "장보기")
        let receipts = try await store.create(body: "영수증 정리")

        let model = makeBrowsing(store)
        #expect(model.listed.count == 2)

        await model.delete(receipts)

        #expect(!model.listed.contains { $0.id == receipts.id })
        #expect(model.listed.count == 1)
        #expect(store.trash.map(\.id) == [receipts.id])
    }

    @Test("지운 뒤 되돌리는 줄이 상자 안에 남는다")
    func keepsUndoLine() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "영수증 정리")

        let model = makeBrowsing(store)
        await model.delete(memo)
        #expect(model.lastDeleted?.id == memo.id)

        await model.restoreLastDeleted()
        #expect(model.lastDeleted == nil)
        #expect(model.listed.map(\.id) == [memo.id])
        #expect(store.trash.isEmpty)
    }

    @Test("고른 자리는 지킨다 — 다음 줄이 그 자리로 올라온다")
    func keepsSelectionSlot() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        for body in ["하나", "둘", "셋"] { _ = try await store.create(body: body) }

        let model = makeBrowsing(store)
        model.selection = 1
        let second = model.listed[1]
        let third = model.listed[2]

        await model.delete(second)

        // 자리는 그대로 1, 그 자리에 있던 것은 셋째 줄이던 메모다.
        #expect(model.selection == 1)
        #expect(model.listed[1].id == third.id)
    }

    @Test("마지막 한 장을 지우면 고른 것이 사라진다 — ⌘⏎ 가 빈 것을 열면 안 된다")
    func clearsSelectionWhenEmptied() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let only = try await store.create(body: "하나뿐")

        let model = makeBrowsing(store)
        model.selection = 0
        await model.delete(only)

        #expect(model.listed.isEmpty)
        #expect(model.selection == nil)
        if case .nothing = model.commit() {} else { Issue.record("빈 목록에서 열 것이 남았다") }
    }

    @Test("찾은 목록에서 지우면 같은 낱말로 다시 찾은 결과가 남는다")
    func refreshesFoundListing() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "치과 예약")
        let checkup = try await store.create(body: "치과 정기검진")

        let model = QuickCaptureModel(store: store)
        model.query = "치과"
        await settle("찾은 것이 둘이 되지 않았다") { model.listed.count == 2 }

        await model.delete(checkup)

        // 지웠다고 요즘 메모로 돌아가 버리면, 훑던 자리를 잃는다.
        #expect(model.listing == .found)
        #expect(model.listed.count == 1)
        #expect(model.listed.first?.id != checkup.id)
    }

    @Test("⌘⌫ 는 고른 줄을 지운다")
    func commandDeleteRemovesSelected() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "하나")
        _ = try await store.create(body: "둘")

        let model = makeBrowsing(store)
        model.selection = 0
        let target = model.listed[0]

        let view = QuickCaptureView(model: model, onCommit: {}, onCancel: {})
        let handled = view.handle(
            command: #selector(NSResponder.deleteToBeginningOfLine(_:)),
            in: NSTextView()
        )

        #expect(handled)
        // 지우기는 비동기로 이어진다. 목록에서 빠질 때까지만 기다린다.
        await settle("지운 줄이 목록에서 안 빠졌다") {
            !model.listed.contains { $0.id == target.id }
        }
    }

    @Test("고른 줄이 없으면 ⌘⌫ 는 글 편집으로 넘어간다")
    func commandDeleteFallsThroughWithoutSelection() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "하나")

        let model = makeBrowsing(store)
        model.selection = nil

        let view = QuickCaptureView(model: model, onCommit: {}, onCancel: {})
        let handled = view.handle(
            command: #selector(NSResponder.deleteToBeginningOfLine(_:)),
            in: NSTextView()
        )

        // 여기서 true 를 돌려주면 상자에서 ⌘⌫ 로 글을 지울 수 없게 된다.
        #expect(!handled)
        #expect(model.lastDeleted == nil)
        #expect(store.trash.isEmpty)
    }

    @Test("다시 열면 지난번 되돌리기 줄은 남지 않는다")
    func dropsUndoLineOnReopen() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "영수증 정리")

        let model = makeBrowsing(store)
        await model.delete(memo)
        #expect(model.lastDeleted != nil)

        model.prepareForShow()
        #expect(model.lastDeleted == nil)
    }
}
