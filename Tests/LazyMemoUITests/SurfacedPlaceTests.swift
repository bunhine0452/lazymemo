import AppKit
import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 보는 것과 꺼내 두는 것을 가른다 (설계문서 §7.2).
///
/// §7.2 는 "날짜가 붙은 것은 달력이 맡는다" 고 정해 놓고, **사람이 정한 것은
/// 이긴다** 는 예외를 하나 두었다 — `layout.json` 에 기록이 있으면 그 뜻을
/// 따른다. 문제는 기록을 남기는 길이 하나뿐이었다는 것이다. 달력에서 일정을
/// **읽으려고** 누른 클릭도, 시각이 되어 앱이 스스로 꺼낸 종이도 같은 기록을
/// 남겼고, 그러면 그 일정은 날짜를 가진 채 **영영 바탕화면에 남는다.**
///
/// 화면으로는 구별되지 않는다 — 꺼내 준 종이와 영구히 꺼내 둔 종이가 똑같이
/// 생겼고, 틀린 것은 다음 날에야 드러난다.
@MainActor
@Suite("자리 — 꺼내 주는 것과 꺼내 두는 것")
struct SurfacedPlaceTests {
    private func makeWorld() throws -> (MemoStore, LayoutStore, NoteWindowManager, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-place-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let layouts = LayoutStore(location: paths.layout)
        let settings = SettingsStore(location: paths.settings)
        let windows = NoteWindowManager(
            store: store,
            layouts: layouts,
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: settings
            ),
            appearance: PaperAppearance(settings: settings)
        )
        return (store, layouts, windows, paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    private func tomorrow() -> Date {
        Date().addingTimeInterval(24 * 60 * 60)
    }

    @Test("시각이 되어 꺼내 준 종이는 자리를 옮기지 않는다")
    func surfacingKeepsThePlace() async throws {
        let (store, layouts, windows, paths) = try makeWorld()
        defer { cleanUp(paths) }
        let appointment = try await store.create(body: "치과", at: tomorrow())

        windows.surface(appointment.id)

        #expect(windows.isVisible(appointment.id))
        // 자리는 여전히 달력이다. `hidden == false` 로 적히면 §7.2 의 예외에
        // 걸려 이 일정은 날짜를 가진 채 영영 종이로 남는다.
        #expect(layouts.layout(for: appointment.id)?.hidden != false)
    }

    @Test("달력에서 읽으려고 누른 것도 자리를 옮기지 않는다")
    func readingFromCalendarKeepsThePlace() async throws {
        let (store, layouts, windows, paths) = try makeWorld()
        defer { cleanUp(paths) }
        let appointment = try await store.create(body: "치과", at: tomorrow())

        windows.reveal(appointment.id, activating: false, keepingPlace: true)

        #expect(windows.isVisible(appointment.id))
        #expect(layouts.layout(for: appointment.id)?.hidden != false)
    }

    @Test("메뉴 목록에서 여는 것은 꺼내 두는 일이다 — 그 목록은 찬 점·빈 점으로 그렇게 말한다")
    func revealingFromTheListRecordsIt() async throws {
        let (store, layouts, windows, paths) = try makeWorld()
        defer { cleanUp(paths) }
        let appointment = try await store.create(body: "치과", at: tomorrow())

        windows.reveal(appointment.id, activating: false)

        #expect(windows.isVisible(appointment.id))
        #expect(layouts.layout(for: appointment.id)?.hidden == false)
    }

    @Test("하루가 끝나면 꺼내 준 종이는 스스로 물러난다")
    func surfacedPaperSettlesAtMidnight() async throws {
        let (store, _, windows, paths) = try makeWorld()
        defer { cleanUp(paths) }
        let appointment = try await store.create(body: "치과", at: tomorrow())
        let plain = try await store.create(body: "그냥 메모")
        windows.sync()
        windows.surface(appointment.id)
        #expect(windows.isVisible(appointment.id))

        windows.clearSurfaced()

        // 일정은 달력에 맡기고 물러난다. 날짜 없는 종이는 그대로 있다 —
        // 그것은 꺼내 준 것이 아니라 원래 자리가 바탕화면이다.
        #expect(!windows.isVisible(appointment.id))
        #expect(windows.isVisible(plain.id))
    }

    @Test("사람이 치우면 꺼내 준 것도 끝난 일이다 — 다시 띄우지 않는다")
    func hidingEndsTheSurfacing() async throws {
        let (store, _, windows, paths) = try makeWorld()
        defer { cleanUp(paths) }
        let appointment = try await store.create(body: "치과", at: tomorrow())
        windows.surface(appointment.id)

        windows.hide(appointment.id)
        // 다음 동기화가 규칙을 무시하고 도로 띄우면, × 는 못 누르는 버튼이 된다.
        windows.sync()

        #expect(!windows.isVisible(appointment.id))
    }
}
