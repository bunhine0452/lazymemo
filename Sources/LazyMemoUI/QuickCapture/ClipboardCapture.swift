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
    var onScheduled: (CalendarDate) -> Void = { _ in }

    init(
        store: MemoStore,
        windows: NoteWindowManager,
        onScheduled: @escaping (CalendarDate) -> Void = { _ in }
    ) {
        self.store = store
        self.windows = windows
        self.onScheduled = onScheduled
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

        // 자연어 날짜/시간 파싱
        let schedule = NaturalDateParser.parse(text)
        let body = if let schedule {
            NaturalDateParser.strip(schedule.phrases, from: text)
        } else {
            text
        }

        let finalBody = body.isEmpty ? text : body
        guard let memo = try? await store.create(
            body: finalBody,
            due: schedule?.due,
            at: schedule?.at
        ) else { return nil }

        announce(memo)
        return memo
    }

    private func announce(_ memo: Memo) {
        guard let day = Schedule(memo).day() else {
            windows.announce(memo)
            return
        }
        onScheduled(day)
    }
}
