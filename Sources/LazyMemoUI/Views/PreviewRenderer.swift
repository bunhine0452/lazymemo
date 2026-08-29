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

    static func renderAll(into directory: URL, store: MemoStore, previews: LinkPreviewStore) async {
        log("표본 생성")
        let samples = await makeSamples(store: store)
        log("표본 완료")

        // 모델을 먼저 만들고 잠깐 기다린다 — 붙인 사진을 파일에서 불러오는
        // 일이 비동기라, 만들자마자 그리면 그림이 아직 없다.
        let scheduled = NoteModel(memo: samples.scheduled, store: store, previews: previews)
        let plain = NoteModel(memo: samples.plain, store: store, previews: previews)
        try? await Task.sleep(for: .milliseconds(300))

        await render(
            name: "note",
            size: CGSize(width: 268, height: 200),
            // 겹쳐 뜨는 조작 줄까지 펴서 낸다 — 지우기(붉은 휴지통)와
            // 치우기(×)가 서로 구별되는지는 나란히 놓고 봐야만 알 수 있다.
            content: NoteView(model: scheduled, onClose: {}, staged: true),
            into: directory
        )
        // **기본 창 크기 그대로**(§7 의 260×200) 한 장 더 낸다. 사진과 링크가
        // 붙은 메모는 큰 창에서는 멀쩡해 보이는데, 실제로 새로 만든 메모는
        // 이 크기다 — 여기서 안 보이면 사용자에게는 "붙여넣기가 안 되는" 것이다.
        await render(
            name: "note-default",
            size: CGSize(width: 260, height: 200),
            content: NoteView(model: plain, onClose: {}),
            into: directory
        )
        // 반쯤 비치는 종이 (§14.5 의 예외). "반투명한 면 위의 글은 씻겨
        // 나간다" 는 경고가 실제로 어디까지 사실인지는 보고 정해야 한다.
        let sheer = PaperAppearance(settings: SettingsStore(location: sheerSettingsLocation()))
        sheer.set(0.5)
        await render(
            name: "note-sheer",
            size: CGSize(width: 268, height: 200),
            content: NoteView(model: scheduled, onClose: {}, appearance: sheer),
            into: directory
        )
        // 날짜 없는 종이의 조작 줄. 새로 생긴 「달력에 놓기」(＋ 가 붙은 달력)는
        // 여기서만 보인다 — `note.png` 의 메모는 이미 일정이라 다른 표시가 뜬다.
        await render(
            name: "note-undated",
            size: CGSize(width: 268, height: 160),
            content: NoteView(model: plain, onClose: {}, staged: true),
            into: directory
        )
        await render(
            name: "note-plain",
            size: CGSize(width: 300, height: 430),
            content: NoteView(model: plain, onClose: {}),
            into: directory
        )

        // 편집기는 **진짜 텍스트 뷰를 그대로** 그린다. SwiftUI 대체 렌더는
        // 여백에 직접 그리는 줄머리 표시(`LineMarker`)를 보여주지 못한다.
        await renderEditor(
            name: "editor",
            size: CGSize(width: 300, height: 250),
            text: samples.plain.body,
            into: directory
        )

        let capture = QuickCaptureModel(store: store)
        // 말풍선 꼬리가 메뉴바 아이콘을 가리키는 모습까지 확인한다.
        capture.arrowOffset = QuickCaptureController.width - 70
        capture.query = "내일 오후 3시 치과\n강남역 3번 출구"
        // 붙인 사진이 조각으로 보이는지 — 이것이 없어서 "붙여넣기가 안 된다"
        // 로 보였다.
        if let pasted = capture.markdown(forPastedImage: samplePhoto(), fileExtension: "png") {
            capture.query += pasted
        }
        // 검색은 디바운스가 걸려 있어 결과가 채워질 때까지 잠깐 기다린다.
        try? await Task.sleep(for: .milliseconds(400))
        log("capture.query=[\(capture.query)] len=\(capture.query.count) label=\(capture.scheduleLabel ?? "-")")
        await render(
            name: "capture",
            size: CGSize(width: QuickCaptureController.width, height: 210),
            content: QuickCaptureView(model: capture, onCommit: {}, onCancel: {}),
            into: directory
        )

        // 빈 상자 — 열면 요즘 메모가 바로 아래 놓인다. 적으러 열었을 때
        // 목록이 글 자리를 밀어내지 않는지는 그려 봐야 안다.
        let browsing = QuickCaptureModel(store: store)
        browsing.arrowOffset = QuickCaptureController.width - 70
        // 지우는 길까지 같은 장에 담는다. 줄 끝의 휴지통은 포인터가 있어야
        // 붉어지므로 둘째 줄에 연출해 얹고, 되돌리기 줄은 **실제로 한 장
        // 지워서** 띄운다 — 흉내가 아니므로 그림이 곧 검증이 된다.
        let discarded = try? await store.create(body: "지난주 영수증 정리")
        browsing.prepareForShow()
        if let discarded { await browsing.delete(discarded) }
        browsing.selection = 0
        log("capture-recent.listed=\(browsing.listed.count) 지운것=\(browsing.lastDeleted?.title ?? "-")")
        await render(
            name: "capture-recent",
            size: CGSize(width: QuickCaptureController.width, height: 300),
            content: QuickCaptureView(
                model: browsing, onCommit: {}, onCancel: {},
                // 찬 점과 빈 점이 나란히 보이게 — 한 종류만 그리면
                // 둘이 구별되는지를 알 수 없다.
                isOnDesktop: { _ in Bool.random() },
                stagedTrashRow: 1
            ),
            into: directory
        )

        await render(
            name: "palette",
            size: CGSize(width: 6 * 96 + 5 * 10, height: 112),
            content: PaletteSheet(),
            into: directory
        )

        let calendarSize = CGSize(width: 300, height: 440)
        let calendar = CalendarModel(store: store)
        await calendar.refresh()
        log("calendar.days=\(calendar.byDay.count)")
        await render(
            name: "calendar",
            size: calendarSize,
            content: CalendarView(model: calendar, onClose: {}, onSelectMemo: { _ in }),
            into: directory
        )

        // 판형이 둘이다 (설계문서 §10.8). 넓은 창은 배치가 통째로 다르므로
        // 세로 판형 한 장만 봐서는 확인되지 않는다 — 접힌 자리가 세로로 섰는지,
        // 격자가 남는 높이를 쓰는지, 오른쪽 면의 제목이 제 폭을 갖는지.
        await render(
            name: "calendar-wide",
            size: CGSize(width: 620, height: 360),
            content: CalendarView(model: calendar, onClose: {}, onSelectMemo: { _ in }),
            into: directory
        )
        // 세로로 크게 늘린 창. 주 높이가 창을 따라 자라는지 — 앞선 판이
        // 36pt 에 못 박혀 창 위쪽의 작은 표로 남던 자리다.
        await render(
            name: "calendar-large",
            size: CGSize(width: 340, height: 620),
            content: CalendarView(model: calendar, onClose: {}, onSelectMemo: { _ in }),
            into: directory
        )

        await renderMenuList(into: directory, memos: Array(store.memos.prefix(4)))

        // 조작하는 중의 모습. **이 화면에서 새로 만든 것이 전부 여기에 있다** —
        // 집어 든 조각, 놓을 자리, 겹쳐 뜬 「미루기」, 옮긴 뒤의 되돌리기 줄.
        // 포인터가 없는 렌더에서는 연출해 주지 않으면 하나도 나타나지 않는다.
        await renderCalendarInUse(model: calendar, size: calendarSize, into: directory)

        // 종이에서 건너와 **놓을 날을 기다리는** 모습 (설계문서 §7.2). 이 상태는
        // 포인터가 달력 위에 있어야만 나타나므로 연출하지 않으면 확인할 길이 없다.
        await render(
            name: "calendar-placing",
            size: calendarSize,
            content: CalendarView(
                model: calendar,
                onClose: {},
                onSelectMemo: { _ in },
                staged: CalendarView.Staged(
                    carrying: samples.plain,
                    carryPoint: CGPoint(x: 150, y: 150),
                    target: calendar.grid.days[safe: 16]?.date,
                    holding: samples.plain
                )
            ),
            into: directory
        )
    }

    /// 「달력」을 **조작하는 중**으로 만들어 그린다.
    ///
    /// 옮기기는 흉내 내지 않고 실제로 시킨다. 그래야 되돌리기 줄에 적히는
    /// 날짜가 진짜 계산 결과가 되고, 그림이 곧 검증이 된다.
    private static func renderCalendarInUse(
        model: CalendarModel, size: CGSize, into directory: URL
    ) async {
        let target = CalendarDate(Date(), calendar: .current).adding(days: 3)
        // 사전의 순회 순서는 실행마다 달라진다. 렌더끼리 견주려면 같은 표본이
        // 같은 그림을 내야 하므로 id 로 정렬해 고른다.
        guard let moved = model.byDay.values.flatMap({ $0 })
            .filter({ $0.scheduledDate() != target })
            .min(by: { $0.id < $1.id })
        else { return }

        await model.move(moved, to: target)
        let listed = model.selectedMemos
        guard let pointed = listed.first, let dragged = listed.last, listed.count > 1 else { return }

        await render(
            name: "calendar-in-use",
            size: size,
            content: CalendarView(
                model: model,
                onClose: {},
                onSelectMemo: { _ in },
                staged: CalendarView.Staged(
                    hoveredRow: pointed.id,
                    carrying: dragged,
                    // 셋째 주 언저리 — 조각과 놓을 자리가 한 눈에 함께 들어온다.
                    carryPoint: CGPoint(x: 172, y: 166),
                    // 격자 안의 칸을 골라야 고리가 실제로 그려진다. 날짜를 계산해
                    // 넣으면 달이 넘어간 순간 격자 밖으로 나가 아무것도 안 보인다.
                    target: model.grid.days[safe: 17]?.date
                )
            ),
            into: directory
        )
    }

    /// 렌더 전용 설정 파일 자리. 실제 설정을 건드리지 않는다.
    private static func sheerSettingsLocation() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-render-settings.json", directoryHint: .notDirectory)
    }

    /// 메뉴바 목록을 그린다.
    ///
    /// `NSMenu` 는 시스템이 띄우는 창이라 `ImageRenderer` 로도 화면 캡처로도
    /// 잡히지 않는다. 그래서 줄(`MemoRow`)만 실제 뷰 그대로 떠내 메뉴처럼
    /// 생긴 판 위에 얹는다 — 자리와 세기가 어긋나면 여기서 드러난다.
    ///
    /// 둘째 줄은 포인터가 올라온 상태로, 셋째 줄은 휴지통 위에 올라온 상태로
    /// 연출한다. 그러지 않으면 이 목록에서 새로 생긴 것이 그림에 하나도
    /// 나타나지 않는다.
    private static func renderMenuList(into directory: URL, memos: [Memo]) async {
        guard !memos.isEmpty else { log("menu 표본 없음"); return }
        log("menu 렌더 시작")

        let inset: CGFloat = 6
        let headerHeight: CGFloat = 22
        let panel = CGSize(
            width: MemoRowGeometry.width + inset * 2,
            height: headerHeight + MemoRowGeometry.height * CGFloat(memos.count) + inset * 2
        )
        let margin: CGFloat = 26
        let tile = CGSize(width: panel.width + margin * 2, height: panel.height + margin * 2)
        let canvas = NSImage(size: CGSize(width: tile.width * 2, height: tile.height))
        let now = Date()

        canvas.lockFocus()
        for (index, scheme) in [ColorScheme.light, .dark].enumerated() {
            let origin = CGPoint(x: tile.width * CGFloat(index), y: 0)
            drawDesktop(scheme, in: NSRect(origin: origin, size: tile))

            NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)?
                .performAsCurrentDrawingAppearance {
                    let frame = NSRect(
                        origin: CGPoint(x: origin.x + margin, y: origin.y + margin), size: panel
                    )
                    drawMenuPanel(in: frame)
                    drawMenuHeader(
                        "메모 \(memos.count)장",
                        in: NSRect(
                            x: frame.minX + inset + 13, y: frame.maxY - inset - headerHeight,
                            width: frame.width, height: headerHeight
                        )
                    )

                    for (order, memo) in memos.enumerated() {
                        let row = MemoRow(
                            title: memo.title,
                            time: MemoTimeLabel.text(for: memo, now: now),
                            color: memo.color,
                            // 찬 점과 빈 점이 한 그림에 함께 있어야 구별이 확인된다.
                            onDesktop: order != 2,
                            onOpen: {}, onDelete: {}
                        )
                        row.staged = (highlighted: order == 1 || order == 2, overTrash: order == 2)
                        row.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)

                        // `cacheDisplay` 로 떠내지 않고 **직접 그린다.** 비트맵을
                        // 거치면 뒷바탕이 흰색으로 깔려, 다크 모드에서 흰 판에
                        // 흰 글자를 그린 꼴이 된다 (한 번 그렇게 나왔다).
                        NSGraphicsContext.saveGraphicsState()
                        let move = NSAffineTransform()
                        move.translateX(
                            by: frame.minX + inset,
                            yBy: frame.maxY - inset - headerHeight
                                - MemoRowGeometry.height * CGFloat(order + 1)
                        )
                        move.concat()
                        row.draw(row.bounds)
                        NSGraphicsContext.restoreGraphicsState()
                    }
                }
        }
        canvas.unlockFocus()

        guard let tiff = canvas.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else { log("menu 실패"); return }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appending(path: "menu.png"))
        log("menu 저장")
    }

    /// 메뉴가 놓이는 판. 시스템이 그리는 것과 똑같을 필요는 없고,
    /// 줄의 글자와 세기를 판단할 수 있을 만큼이면 된다.
    private static func drawMenuPanel(in frame: NSRect) {
        let path = NSBezierPath(roundedRect: frame, xRadius: 10, yRadius: 10)
        NSColor.windowBackgroundColor.withAlphaComponent(0.97).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.75
        path.stroke()
    }

    private static func drawMenuHeader(_ text: String, in rect: NSRect) {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        let height = ceil(font.ascender - font.descender)
        (text as NSString).draw(
            in: NSRect(
                x: rect.minX, y: rect.midY - height / 2 + font.descender / 2,
                width: rect.width, height: height
            ),
            withAttributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        )
    }

    /// 여섯 색을 나란히 놓고 본다.
    ///
    /// 색은 **바탕화면에 열 장이 흩어졌을 때 서로 구별되는가**가 전부다.
    /// 한 장만 보면 어떤 세기든 그럴듯해 보이므로, 반드시 나란히 놓고 정한다.
    private struct PaletteSheet: View {
        var body: some View {
            HStack(spacing: 10) {
                ForEach(MemoColor.allCases, id: \.self) { color in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(color.label)
                            .font(Theme.body)
                            .foregroundStyle(Paper.ink)
                        Text("치과 예약")
                            .font(Theme.label)
                            .foregroundStyle(Paper.fadedInk)
                    }
                    .frame(width: 96, height: 112, alignment: .topLeading)
                    .padding(.top, 12)
                    .padding(.leading, 12)
                    .background(Theme.paper(color.ink))
                    .overlay(Theme.edge())
                }
            }
        }
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

        // 오늘 칸은 넷 이상으로 채운다 — 점 셋과 "많다" 막대, 그리고 아래 판의
        // 여러 줄이 한 장에서 함께 확인되어야 한다.
        let today = CalendarDate(Date(), calendar: calendar)
        for (hour, minute, body, color) in [
            (9, 30, "팀 회의", MemoColor.purple),
            (13, 0, "은행 — 통장 정리", MemoColor.green),
            (19, 0, "저녁 약속", MemoColor.pink),
        ] {
            _ = try? await store.create(
                body: body,
                at: calendar.date(from: DateComponents(
                    year: today.year, month: today.month, day: today.day,
                    hour: hour, minute: minute
                )),
                color: color
            )
        }
        _ = try? await store.create(body: "분리수거", due: today, color: .gray)
        _ = try? await store.create(
            body: "전기요금", due: today.adding(days: 3, calendar: calendar), color: .yellow
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

    // MARK: 편집기 렌더 — 실물 그대로

    /// `MemoNSTextView` 를 화면 밖에서 직접 그린다.
    ///
    /// `ImageRenderer` 로는 이 뷰에 닿을 수 없어(§ `MemoTextArea`) 그동안
    /// 편집기의 실제 모습은 **한 번도 확인된 적이 없었다.** 체크상자와 글머리
    /// 점은 우리가 여백에 직접 그리는 것이라, 자리가 어긋나도 알 길이 없다.
    private static func renderEditor(
        name: String, size: CGSize, text: String, into directory: URL
    ) async {
        log("\(name) 렌더 시작")

        let margin: CGFloat = 26
        let tile = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let canvas = NSImage(size: CGSize(width: tile.width * 2, height: tile.height))

        canvas.lockFocus()
        for (index, scheme) in [ColorScheme.light, .dark].enumerated() {
            let origin = CGPoint(x: tile.width * CGFloat(index), y: 0)
            drawDesktop(scheme, in: NSRect(origin: origin, size: tile))

            let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            appearance?.performAsCurrentDrawingAppearance {
                let textView = MemoTextEditor.makeTextView(
                    font: .systemFont(ofSize: Paper.bodySize),
                    insets: NSSize(width: Theme.loose, height: Theme.loose),
                    linePitch: Paper.linePitch
                )
                textView.appearance = appearance
                // 렌더에서만 바탕을 직접 칠한다. 화면에서는 종이가 뒤에 깔리지만
                // 여기서는 뷰 하나를 통째로 떠내는 것이라 스스로 칠해야 한다.
                textView.drawsBackground = true
                textView.backgroundColor = Paper.surfaceNSColor
                textView.frame = NSRect(origin: .zero, size: size)
                textView.string = text
                if let storage = textView.textStorage {
                    MarkdownStyler.apply(
                        to: storage,
                        baseFont: .systemFont(ofSize: Paper.bodySize),
                        paragraph: textView.defaultParagraphStyle,
                        activeLine: nil
                    )
                }
                // 스크롤 뷰 없이 세로 가변으로 두면 뷰가 제 높이를 63pt 따위로
                // 줄여 잡고, 그 조각만 떠내 확대돼 그려진다. 카드 크기로 못박는다.
                textView.isVerticallyResizable = false
                if let container = textView.textContainer {
                    container.containerSize = NSSize(width: size.width, height: size.height)
                    textView.layoutManager?.ensureLayout(for: container)
                }
                textView.frame = NSRect(origin: .zero, size: size)
                textView.layoutSubtreeIfNeeded()

                guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds)
                else { return }
                textView.cacheDisplay(in: textView.bounds, to: rep)
                // 떠낸 비트맵은 픽셀 크기를 들고 있다. 포인트 크기로 되돌리지
                // 않으면 화면 배율만큼 확대돼 그려진다.
                rep.size = size
                rep.draw(in: NSRect(
                    origin: CGPoint(x: origin.x + margin, y: origin.y + margin), size: size
                ))
            }
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
