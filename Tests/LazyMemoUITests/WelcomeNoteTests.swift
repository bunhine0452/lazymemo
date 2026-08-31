import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 처음 켠 사람에게 놓이는 첫 장 (`WelcomeNote`).
///
/// 이 앱은 메뉴바 아이콘 하나가 전부라, 단축키를 모르면 **앱이 있다는 것조차
/// 모른다.** 그렇다고 온보딩 화면을 지으면 철학 4("앱은 자기를 드러내지
/// 않는다")가 첫 화면에서 깨진다. 그래서 안내서를 앱이 아니라 메모로 준다.
///
/// 여기서 지킬 것은 하나 — **두 번 놓지 않는다.** 안내가 두 장이면 그건
/// 안내가 아니라 치울 거리다.
@MainActor
@Suite("첫 장 — 안내 종이")
struct WelcomeNoteTests {
    private func makeWorld() throws -> (MemoStore, SettingsStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-welcome-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoStore(paths: paths), SettingsStore(location: paths.settings), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    @Test("처음 켜면 종이 한 장이 놓여 있다")
    func greetsOnFirstLaunch() async throws {
        let (store, settings, paths) = try makeWorld()
        defer { cleanUp(paths) }

        await WelcomeNote.place(in: store, settings: settings)

        #expect(store.memos.count == 1)
        #expect(settings.current.greeted == true)
    }

    @Test("두 번 켜도 한 장이다")
    func greetsOnlyOnce() async throws {
        let (store, settings, paths) = try makeWorld()
        defer { cleanUp(paths) }

        await WelcomeNote.place(in: store, settings: settings)
        await WelcomeNote.place(in: store, settings: settings)

        #expect(store.memos.count == 1)
    }

    @Test("첫 장을 지운 사람에게 다시 놓지 않는다")
    func doesNotReturnAfterDeletion() async throws {
        let (store, settings, paths) = try makeWorld()
        defer { cleanUp(paths) }
        await WelcomeNote.place(in: store, settings: settings)
        let placed = try #require(store.memos.first)
        try await store.delete(placed.id)

        await WelcomeNote.place(in: store, settings: settings)

        #expect(store.memos.isEmpty)
    }

    @Test("쓰던 사람의 설정이 지워져도 안내가 끼어들지 않는다")
    func staysAwayFromExistingUsers() throws {
        // settings.json 은 파생물이라 지워질 수 있다 (§5.1). 그때 메모가 있는
        // 사람에게 안내 종이가 한 장 더 생기면 그건 안내가 아니라 치울 거리다.
        #expect(!WelcomeNote.shouldGreet(greeted: nil, memoCount: 12))
        #expect(WelcomeNote.shouldGreet(greeted: nil, memoCount: 0))
        #expect(!WelcomeNote.shouldGreet(greeted: true, memoCount: 0))
    }

    @Test("첫 장에 이 앱의 머리 동작이 전부 적혀 있다")
    func tellsWhatMatters() {
        let body = WelcomeNote.body
        // 단축키를 모르면 이 앱은 없는 것과 같다.
        #expect(body.contains("⌥⌘N"))
        // 형식을 배우지 않아도 된다는 것을 본보기 한 줄로 보인다.
        #expect(body.contains("내일 3시"))
        // 재부팅을 넘기는 스위치가 어디 있는지 (`LoginItem`).
        #expect(body.contains("로그인할 때 시작"))
        // 읽고 나면 지우면 된다 — 지우는 법까지 그 종이 안에.
        #expect(body.contains("휴지통"))
        // 눌러서 뒤집히는 것을 손으로 겪게 한다.
        #expect(body.contains("- [ ]"))
    }
}
