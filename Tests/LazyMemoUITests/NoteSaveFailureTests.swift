import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 저장에 실패한 종이는 **스스로 그 사실을 말한다** (설계문서 §8).
///
/// `NoteModel.persistBody` 의 catch 는 오랫동안 비어 있었다 — 주석만 "조용히
/// 넘어가면 안 된다" 라고 적혀 있고 실제로는 조용히 넘어갔다. 저장 버튼이 없는
/// 앱에서 그것은 곧 **글이 사라지는 길**이다: 안 적힌 글도 화면에는 그대로
/// 있으므로 적힌 것과 구별되지 않고, 그 상태로 창을 닫으면 끝이다.
@MainActor
@Suite("메모 — 아직 안 적힌 종이")
struct NoteSaveFailureTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-unsaved-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    private func makeModel(_ memo: Memo, _ store: MemoStore, _ paths: AppPaths) -> NoteModel {
        NoteModel(
            memo: memo,
            store: store,
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: SettingsStore(location: paths.settings)
            )
        )
    }

    /// 정본 파일을 **잠깐 치운다.** 다음 쓰기는 반드시 실패한다.
    ///
    /// 지우지 않고 옮겨 두는 이유: 되돌려 놓아야 "다시 쓸 수 있게 되면" 을
    /// 시험할 수 있다. 통째로 지우면 그 메모는 영영 없는 메모가 되어,
    /// 디스크가 잠깐 막힌 상황이 아니라 다른 상황을 재는 것이 된다.
    @discardableResult
    private func hideNotes(_ paths: AppPaths) throws -> URL {
        let stash = paths.support.appending(path: "stash", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: stash)
        try FileManager.default.moveItem(at: paths.notes, to: stash)
        return stash
    }

    private func restoreNotes(_ paths: AppPaths, from stash: URL) throws {
        try? FileManager.default.removeItem(at: paths.notes)
        try FileManager.default.moveItem(at: stash, to: paths.notes)
    }

    @Test("파일에 못 쓰면 종이가 «아직 안 적혔다» 를 든다")
    func marksUnsavedWhenWriteFails() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")

        let model = makeModel(memo, store, paths)
        #expect(!model.isUnsaved)

        try hideNotes(paths)
        model.text = "치과 예약 — 강남역"
        model.edited(model.text)
        await model.flush()

        #expect(model.isUnsaved)
    }

    @Test("다시 쓸 수 있게 되면 표시가 사라진다")
    func clearsMarkOnceSaved() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")

        let model = makeModel(memo, store, paths)
        let stash = try hideNotes(paths)
        model.text = "첫 시도"
        model.edited(model.text)
        await model.flush()
        #expect(model.isUnsaved)

        // 쓸 자리가 돌아왔다.
        try restoreNotes(paths, from: stash)
        model.text = "두 번째 시도"
        model.edited(model.text)
        await model.flush()

        #expect(!model.isUnsaved)
        #expect(model.memo.body == "두 번째 시도")
    }

    @Test("실패해도 글은 종이에 그대로 남는다 — 되돌려 놓지 않는다")
    func keepsTextAfterFailure() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")

        let model = makeModel(memo, store, paths)
        try hideNotes(paths)
        model.text = "잃으면 안 되는 글"
        model.edited(model.text)
        await model.flush()

        // 표시는 뜨되 글은 화면에 있어야 사용자가 옮겨 담을 수 있다.
        #expect(model.isUnsaved)
        #expect(model.text == "잃으면 안 되는 글")
    }

    @Test("실패는 메뉴가 읽는 자리까지 올라간다")
    func failureReachesTheStore() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")

        let model = makeModel(memo, store, paths)
        try hideNotes(paths)
        model.text = "허공에 쓰기"
        model.edited(model.text)
        await model.flush()

        // 종이가 하나 표시를 드는 것만으로는 부족하다 — 그 종이가 치워져
        // 있으면 아무도 못 본다. 메뉴 첫머리가 같은 사실을 읽어야 한다.
        #expect(store.trouble?.doing == "메모를 저장하지 못했습니다")
    }
}
