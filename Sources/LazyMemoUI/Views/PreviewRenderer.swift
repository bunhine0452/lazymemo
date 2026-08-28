import AppKit
import LazyMemoCore
import SwiftUI

/// 실제 뷰를 PNG 로 렌더한다 (`LAZYMEMO_RENDER=<디렉터리>`).
///
/// 화면 기록 권한 없이 UI 를 눈으로 확인하기 위한 통로다. 목업이 아니라
/// **앱이 쓰는 그 뷰**를 그리므로, 여기서 어긋나 보이면 화면에서도 어긋난다.
///
/// 한 가지 한계: `glassEffect` 는 뒤 배경을 흐리는 재질이라 화면 밖 렌더에서는
/// 흐림이 빠진다. 색과 배치는 정확하고 질감만 실제보다 밋밋하다.
@MainActor
enum PreviewRenderer {
    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("[render] \(message)\n".utf8))
    }

    static func renderAll(into directory: URL, store: MemoStore) async {
        log("표본 생성")
        let samples = await makeSamples(store: store)
        log("표본 완료")

        // 모델을 먼저 만들고 잠깐 기다린다 — 붙인 사진을 파일에서 불러오는
        // 일이 비동기라, 만들자마자 그리면 그림이 아직 없다.
        let scheduled = NoteModel(memo: samples.scheduled, store: store)
        let plain = NoteModel(memo: samples.plain, store: store)
        try? await Task.sleep(for: .milliseconds(300))

        await render(
            name: "note",
            size: CGSize(width: 268, height: 200),
            content: NoteView(model: scheduled, onClose: {}),
            into: directory
        )
        await render(
            name: "note-plain",
            size: CGSize(width: 300, height: 430),
            content: NoteView(model: plain, onClose: {}),
            into: directory
        )

        let capture = QuickCaptureModel(store: store)
        capture.query = "내일 오후 3시 치과"
        // 검색은 디바운스가 걸려 있어 결과가 채워질 때까지 잠깐 기다린다.
        try? await Task.sleep(for: .milliseconds(400))
        log("capture.query=[\(capture.query)] len=\(capture.query.count) label=\(capture.scheduleLabel ?? "-")")
        await render(
            name: "capture",
            size: CGSize(width: QuickCaptureController.width, height: 230),
            content: QuickCaptureView(model: capture, onCommit: {}, onCancel: {}),
            into: directory
        )

        let stream = StreamModel(store: store)
        await stream.refresh()
        log("stream.days=\(stream.days.count)")
        await render(
            name: "stream",
            size: CGSize(width: 268, height: 420),
            content: StreamView(model: stream, onClose: {}, onSelectMemo: { _ in }),
            into: directory
        )
    }

    // MARK: 표본

    private struct Samples {
        let scheduled: Memo
        let plain: Memo
    }

    private static func makeSamples(store: MemoStore) async -> Samples {
        let calendar = Calendar.current
        let appointment = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 14, minute: 30)
        ) ?? Date()

        let scheduled = (try? await store.create(
            body: "치과 예약\n강남역 3번 출구에서 5분",
            at: appointment, tags: ["병원"], color: .blue
        )) ?? Memo(body: "치과 예약")

        // 마크다운 꾸밈과 붙여넣기 결과를 한 장에 담아 눈으로 확인한다.
        let attachment = (try? store.attachments.save(samplePhoto(), fileExtension: "png")) ?? ""
        let plain = (try? await store.create(
            body: """
                ## 장보기
                - [x] 우유
                - [ ] **계란** 두 판
                - [ ] 식빵

                > 세제도 떨어졌음

                [example.com/recipes](https://example.com/recipes)

                ![](\(attachment))
                """,
            color: .yellow
        )) ?? Memo(body: "장보기")

        _ = try? await store.create(
            body: "월세 이체", due: CalendarDate(year: 2026, month: 8, day: 25), color: .pink
        )
        _ = try? await store.create(
            body: "치과 정기검진 예약하기",
            due: CalendarDate(year: 2026, month: 8, day: 20), color: .green
        )

        return Samples(scheduled: scheduled, plain: plain)
    }

    /// 붙여넣기 결과를 그려 보기 위한 가짜 사진.
    private static func samplePhoto() -> Data {
        let size = NSSize(width: 320, height: 150)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(
            starting: NSColor(calibratedRed: 0.42, green: 0.55, blue: 0.72, alpha: 1),
            ending: NSColor(calibratedRed: 0.78, green: 0.66, blue: 0.52, alpha: 1)
        )?.draw(in: NSRect(origin: .zero, size: size), angle: -60)
        NSColor(calibratedWhite: 1, alpha: 0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 232, y: 96, width: 34, height: 34)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else { return Data() }
        return data
    }

    // MARK: 렌더

    private static func render(
        name: String, size: CGSize, content: some View, into directory: URL
    ) async {
        log("\(name) 렌더 시작")

        // 라이트와 다크를 각자의 바탕화면 위에 놓고 나란히 낸다.
        // 밝은 모드 뷰를 어두운 바탕에 합성하면 명암이 뒤집혀 보여
        // 무엇이 흐린 글씨인지 판단할 수 없다.
        let margin: CGFloat = 26
        let tile = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let canvas = NSImage(size: CGSize(width: tile.width * 2, height: tile.height))

        canvas.lockFocus()
        for (index, scheme) in [ColorScheme.light, .dark].enumerated() {
            let origin = CGPoint(x: tile.width * CGFloat(index), y: 0)
            drawDesktop(scheme, in: NSRect(origin: origin, size: tile))

            let renderer = ImageRenderer(
                content: content
                    .frame(width: size.width, height: size.height)
                    .environment(\.rendersStatically, true)
                    .environment(\.colorScheme, scheme)
            )
            renderer.scale = 2
            guard let rendered = renderer.nsImage else { continue }
            rendered.draw(in: NSRect(
                origin: CGPoint(x: origin.x + margin, y: origin.y + margin), size: size
            ))
        }
        canvas.unlockFocus()

        guard let tiff = canvas.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else { log("\(name) 실패"); return }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appending(path: "\(name).png"))
        log("\(name) 저장")
    }

    /// 바탕화면 흉내. 유리가 무엇을 비추는지 볼 수 있어야 한다.
    private static func drawDesktop(_ scheme: ColorScheme, in rect: NSRect) {
        let colors: (NSColor, NSColor) = scheme == .light
            ? (NSColor(calibratedRed: 0.82, green: 0.85, blue: 0.90, alpha: 1),
               NSColor(calibratedRed: 0.66, green: 0.71, blue: 0.80, alpha: 1))
            : (NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.28, alpha: 1),
               NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.15, alpha: 1))
        NSGradient(starting: colors.0, ending: colors.1)?.draw(in: rect, angle: -90)
    }
}
