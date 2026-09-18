import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 종이가 글에 맞춰 자라는 길이 **실제 창까지 닿는가**.
///
/// 계산은 `PaperFitTests` 가 지킨다. 그런데 계산이 맞아도 재는 자리(텍스트 뷰의
/// 배치)나 거는 자리(콜백)가 끊기면 화면에서는 아무 일도 안 일어난다 — 그 둘을
/// 여기서 한 번에 지난다. 창을 화면 밖(-3000)에 띄우는 것은 사람의 화면을
/// 건드리지 않기 위해서다.
@MainActor
@Suite("종이 — 창이 실제로 자란다")
struct PaperFitWindowTests {
    private func makeController(body: String, frame: NSRect) async throws -> (NoteWindowController, URL) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-fit-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let previews = LinkPreviewStore(
            cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
            settings: settings
        )
        let memo = try await store.create(body: body)
        let controller = NoteWindowController(
            memo: memo, store: store, previews: previews,
            appearance: PaperAppearance(settings: settings),
            frame: frame, onFrameChange: { _, _ in }, onCloseRequest: { _ in }
        )
        controller.show()
        // SwiftUI 가 한 번 배치를 끝내야 글 칸의 자리가 생긴다.
        controller.window.layoutIfNeeded()
        return (controller, root)
    }

    private func longBody(lines: Int = 40) -> String {
        (1...lines).map { "\($0) 번째 줄이다. 붙여 넣은 글은 대개 이만큼 길다." }.joined(separator: "\n")
    }

    /// 윗변이 제자리에 남는 것은 `PaperFitTests` 가 지킨다 — 여기 창은 화면 밖에 있어
    /// 화면 안으로 끌려 들어오므로 자리로는 확인할 수 없다. 여기서 보는 것은 **자라는가**다.
    @Test("긴 글이 든 종이는 열자마자 자란다")
    func longMemoGrows() async throws {
        let frame = NSRect(x: -3000, y: -2000, width: 260, height: 200)
        let (controller, root) = try await makeController(body: longBody(), frame: frame)
        defer { controller.window.orderOut(nil); try? FileManager.default.removeItem(at: root) }

        controller.fitToContent()
        // 자라는 것은 짧은 애니메이션이다 — 끝나기를 기다린다.
        await settle("종이가 안 자랐다") { controller.frame.height > frame.height }
        #expect(controller.frame.height > frame.height)
    }

    @Test("짧은 글은 그대로 — 한 줄 메모가 창을 흔들지 않는다")
    func shortMemoStays() async throws {
        let frame = NSRect(x: -3000, y: -2000, width: 260, height: 200)
        let (controller, root) = try await makeController(body: "치과 예약", frame: frame)
        defer { controller.window.orderOut(nil); try? FileManager.default.removeItem(at: root) }

        controller.fitToContent()
        try? await Task.sleep(for: .milliseconds(400))
        #expect(controller.frame == frame)
    }

    @Test("손으로 맞춰 둔 크기로 열린 종이는 조금 넘친다고 안 자란다")
    func handSizedIsLeftAlone() async throws {
        // 앱이 내놓는 크기가 아니다 = 사람이 정한 것으로 본다 (`PaperFit.looksAppSized`).
        let frame = NSRect(x: -3000, y: -2000, width: 420, height: 460)
        let (controller, root) = try await makeController(body: longBody(lines: 16), frame: frame)
        defer { controller.window.orderOut(nil); try? FileManager.default.removeItem(at: root) }

        controller.fitToContent()
        try? await Task.sleep(for: .milliseconds(400))
        #expect(controller.frame == frame)
    }
}
