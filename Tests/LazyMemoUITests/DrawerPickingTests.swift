import CoreGraphics
import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 서랍 안에서 **여러 장을 한꺼번에**, **폴더**, 그리고 **한 겹씩 되돌리기.**
///
/// 화면으로는 확인할 수 없는 것들이다. 「고른 세 장을 꺼냈다」와 「고른 세 장
/// 중 둘만 꺼냈다」는 그림이 같고(둘 다 목록이 줄어든다), esc 가 몇 겹을
/// 벗겼는지는 렌더에 아무 흔적도 남기지 않는다 (§14.9).
@MainActor
@Suite("서랍 — 고르기·폴더·되돌리기")
struct DrawerPickingTests {

    /// 창고 하나에 날짜 없는 종이 몇 장. **전부 치운 것으로 친다** — 좌표
    /// 파일이 없는 시험에서는 「사람이 치웠는가」를 물을 곳이 없다.
    private func drawer(
        _ bodies: [String], folders: [String] = []
    ) async throws -> (DrawerModel, MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-drawer-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        for body in bodies { _ = try await store.create(body: body) }
        return (DrawerModel(store: store, putAway: { _ in true }, folders: folders), store, paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    /// 파일에 적히는 일은 비동기다 — 시간이 아니라 조건을 기다린다.
    private func settle(until: () -> Bool) async {
        for _ in 0..<80 {
            if until() { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func id(of title: String, in model: DrawerModel) -> ULID? {
        model.papers.first { $0.title == title }?.id
    }

    // MARK: 고르기

    @Test("고르고 다시 누르면 놓는다")
    func pickingTogglesOne() async throws {
        let (model, _, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        let first = try #require(model.shown.first?.id)

        model.pick(first)
        #expect(model.picked == [first])
        model.pick(first)
        #expect(model.picked.isEmpty)
    }

    @Test("고른 것이 없으면 아무 말도 하지 않는다 — 「0장 골랐습니다」는 말이 아니다")
    func silentWithNothingPicked() async throws {
        let (model, _, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        #expect(model.pickedLabel == nil)
        model.pick(try #require(model.shown.first?.id))
        #expect(model.pickedLabel == "1장 골랐습니다")
    }

    /// 집합이 주는 차례대로 꺼내면 꺼낼 때마다 순서가 달라지고, 그러면
    /// «되돌렸다» 가 아니라 «흩뿌렸다» 가 된다.
    @Test("한꺼번에 꺼낼 때 차례는 목록에 놓인 그대로다")
    func takingOutKeepsListOrder() async throws {
        let (model, _, paths) = try await drawer(["하나", "둘", "셋", "넷"])
        defer { cleanUp(paths) }
        var takenOut: [ULID] = []
        model.onTakeOut = { takenOut.append($0) }

        let order = model.shown.map(\.id)
        for id in [order[2], order[0], order[3]] { model.pick(id) }
        model.takeOutPicked()

        #expect(takenOut == [order[0], order[2], order[3]])
        #expect(model.picked.isEmpty)
    }

    @Test("한꺼번에 지우면 고른 것만, 전부 지운다")
    func deletingPickedDeletesExactlyThose() async throws {
        let (model, _, paths) = try await drawer(["하나", "둘", "셋"])
        defer { cleanUp(paths) }
        var deleted: Set<ULID> = []
        model.onDelete = { deleted.insert($0) }

        let order = model.shown.map(\.id)
        model.pick(order[0])
        model.pick(order[2])
        model.deletePicked()

        #expect(deleted == [order[0], order[2]])
        #expect(model.picked.isEmpty)
    }

    /// **화면에 없는 종이에 조작이 걸리면 안 된다.**
    @Test("찾기로 걸러진 줄은 고르기에서도 빠진다")
    func filteringDropsPicked() async throws {
        let (model, _, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        let dentist = try #require(id(of: "치과", in: model))
        let groceries = try #require(id(of: "장보기", in: model))
        model.pick(dentist)
        model.pick(groceries)
        #expect(model.picked.count == 2)

        model.query = "치과"
        #expect(model.picked == [dentist])
    }

    @Test("짚어 둔 줄도 걸러지면 놓는다")
    func filteringDropsFocus() async throws {
        let (model, _, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        model.focused = try #require(id(of: "장보기", in: model))
        model.query = "치과"
        #expect(model.focused == nil)
    }

    // MARK: 폴더

    @Test("폴더를 만들면 그 폴더를 보고, 설정에 적을 차례를 돌려준다")
    func creatingAFolderSelectsIt() async throws {
        let (model, _, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        var saved: [String]?
        model.onFoldersChanged = { saved = $0 }

        #expect(model.createFolder("  집 "))
        #expect(model.folders == ["집"])
        #expect(model.selectedFolder == "집")
        #expect(saved == ["집"])
        #expect(!model.isNamingFolder)

        // 빈 이름은 폴더가 아니다.
        #expect(!model.createFolder("   "))
        #expect(model.folders == ["집"])
    }

    @Test("폴더로 옮기면 파일에 이름표가 적히고, 그 칸에서만 보인다")
    func movingWritesTheLabel() async throws {
        let (model, store, paths) = try await drawer(["장보기", "치과"], folders: ["집"])
        defer { cleanUp(paths) }
        let groceries = try #require(id(of: "장보기", in: model))

        model.move(groceries, to: "집")
        await settle { store.memo(groceries)?.folder == "집" }
        model.refresh()

        #expect(try #require(store.memo(groceries)).folder == "집")
        #expect(model.counts == ["집": 1])
        model.selectedFolder = "집"
        #expect(model.shown.map(\.id) == [groceries])
        model.selectedFolder = nil
        #expect(model.shown.count == 2)
    }

    /// 메모에만 적힌 이름표도 폴더다 — 다른 컴퓨터에서 왔거나 Claude 가 적었거나.
    @Test("설정에 없는 이름표도 폴더로 보인다")
    func unlistedLabelsShowAsFolders() async throws {
        let (model, store, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        let groceries = try #require(id(of: "장보기", in: model))
        _ = try await store.update(groceries, folder: .some("낯선 폴더"))
        model.refresh()
        #expect(model.folders == ["낯선 폴더"])
    }

    /// 「장보기」를 펼쳐 놓고 종이를 끌어다 놓았는데 「전체」에만 떨어지면,
    /// 사람은 자기가 겨눈 자리에 놓이지 않은 것으로 본다.
    @Test("폴더를 보는 중에 들어온 종이는 그 폴더로 간다")
    func receivedPaperJoinsTheOpenFolder() async throws {
        let (model, store, paths) = try await drawer(["장보기", "치과"], folders: ["집"])
        defer { cleanUp(paths) }
        let dentistID = try #require(id(of: "치과", in: model))
        let dentist = try #require(store.memo(dentistID))

        model.setOpen(true)
        model.selectedFolder = "집"
        model.received(dentist)
        await settle { store.memo(dentist.id)?.folder == "집" }
        #expect(store.memo(dentist.id)?.folder == "집")

        // 「전체」를 보는 중이면 이름표를 달지 않는다.
        let groceriesID = try #require(id(of: "장보기", in: model))
        let groceries = try #require(store.memo(groceriesID))
        model.selectedFolder = nil
        model.received(groceries)
        try? await Task.sleep(for: .milliseconds(150))
        #expect(store.memo(groceries.id)?.folder == nil)
    }

    @Test("이름을 바꾸면 그 이름표를 단 종이가 전부 따라간다")
    func renamingCarriesTheLabels() async throws {
        let (model, store, paths) = try await drawer(["장보기", "치과"], folders: ["집"])
        defer { cleanUp(paths) }
        let groceries = try #require(id(of: "장보기", in: model))
        _ = try await store.update(groceries, folder: .some("집"))
        model.refresh()
        model.selectedFolder = "집"

        #expect(model.renameFolder("집", to: "우리 집"))
        await settle { store.memo(groceries)?.folder == "우리 집" }
        #expect(store.memo(groceries)?.folder == "우리 집")
        #expect(model.selectedFolder == "우리 집")
        #expect(model.folders == ["우리 집"])

        // 빈 이름이나 겹치는 이름은 거절한다 — 그리고 바꾸던 상태를 끝낸다.
        model.renamingFolder = "우리 집"
        #expect(!model.renameFolder("우리 집", to: " "))
        #expect(model.renamingFolder == nil)
    }

    /// 폴더를 지우는 것이 메모를 지우는 길이 되면 안 된다.
    @Test("폴더를 지워도 종이는 서랍에 남는다 — 이름표만 뗀다")
    func deletingAFolderKeepsThePapers() async throws {
        let (model, store, paths) = try await drawer(["장보기", "치과"], folders: ["집"])
        defer { cleanUp(paths) }
        let groceries = try #require(id(of: "장보기", in: model))
        _ = try await store.update(groceries, folder: .some("집"))
        model.refresh()
        model.selectedFolder = "집"

        model.deleteFolder("집")
        await settle { store.memo(groceries)?.folder == nil }
        #expect(store.memo(groceries)?.folder == nil)
        #expect(model.folders.isEmpty)
        #expect(model.selectedFolder == nil)
        #expect(model.total == 2)
    }

    @Test("Tab 은 「전체」→ 폴더들 → 「전체」로 감아 돈다")
    func tabCyclesFolders() async throws {
        let (model, _, paths) = try await drawer(["장보기"], folders: ["집", "읽을 것"])
        defer { cleanUp(paths) }
        #expect(model.selectedFolder == nil)
        model.stepFolder(1)
        #expect(model.selectedFolder == "집")
        model.stepFolder(1)
        #expect(model.selectedFolder == "읽을 것")
        model.stepFolder(1)
        #expect(model.selectedFolder == nil)
        model.stepFolder(-1)
        #expect(model.selectedFolder == "읽을 것")
    }

    @Test("폴더가 없으면 Tab 은 흘려보낸다")
    func tabIsIgnoredWithoutFolders() async throws {
        let (model, _, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        #expect(!model.handle(.folder(1)))
    }

    // MARK: 키보드로 훑기

    @Test("아무것도 안 짚었을 때 ↓ 는 맨 위부터, ↑ 는 맨 아래부터")
    func firstMoveEntersTheList() async throws {
        let (model, _, paths) = try await drawer(["하나", "둘", "셋"])
        defer { cleanUp(paths) }
        let order = model.shown.map(\.id)

        model.moveFocus(by: 1)
        #expect(model.focused == order.first)

        model.focused = nil
        model.moveFocus(by: -1)
        #expect(model.focused == order.last)
    }

    /// 끝에서 한 번 더 눌러도 **넘어가지 않는다.** 목록을 감아 돌면 사람은
    /// 자기가 끝에 닿았다는 것을 알 수 없다.
    @Test("목록 끝에서는 멈춘다")
    func focusStopsAtTheEdges() async throws {
        let (model, _, paths) = try await drawer(["하나", "둘"])
        defer { cleanUp(paths) }
        let order = model.shown.map(\.id)

        model.focused = order.last
        model.moveFocus(by: 1)
        #expect(model.focused == order.last)

        model.focused = order.first
        model.moveFocus(by: -1)
        #expect(model.focused == order.first)
    }

    @Test("↩ 는 짚은 줄을 펼치고, 한 번 더 누르면 접는다")
    func returnTogglesTheRow() async throws {
        let (model, _, paths) = try await drawer(["하나", "둘"])
        defer { cleanUp(paths) }
        let first = try #require(model.shown.first?.id)
        model.focused = first
        #expect(model.handle(.zoom))
        #expect(model.expanded == first)
        #expect(model.handle(.zoom))
        #expect(model.expanded == nil)
    }

    // MARK: 한 겹씩 되돌리기

    /// esc 한 번에 전부 지우면 세 글자를 찾다가 한 번 잘못 눌렀을 때 서랍이
    /// 통째로 닫힌다. 한 겹씩 벗겨야 되돌리기가 예측된다.
    @Test("esc 는 고르기 → 찾기 → 펼친 줄 → 짚은 자리 → 폴더 → 서랍 차례로 벗긴다")
    func escapePeelsOneLayerAtATime() async throws {
        let (model, _, paths) = try await drawer(["장보기", "치과"], folders: ["집"])
        defer { cleanUp(paths) }
        let first = try #require(model.shown.first?.id)

        model.setOpen(true)
        model.selectedFolder = nil
        model.query = "장"
        model.zoom(first)
        model.pick(first)
        model.selectedFolder = nil
        // 폴더 겹은 마지막에 건다 — 고르면 목록이 그 칸으로 좁혀지므로 먼저 걸면 나머지가 빠진다.

        model.escape()
        #expect(model.picked.isEmpty)
        #expect(model.isSearching)

        model.escape()
        #expect(!model.isSearching)
        #expect(model.expanded == first)

        model.escape()
        #expect(model.expanded == nil)
        #expect(model.focused == first)

        model.escape()
        #expect(model.focused == nil)
        #expect(model.isOpen)

        model.selectedFolder = "집"
        model.escape()
        #expect(model.selectedFolder == nil)
        #expect(model.isOpen)

        model.escape()
        #expect(!model.isOpen)
    }

    @Test("이름을 적는 중의 esc 는 그것부터 그만둔다")
    func escapeCancelsNamingFirst() async throws {
        let (model, _, paths) = try await drawer(["장보기"])
        defer { cleanUp(paths) }
        model.setOpen(true)
        model.query = "장"
        model.isNamingFolder = true

        model.escape()
        #expect(!model.isNamingFolder)
        #expect(model.isSearching)
    }

    @Test("벗길 겹이 남았으면 esc 가 서랍을 닫지 않는다")
    func escapeWouldCloseOnlyAtTheBottom() async throws {
        let (model, _, paths) = try await drawer(["장보기"], folders: ["집"])
        defer { cleanUp(paths) }
        model.setOpen(true)
        #expect(model.escapeWouldClose)

        model.query = "장"
        #expect(!model.escapeWouldClose)
        model.query = ""
        model.selectedFolder = "집"
        #expect(!model.escapeWouldClose)
    }

    /// 서랍은 늘 같은 모습으로 열린다 — **보던 폴더만 빼고.** 폴더는 상태가
    /// 아니라 자리다.
    @Test("접으면 찾던 글자도 고른 것도 펼친 줄도 놓지만, 보던 폴더는 남는다")
    func closingPutsEverythingDownExceptTheFolder() async throws {
        let (model, store, paths) = try await drawer(["종이 1", "종이 2"], folders: ["집"])
        defer { cleanUp(paths) }
        for memo in store.memos { _ = try await store.update(memo.id, folder: .some("집")) }
        model.refresh()

        model.setOpen(true)
        model.selectedFolder = "집"
        model.query = "종이"
        model.pick(try #require(model.shown.first?.id))
        model.zoom(try #require(model.shown.last?.id))
        model.isNamingFolder = true

        model.setOpen(false)
        #expect(model.query.isEmpty)
        #expect(model.picked.isEmpty)
        #expect(model.focused == nil)
        #expect(model.expanded == nil)
        #expect(!model.isNamingFolder)
        #expect(model.selectedFolder == "집")
    }

    // MARK: 키 하나가 실제로 하는 일

    /// **「무엇에」가 없는 동작은 사람이 겨눈 적이 없는 동작이다.**
    @Test("짚은 것이 없으면 ↩·⌘↩·⌘⌫ 는 아무 일도 하지 않는다")
    func keysWithoutATargetDoNothing() async throws {
        let (model, _, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        var touched = 0
        model.onDelete = { _ in touched += 1 }
        model.onTakeOut = { _ in touched += 1 }

        #expect(!model.handle(.zoom))
        #expect(!model.handle(.takeOut))
        #expect(!model.handle(.delete))
        #expect(touched == 0)
    }

    @Test("짚은 줄에 ⌘↩ 는 꺼내고 ⌘⌫ 는 지운다")
    func keysActOnTheAimedRow() async throws {
        let (model, _, paths) = try await drawer(["장보기", "치과"])
        defer { cleanUp(paths) }
        var takenOut: [ULID] = []
        var deleted: [ULID] = []
        model.onTakeOut = { takenOut.append($0) }
        model.onDelete = { deleted.append($0) }

        let groceries = try #require(id(of: "장보기", in: model))
        model.focused = groceries
        #expect(model.handle(.takeOut))
        #expect(takenOut == [groceries])

        let dentist = try #require(id(of: "치과", in: model))
        model.focused = dentist
        #expect(model.handle(.delete))
        #expect(deleted == [dentist])
    }

    /// 고른 것이 있으면 **고른 것이 이긴다.**
    @Test("고른 것이 있으면 ⌘⌫ 는 고른 것 전부에 걸린다")
    func pickedWinsOverAimed() async throws {
        let (model, _, paths) = try await drawer(["하나", "둘", "셋"])
        defer { cleanUp(paths) }
        var deleted: Set<ULID> = []
        model.onDelete = { deleted.insert($0) }

        let order = model.shown.map(\.id)
        model.focused = order[0]
        model.pick(order[1])
        model.pick(order[2])

        #expect(model.handle(.delete))
        #expect(deleted == [order[1], order[2]])
    }
}
