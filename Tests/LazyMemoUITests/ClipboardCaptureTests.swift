import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 클립보드 원키 즉시 캡처 (⌥⌘V) 단위 시험.
@MainActor
@Suite("클립보드 즉시 캡처 (⌥⌘V)")
struct ClipboardCaptureTests {
    private func makeEnvironment() throws -> (store: MemoStore, windows: NoteWindowManager, capture: ClipboardCapture) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-clip-\(UUID().uuidString)", directoryHint: .isDirectory)
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
        let capture = ClipboardCapture(store: store, windows: windows)
        return (store, windows, capture)
    }

    private func makeTextPasteboard(_ text: String, name: String) -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name(name))
        board.clearContents()
        board.setString(text, forType: .string)
        return board
    }

    private func makeImagePasteboard(name: String) -> NSPasteboard {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 10, height: 10)).fill()
        image.unlockFocus()

        let png = image.tiffRepresentation
            .flatMap(NSBitmapImageRep.init(data:))
            .flatMap { $0.representation(using: .png, properties: [:]) }

        let board = NSPasteboard(name: NSPasteboard.Name(name))
        board.clearContents()
        if let png {
            board.setData(png, forType: .png)
        }
        return board
    }

    @Test("클립보드의 텍스트를 즉시 새 메모로 생성한다")
    func capturesPlainText() async throws {
        let env = try makeEnvironment()
        let board = makeTextPasteboard("장보기 목록: 사과, 바나나, 우유", name: "test.clip.text")

        let memo = try #require(await env.capture.capture(from: board))
        #expect(memo.body == "장보기 목록: 사과, 바나나, 우유")
        #expect(memo.due == nil)
        #expect(memo.at == nil)
        #expect(env.store.active.contains { $0.id == memo.id })
    }

    @Test("텍스트에 날짜/시간이 있으면 일정을 자동으로 추출한다")
    func capturesScheduledText() async throws {
        let env = try makeEnvironment()
        let board = makeTextPasteboard("내일 오후 3시 치과 예약", name: "test.clip.schedule")

        let memo = try #require(await env.capture.capture(from: board))
        #expect(memo.isScheduled)
        #expect(memo.body.contains("치과 예약"))
    }

    @Test("클립보드에 이미지가 있으면 첨부파일로 저장하고 마크다운을 생성한다")
    func capturesImage() async throws {
        let env = try makeEnvironment()
        let board = makeImagePasteboard(name: "test.clip.image")

        let memo = try #require(await env.capture.capture(from: board))
        #expect(memo.body.contains("![](\(AttachmentStore.directoryName)/"))
        #expect(memo.body.contains(".png)"))
    }

    @Test("클립보드가 비어있거나 공백뿐이면 아무 메모도 생성하지 않는다")
    func ignoresEmptyClipboard() async throws {
        let env = try makeEnvironment()
        let board = makeTextPasteboard("   \n\t  ", name: "test.clip.empty")

        let memo = await env.capture.capture(from: board)
        #expect(memo == nil)
        #expect(env.store.active.isEmpty)
    }
}
