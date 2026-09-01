import AppKit
import LazyMemoCore

/// 클립보드 원키 즉시 캡처 (⌥⌘V).
///
/// 게으른 사용자를 위한 가장 빠른 캡처 동선:
/// 창을 열고, 커서를 옮기고, ⌘V를 누르고, ⌘⏎를 누를 필요 없이
/// 어느 앱에서든 복사(⌘C) 후 ⌥⌘V 단 한 번으로 바탕화면에 새 메모가 생성되고 잠깐 떠오른다.
@MainActor
final class ClipboardCapture {
    private let store: MemoStore
    private let windows: NoteWindowManager
    private let door: InboundDoor
    var onScheduled: (CalendarDate) -> Void = { _ in } {
        didSet { door.onScheduled = onScheduled }
    }

    init(
        store: MemoStore,
        windows: NoteWindowManager,
        door: InboundDoor? = nil,
        onScheduled: @escaping (CalendarDate) -> Void = { _ in }
    ) {
        self.store = store
        self.windows = windows
        self.door = door ?? InboundDoor(store: store, windows: windows)
        self.onScheduled = onScheduled
        self.door.onScheduled = onScheduled
    }

    /// 클립보드의 내용(텍스트 또는 이미지)을 즉시 메모로 저장하고 안내한다.
    @discardableResult
    func capture(from pasteboard: NSPasteboard = .general) async -> Memo? {
        // 1. 이미지 데이터 확인 (PNG / TIFF / JPEG)
        if let imageType = pasteboard.types?.first(where: {
            $0 == .png || $0 == .tiff || $0 == NSPasteboard.PasteboardType("public.jpeg")
        }), let data = pasteboard.data(forType: imageType) {
            let ext = imageType == .png ? "png" : (imageType == .tiff ? "tiff" : "jpg")
            if let path = try? store.attachments.save(data, fileExtension: ext) {
                let optionalText = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let body: String
                if let optionalText, !optionalText.isEmpty {
                    body = "\(optionalText)\n\n![](\(path))"
                } else {
                    body = "![](\(path))"
                }

                if let memo = try? await store.create(body: body) {
                    announce(memo)
                    return memo
                }
            }
        }

        // 2. 텍스트 확인
        guard let rawText = pasteboard.string(forType: .string) else { return nil }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // 읽는 규칙은 문마다 다르지 않다 — 날짜도 장소도 `InboundDoor` 가 읽는다.
        // 복사해 온 주소가 그대로 장소가 되는 것이 이 갈래의 값이다.
        return await door.receive(text: text)
    }

    private func announce(_ memo: Memo) {
        guard let day = Schedule(memo).day() else {
            windows.announce(memo)
            return
        }
        onScheduled(day)
    }
}
