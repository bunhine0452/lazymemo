import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 빠른 입력에 사진을 붙여넣을 수 있는가.
///
/// 사용자가 겪은 결함: **빠른 입력에서만 ⌘V 가 죽었다.** 글자는 쳐지는데
/// 사진은 들어오지 않으니 "빠른 메모에는 사진을 못 붙인다" 로 보였다.
///
/// 까닭은 붙여넣기 자체가 아니라 **⌘V 가 글 상자까지 닿지 못한 것**이었다.
/// 표준 편집 단축키를 `NSApp.sendAction(_:to:nil:)` 으로 보내고 있었는데, 그
/// 함수는 대상을 **키 윈도의 응답 체인**에서 찾는다. 빠른 입력 상자는
/// `.nonactivatingPanel` 이라 앱이 활성이 아니면 키 윈도가 아예 없어
/// (`NSApp.keyWindow == nil`) 첫 응답자가 바로 그 텍스트 뷰인데도 대상을
/// 못 찾고 조용히 아무 일도 안 일어났다.
///
/// 그래서 여기서 재는 것은 **키 윈도가 없는 그 세상**이다 — 시험이 도는 동안
/// 앱은 활성이 아니므로 사용자가 겪은 상황과 같다.
@MainActor
@Suite("빠른 입력 — 사진 붙여넣기")
struct CapturePasteTests {
    private func makeController() throws -> QuickCaptureController {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-paste-\(UUID().uuidString)", directoryHint: .isDirectory)
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
        let controller = QuickCaptureController(store: store, windows: windows)
        controller.anchorProvider = { NSRect(x: 500, y: 900, width: 24, height: 22) }
        controller.resize()
        return controller
    }

    /// 사람이 쓰던 클립보드를 시험이 헤집지 않게 우리 붙임판을 쓴다.
    private func makePasteboard(named name: String) -> NSPasteboard {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()

        let png = image.tiffRepresentation
            .flatMap(NSBitmapImageRep.init(data:))
            .flatMap { $0.representation(using: .png, properties: [:]) }

        let board = NSPasteboard(name: NSPasteboard.Name(name))
        board.clearContents()
        board.setData(png, forType: .png)
        return board
    }

    private func commandV() -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: 0, context: nil,
            characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9
        )
    }

    @Test("⌘V 가 사진을 넣는다 — 키 윈도가 없어도")
    func pastesWithoutAKeyWindow() throws {
        let controller = try makeController()
        let editor = try #require(controller.editorForTesting)
        editor.pasteboard = makePasteboard(named: "lazymemo.test.paste")
        controller.focusForTesting()

        // 결함이 살던 세상인지 먼저 확인한다. 키 윈도가 있으면 이 시험은
        // 아무것도 지키지 못한다.
        #expect(NSApp.keyWindow == nil)

        let event = try #require(commandV())
        #expect(editor.performKeyEquivalent(with: event))

        #expect(controller.draftForTesting.contains("![](\(AttachmentStore.directoryName)/"))
    }

    @Test("붙인 사진은 조각으로 보인다 — 마크다운 글자만으로는 붙은 줄 모른다")
    func showsTheChip() throws {
        let controller = try makeController()
        let editor = try #require(controller.editorForTesting)
        editor.pasteboard = makePasteboard(named: "lazymemo.test.chip")
        controller.focusForTesting()

        let event = try #require(commandV())
        #expect(editor.performKeyEquivalent(with: event))

        #expect(controller.imagesForTesting.count == 1)
    }

    @Test("경로 글자는 감춘다 — 19pt 로 늘어놓으면 말풍선이 그것만으로 찬다")
    func hidesTheReference() throws {
        let controller = try makeController()
        let editor = try #require(controller.editorForTesting)
        editor.pasteboard = makePasteboard(named: "lazymemo.test.hidden")
        controller.typeForTesting("치과")
        controller.focusForTesting()
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))

        let event = try #require(commandV())
        #expect(editor.performKeyEquivalent(with: event))

        let storage = try #require(editor.textStorage)
        let source = editor.string as NSString
        let reference = source.range(of: "![](")
        try #require(reference.location != NSNotFound)
        let hidden = storage.attribute(.font, at: reference.location, effectiveRange: nil) as? NSFont
        // 지우지는 않는다 (D4). 보이지 않을 만큼 작을 뿐이다.
        #expect(hidden?.pointSize ?? 99 < 1)
        #expect(editor.string.contains("![]("))

        // 적던 글은 그대로여야 한다 — 감추는 것은 경로 하나뿐이다.
        let typed = source.range(of: "치과")
        try #require(typed.location != NSNotFound)
        let body = storage.attribute(.font, at: typed.location, effectiveRange: nil) as? NSFont
        #expect(body?.pointSize == editor.baseFont.pointSize)
    }

    @Test("끌어놓기가 받는 형식은 붙여넣기와 같다")
    func dragAcceptsWhatPasteAccepts() {
        let types = MemoNSTextView.draggedTypes
        #expect(types.contains(.fileURL))
        #expect(types.contains(.png))
        #expect(types.contains(.tiff))
        #expect(types.contains(NSPasteboard.PasteboardType("public.jpeg")))
        #expect(types.contains(NSPasteboard.PasteboardType("public.heic")))
    }
}
