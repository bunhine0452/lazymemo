import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 손이 얹힌 줄과 키보드로 고른 줄은 **다른 것이다** (설계문서 §8).
///
/// 예전에는 하나였다. 포인터가 목록 위를 지나가기만 해도 그 줄이 곧 선택이
/// 되었고, 그래서 세 줄 적다가 마우스가 스치면 ⌘⏎ 가 「적기 끝」에서
/// 「남의 메모 열기」로 바뀌었다 — **적던 글은 저장되지 않은 채로.** 같은
/// 상태에서 ⌘⌫ 는 가리키기만 한 메모를 휴지통으로 보냈다.
///
/// 화면으로는 구별할 수 없는 종류다. 줄이 밝아진 것까지는 맞게 보이고,
/// 틀린 것은 **그 다음에 키가 무엇을 하는가**뿐이라 그림에 나타나지 않는다.
/// 그래서 여기서 못 박는다.
@MainActor
@Suite("빠른 입력 — 손이 얹힌 줄과 고른 줄")
struct CaptureHoverTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-capture-hover-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    private func browsing(_ store: MemoStore) -> QuickCaptureModel {
        let model = QuickCaptureModel(store: store)
        model.prepareForShow()
        return model
    }

    @Test("스치기만 한 줄은 ⌘⏎ 를 가로채지 못한다 — 적던 글이 저장된다")
    func hoverDoesNotStealCommit() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "치과 예약")

        let model = browsing(store)
        model.query = "우유 사기"
        // 마우스가 목록 위를 지나갔다. 그게 전부다.
        model.pointed = model.listed[0].id

        guard case .create(let draft) = model.commit() else {
            Issue.record("스치기만 했는데 남의 메모를 열었다 — 적던 글을 잃는다")
            return
        }
        #expect(draft.text == "우유 사기")
    }

    @Test("스치기만 한 줄은 ⌘⌫ 로 지워지지 않는다 — 그 키는 글자를 지워야 한다")
    func hoverDoesNotArmDelete() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let target = try await store.create(body: "치과 예약")

        let model = browsing(store)
        model.pointed = target.id

        let view = QuickCaptureView(model: model, onCommit: {}, onCancel: {})
        let handled = view.handle(
            command: #selector(NSResponder.deleteToBeginningOfLine(_:)),
            in: NSTextView()
        )

        // true 를 돌려주면 그 키는 메모를 지운 것이다.
        #expect(!handled)
        try await Task.sleep(for: .milliseconds(150))
        #expect(store.trash.isEmpty)
        #expect(model.lastDeleted == nil)
    }

    @Test("줄을 직접 누른 것은 고른 것이다 — 스치는 것과 다르다")
    func tappingIsChoosing() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "치과 예약")

        let model = browsing(store)
        // 뷰의 탭 제스처가 하는 일 그대로.
        model.selection = 0

        guard case .open(let id) = model.commit() else {
            Issue.record("눌러서 고른 줄이 열리지 않았다")
            return
        }
        #expect(id == memo.id)
    }

    @Test("화살표로 고른 뒤 다른 줄을 스쳐도 ⌘⏎ 는 고른 줄을 연다")
    func hoverDoesNotMoveTheChoice() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "하나")
        _ = try await store.create(body: "둘")

        let model = browsing(store)
        model.moveSelection(1)
        let chosen = model.listed[0]

        model.pointed = model.listed[1].id

        #expect(model.selectedID == chosen.id)
        guard case .open(let id) = model.commit() else {
            Issue.record("고른 줄이 열리지 않았다")
            return
        }
        #expect(id == chosen.id)
    }

    @Test("포인터가 줄을 벗어나면 그 자국도 사라진다")
    func pointerLeavesNoResidue() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "하나")

        let model = browsing(store)
        model.pointed = model.listed[0].id
        model.pointed = nil

        #expect(model.pointed == nil)
        #expect(model.selection == nil)
    }

    @Test("스친 줄이 목록에서 사라지면 그 자국도 함께 놓는다")
    func dropsPointerWhenRowLeaves() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "치과 예약")
        let other = try await store.create(body: "전기요금")

        let model = browsing(store)
        model.pointed = other.id

        model.query = "치과"
        try await Task.sleep(for: .milliseconds(300))

        #expect(model.listed.count == 1)
        #expect(model.pointed == nil)
    }

    @Test("다시 열면 손도 키보드도 아무것도 가리키지 않는다")
    func reopeningClearsBoth() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "하나")

        let model = browsing(store)
        model.moveSelection(1)
        model.pointed = model.listed[0].id

        model.prepareForShow()

        #expect(model.selection == nil)
        #expect(model.pointed == nil)
    }
}
