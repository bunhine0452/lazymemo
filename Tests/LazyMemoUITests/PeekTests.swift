import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 「종이 보기」 — 바탕화면의 종이를 전부 잠깐 앞에 세우고, 다시 누르면 내려앉는다 (`NoteWindowManager.peek`).
///
/// 종이는 바탕화면 높이에 눕는 것이 이 앱의 뜻이지만 하루의 대부분 바탕화면은 브라우저 뒤다.
/// 한 키로 전부 앞에 서지 않으면 「내가 뭘 적어 뒀더라」의 답이 창을 치우는 손짓 뒤에만 있다.
@MainActor
@Suite("종이 보기")
struct PeekTests {
    private func makeWindows() throws -> (MemoStore, NoteWindowManager) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-peek-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let windows = NoteWindowManager(
            store: store,
            layouts: LayoutStore(location: paths.layout),
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: settings
            ),
            appearance: PaperAppearance(settings: settings)
        )
        return (store, windows)
    }

    @Test("한 번 누르면 전부 앞에 서고, 다시 누르면 전부 내려앉는다 — 포커스는 그대로")
    func raisesAllThenSettles() async throws {
        let (store, windows) = try makeWindows()
        let first = try await store.create(body: "장보기")
        let second = try await store.create(body: "치과 예약")
        let a = windows.open(first, activating: false)
        let b = windows.open(second, activating: false)
        defer { a.hide(); b.hide() }
        #expect(a.window.level == DesktopLevelWindow.desktopLevel)

        #expect(windows.peek(for: .seconds(30)) == 2)
        #expect(a.window.level == DesktopLevelWindow.focusedLevel)
        #expect(b.window.level == DesktopLevelWindow.focusedLevel)
        #expect(!a.window.isKeyWindow && !b.window.isKeyWindow, "보는 것이지 손을 옮기는 것이 아니다")

        #expect(windows.peek() == 2)
        #expect(a.window.level == DesktopLevelWindow.desktopLevel)
        #expect(b.window.level == DesktopLevelWindow.desktopLevel)
    }

    @Test("시간이 지나면 스스로 내려앉는다")
    func settlesOnItsOwn() async throws {
        let (store, windows) = try makeWindows()
        let memo = try await store.create(body: "우유")
        let controller = windows.open(memo, activating: false)
        defer { controller.hide() }

        windows.peek(for: .milliseconds(80))
        #expect(controller.window.level == DesktopLevelWindow.focusedLevel)
        await settle("종이가 내려앉는다") { controller.window.level == DesktopLevelWindow.desktopLevel }
    }

    @Test("종이가 한 장도 없으면 0 — 부르는 쪽이 그렇다고 말할 수 있게")
    func nothingToPeek() throws {
        let (_, windows) = try makeWindows()
        #expect(windows.peek() == 0)
    }

    @Test("치운 종이는 세우지 않는다 — 서랍에 든 것은 바탕화면의 것이 아니다")
    func hiddenPapersStayDown() async throws {
        let (store, windows) = try makeWindows()
        let shown = try await store.create(body: "보이는 것")
        let hidden = try await store.create(body: "치운 것")
        let a = windows.open(shown, activating: false)
        _ = windows.open(hidden, activating: false)
        windows.hide(hidden.id)
        defer { a.hide() }
        #expect(windows.peek(for: .seconds(30)) == 1)
        windows.peek()
    }
}
