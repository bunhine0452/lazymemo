import CoreGraphics
import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// **지우는 길이 셋이면 되돌리는 길도 셋이다** (설계문서 §6, D6).
///
/// 지우기는 목록에서도(빠른 입력·메뉴), 종이에서도, 달력에서도 할 수 있는데
/// 되돌리는 줄이 그 자리에 생기는 것은 목록뿐이었다. 종이의 휴지통은 창이
/// 소리 없이 사라져 화면에 흔적이 하나도 안 남았고, 달력 줄에는 지우는 길이
/// 아예 없어서 날짜를 떼어 종이로 내려보낸 뒤 그 종이를 찾아 지워야 했다.
///
/// 잘못 눌렀다는 것을 아는 순간은 **지운 직후**다. 그때 되돌리는 길이 메뉴
/// 안에만 있으면 그 휴지통은 못 누르는 버튼이 된다.
@MainActor
@Suite("지운 자리에 남는 되돌리기")
struct DeleteUndoTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-undo-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    // MARK: 종이 (`{#note-inline-undo}`)

    @Test("종이를 지우면 그 자리에 되돌리는 줄이 남는다")
    func paperKeepsAnUndoLine() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")
        let model = makeModel(memo, store, paths)

        await model.delete()

        // 창이 사라지지 않는 근거가 이 값이다 (`NoteWindowController.isMourning`).
        #expect(model.justDeleted?.id == memo.id)
        #expect(store.memo(memo.id) == nil)
        #expect(store.trash.contains { $0.id == memo.id })
    }

    @Test("그 자리에서 되돌리면 메모가 그대로 돌아온다")
    func undoBringsThePaperBack() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")
        let model = makeModel(memo, store, paths)
        await model.delete()

        await model.restoreDeleted()

        #expect(model.justDeleted == nil)
        #expect(store.memo(memo.id)?.body == "치과 예약")
        #expect(store.trash.isEmpty)
    }

    @Test("지운 종이에는 더 적히지 않는다 — 휴지통 안의 파일에 쓰는 일이 된다")
    func deletedPaperStopsTakingText() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")
        let model = makeModel(memo, store, paths)
        await model.delete()

        model.text = "다른 글"
        model.edited("다른 글")
        await model.flush()

        // 되살린 것은 지울 때 그대로여야 한다.
        await model.restoreDeleted()
        #expect(store.memo(memo.id)?.body == "치과 예약")
    }

    /// 되살린 종이는 **있던 자리로** 돌아와야 한다. 지우는 순간 자리를
    /// 지워 버리면 되돌리기는 절반만 되돌린 것이 된다.
    @Test("휴지통에 있는 동안에도 창 자리는 남는다")
    func layoutSurvivesTheTrash() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")
        let layouts = LayoutStore(location: paths.layout)
        layouts.set(
            WindowLayout(frame: CGRect(x: 120, y: 240, width: 260, height: 200)), for: memo.id
        )

        try await store.delete(memo.id)
        layouts.prune(keeping: Set(store.memos.map(\.id)).union(store.trash.map(\.id)))

        #expect(layouts.layout(for: memo.id)?.x == 120)
    }

    // MARK: 달력 (`{#calendar-row-delete}`)

    @Test("달력 줄에서 지우면 바닥에 되돌리는 줄이 선다")
    func calendarRowCanDelete() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let today = CalendarDate(Date())
        let memo = try await store.create(body: "치과 예약", due: today)
        let model = CalendarModel(store: store)
        await model.refresh()
        #expect(model.selectedMemos.count == 1)

        await model.delete(memo)

        #expect(model.lastDeleted?.id == memo.id)
        // 달력에서도 사라져야 한다 — 지웠다는 말과 화면이 어긋나면 안 된다.
        #expect(model.selectedMemos.isEmpty)
        #expect(store.trash.contains { $0.id == memo.id })
    }

    @Test("달력에서 되돌리면 그 날로 돌아온다")
    func calendarUndoRestoresTheDay() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let today = CalendarDate(Date())
        let memo = try await store.create(body: "치과 예약", due: today)
        let model = CalendarModel(store: store)
        await model.refresh()
        await model.delete(memo)

        await model.restoreDeleted()

        #expect(model.lastDeleted == nil)
        #expect(model.selectedMemos.map(\.id) == [memo.id])
    }

    /// 바닥의 한 줄은 하나뿐이다. 방금 한 일이 둘이면 사람은 어느 것을
    /// 되돌리는지 모른다.
    @Test("지우기와 옮기기는 같은 줄을 두고 다투지 않는다")
    func onlyTheLastActionKeepsTheLine() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let today = CalendarDate(Date())
        let one = try await store.create(body: "치과 예약", due: today)
        let two = try await store.create(body: "은행", due: today)
        let model = CalendarModel(store: store)
        await model.refresh()

        await model.delete(one)
        #expect(model.lastDeleted != nil)

        await model.postpone(two)

        #expect(model.lastDeleted == nil)
        #expect(model.lastMove?.id == two.id)
    }

    /// 「종이로」는 언제 할지 모르겠다는 뜻이고 지우기는 안 하겠다는 뜻이다.
    @Test("지우기는 날짜 떼기와 다른 일이다")
    func deleteIsNotDetach() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let today = CalendarDate(Date())
        let memo = try await store.create(body: "치과 예약", due: today)
        let model = CalendarModel(store: store)
        await model.refresh()

        await model.detach(memo)

        // 날짜를 떼면 달력에서는 빠지지만 메모는 살아서 종이가 된다.
        #expect(store.memo(memo.id) != nil)
        #expect(store.trash.isEmpty)
    }
}
