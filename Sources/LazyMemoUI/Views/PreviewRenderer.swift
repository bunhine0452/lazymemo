import AppKit
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoPlaces
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
        for step in 0..<WelcomeView.stepCount {
            await render(name: step == 0 ? "welcome" : "tutorial-\(step + 1)",
                         size: CGSize(width: 660, height: 610),
                         content: WelcomeView(initialStep: step), into: directory)
        }

        // 모델을 먼저 만들고 잠깐 기다린다 — 붙인 사진을 파일에서 불러오는
        // 일이 비동기라, 만들자마자 그리면 그림이 아직 없다.
        // **버튼이 넷에서 다섯으로 늘면 꼬리가 비워야 할 폭도 달라진다.**
        // 그 어긋남은 렌더에서만 보이므로(§14.9), 여기서는 `claude` 가 있는
        // 것으로 치고 그린다 — 진짜로 부르지는 않는다.
        let pretendClaude = ClaudeRunner(cli: ClaudeCLI(path: "/usr/bin/true"))
        let scheduled = NoteModel(
            memo: samples.scheduled, store: store, previews: previews, claude: pretendClaude
        )
        let plain = NoteModel(memo: samples.plain, store: store, previews: previews)
        try? await Task.sleep(for: .milliseconds(300))

        // 자리가 적힌 종이는 지도 카드가 서서 창이 자란다 (`NoteWindowController.paperWithMap`).
        // `ImageRenderer` 는 `.task` 를 돌리지 않으므로 자리를 여기서 직접 세운다 —
        // 표본은 좌표가 적혀 있어 지도에 묻지 않는다.
        await scheduled.places.load(places: scheduled.placeList)
        await render(
            name: "note",
            size: CGSize(width: 268, height: NoteWindowController.paperWithMap),
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
            size: CGSize(width: 268, height: NoteWindowController.paperWithMap),
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
        // **첫 줄이 긴 종이.** 겹쳐 뜨는 조작이 제목을 덮는지는 짧은 제목으로는
        // 드러나지 않는다 — `note.png` 의 「치과 예약」은 네 글자라 캡슐 밑에
        // 닿지 않는다. 기본 창(260pt)에서 제목이 줄을 채우는 이 경우가
        // 사람이 실제로 겪는 쪽이다 (`{#controls-overlap}`).
        let longTitled = NoteModel(
            memo: Memo(body: L("은행 가서 통장 재발급 받기\n신분증이랑 도장 챙길 것")),
            store: store, previews: previews
        )
        await render(
            name: "note-long-title",
            size: CGSize(width: 260, height: 200),
            content: NoteView(model: longTitled, onClose: {}, staged: true),
            into: directory
        )
        await render(
            name: "note-plain",
            size: CGSize(width: 300, height: 430),
            content: NoteView(model: plain, onClose: {}),
            into: directory
        )
        // **방금 지운 종이** (`{#note-inline-undo}`). 흉내가 아니라 정말로 한
        // 장 지워서 그린다 — 그러면 그림이 곧 검증이 된다. 예전에는 여기서
        // 창이 소리 없이 사라져 화면에 흔적이 한 줄도 안 남았다.
        if let doomed = try? await store.create(body: L("잘못 적은 메모")) {
            let mourning = NoteModel(memo: doomed, store: store, previews: previews)
            await mourning.delete()
            await render(
                name: "note-deleted",
                size: CGSize(width: 260, height: 200),
                content: NoteView(model: mourning, onClose: {}),
                into: directory
            )
            await mourning.restoreDeleted()
            try? await store.delete(doomed.id)
        }

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
        capture.query = L("내일 오후 3시 치과\n강남역 3번 출구")
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
            size: CGSize(width: QuickCaptureController.width, height: 310),
            content: QuickCaptureView(model: capture, onCommit: {}, onCancel: {}),
            into: directory
        )

        // 낱말이 기억나지 않을 때 (`MemoFilter`). **무엇으로 걸렀는지가
        // 화면에 없으면** 목록이 짧아진 이유를 알 길이 없다.
        let recalling = QuickCaptureModel(store: store)
        recalling.arrowOffset = QuickCaptureController.width - 70
        recalling.query = "#" + MemoShape.photo.label
        try? await Task.sleep(for: .milliseconds(400))
        log("capture-filter.chips=\(recalling.filter.chips) 찾은것=\(recalling.pool.count)")
        await render(
            name: "capture-filter",
            size: CGSize(width: QuickCaptureController.width, height: 310),
            content: QuickCaptureView(model: recalling, onCommit: {}, onCancel: {}),
            into: directory
        )

        // 빈 상자 — 열면 요즘 메모가 바로 아래 놓인다. 적으러 열었을 때
        // 목록이 글 자리를 밀어내지 않는지는 그려 봐야 안다.
        let browsing = QuickCaptureModel(store: store)
        browsing.arrowOffset = QuickCaptureController.width - 70
        // 지우는 길까지 같은 장에 담는다. 줄 끝의 휴지통은 포인터가 있어야
        // 붉어지므로 둘째 줄에 연출해 얹고, 되돌리기 줄은 **실제로 한 장
        // 지워서** 띄운다 — 흉내가 아니므로 그림이 곧 검증이 된다.
        let discarded = try? await store.create(body: L("지난주 영수증 정리"))
        browsing.prepareForShow()
        if let discarded { await browsing.delete(discarded) }
        browsing.selection = 0
        log("capture-recent.listed=\(browsing.listed.count) 지운것=\(browsing.lastDeleted?.title ?? "-")")
        await render(
            name: "capture-recent",
            size: CGSize(width: QuickCaptureController.width, height: 545),
            content: QuickCaptureView(
                model: browsing, onCommit: {}, onCancel: {},
                // 찬 점과 빈 점이 나란히 보이게 — 한 종류만 그리면
                // 둘이 구별되는지를 알 수 없다.
                isOnDesktop: { _ in Bool.random() },
                stagedTrashRow: 1
            ),
            into: directory
        )

        // 비서를 겸하는 상자 — 되묻기·답·후보·결과 (docs/research/quick-capture-assistant-2026-09-15.md).
        // 모델 없이 상태만 세운다(`stageForPreview`). 배치와 낱말을 눈으로 보는 것이 목적이다.
        let assistant = AssistantModel(service: store.service, support: FileManager.default.temporaryDirectory
            .appending(path: "lazymemo-render-assistant", directoryHint: .isDirectory))
        let asking = QuickCaptureModel(store: store)
        asking.arrowOffset = QuickCaptureController.width - 70
        asking.assistant = assistant
        asking.query = L("9월 30일에 @홍대입구 친구랑 밥 먹기로 했어")
        _ = asking.commit()
        asking.query = ""
        log("capture-asking.question=\(asking.pendingQuestion ?? "-") summary=\(asking.pendingSummary ?? "-")")
        await render(
            name: "capture-asking",
            size: CGSize(width: QuickCaptureController.width, height: 300),
            content: QuickCaptureView(model: asking, onCommit: {}, onCancel: {}),
            into: directory
        )

        let dentist = try? await store.create(body: L("치과 예약 — 강남역 3번 출구 서울밝은치과. 18일 오후 2시 스케일링."),
                                              due: CalendarDate(year: 2026, month: 9, day: 18))
        let answering = QuickCaptureModel(store: store)
        answering.arrowOffset = QuickCaptureController.width - 70
        answering.assistant = assistant
        if let dentist {
            assistant.stageForPreview(answer: AssistantAnswer(found: true, text: L("9월 18일 오후 2시, 강남역 서울밝은치과 스케일링 예약이에요."),
                                                              evidence: [dentist.id], quotes: [L("치과 예약 — 강남역 3번 출구 서울밝은치과. 18일 오후 2시 스케일링.")]))
            answering.showMemos([dentist.id], as: .evidence)
        }
        await render(
            name: "capture-answer",
            size: CGSize(width: QuickCaptureController.width, height: 330),
            content: QuickCaptureView(model: answering, onCommit: {}, onCancel: {}),
            into: directory
        )

        let applying = QuickCaptureModel(store: store)
        applying.arrowOffset = QuickCaptureController.width - 70
        applying.assistant = assistant
        if let dentist {
            let when = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 10)) ?? Date()
            assistant.stageForPreview(applied: ProposedAction(requestID: UUID(), kind: .setRecall, memoID: dentist.id,
                                                              patch: FieldPatch(surface: .set(when))))
            applying.prepareForShow()
        }
        await render(
            name: "capture-applied",
            size: CGSize(width: QuickCaptureController.width, height: 420),
            content: QuickCaptureView(model: applying, onCommit: {}, onCancel: {}),
            into: directory
        )

        let choosing = QuickCaptureModel(store: store)
        choosing.arrowOffset = QuickCaptureController.width - 70
        choosing.assistant = assistant
        let jisoo = try? await store.create(body: L("지수한테 5만 원 빌려줌"))
        let jisoo2 = try? await store.create(body: L("지수 생일 — 11월 2일"))
        if let jisoo, let jisoo2 {
            assistant.stageForPreview(proposal: ProposedAction(requestID: UUID(), kind: .ask, question: L("어느 메모를 말하는지 골라 주세요"),
                                                               candidates: [jisoo.id, jisoo2.id]))
            choosing.showMemos([jisoo.id, jisoo2.id], as: .candidates)
            choosing.selection = 0
        }
        await render(
            name: "capture-candidates",
            size: CGSize(width: QuickCaptureController.width, height: 330),
            content: QuickCaptureView(model: choosing, onCommit: {}, onCancel: {}),
            into: directory
        )

        // 메모에 없다 — 「웹에서 찾기」를 권하는 줄 (빈 상자의 ⌘↵ 도 같은 일).
        let offering = QuickCaptureModel(store: store)
        offering.arrowOffset = QuickCaptureController.width - 70
        offering.assistant = assistant
        assistant.stageForPreview(failed: L("메모에서 근거를 찾지 못했습니다"), offersWeb: L("달러 환율 얼마야?"))
        offering.prepareForShow()
        await render(
            name: "capture-web-offer",
            size: CGSize(width: QuickCaptureController.width, height: 330),
            content: QuickCaptureView(model: offering, onCommit: {}, onCancel: {}),
            into: directory
        )

        // 웹의 답 — 물음·답 문장, 그 밑에 결과 전부(인용한 둘이 앞), 끝에 「이걸 어떻게 할까요?」.
        let webbing = QuickCaptureModel(store: store)
        webbing.arrowOffset = QuickCaptureController.width - 70
        webbing.assistant = assistant
        let hits = Self.sampleWebHits.map(Evidence.init(hit:))
        let kma = WebSource(id: hits[0].memoID, title: hits[0].title ?? "", url: hits[0].url!)
        let meteo = WebSource(id: hits[1].memoID, title: hits[1].title ?? "", url: hits[1].url!)
        assistant.stageForPreview(answer: AssistantAnswer(
            found: true, text: L("내일 서울은 경상권 해안과 제주도 중심으로 비, 강풍과 풍랑에 유의하래요."),
            evidence: [kma.id, meteo.id],
            quotes: [hits[0].excerpt, hits[1].excerpt],
            sources: [kma, meteo]), results: hits, question: L("웹에서 서울 내일 날씨"))
        webbing.showMemos([], as: .evidence)
        await render(
            name: "capture-web-answer",
            size: CGSize(width: QuickCaptureController.width, height: 560),
            content: QuickCaptureView(model: webbing, onCommit: {}, onCancel: {}),
            into: directory
        )
        // 생각하는 중 — 획·단계의 말·숨 쉬는 테두리 (`ThinkingInk`). 한 장면은 한 숨의 한순간이다.
        let thinking = QuickCaptureModel(store: store)
        thinking.arrowOffset = QuickCaptureController.width - 70
        thinking.assistant = assistant
        thinking.query = L("엄마 선물 뭐 사기로 했지?")
        assistant.stageThinkingForPreview(.writing(found: 6, tokens: 3), task: .answer)
        await render(
            name: "capture-thinking",
            size: CGSize(width: QuickCaptureController.width, height: 200),
            content: QuickCaptureView(model: thinking, onCommit: {}, onCancel: {}),
            into: directory
        )
        assistant.reset()
        for extra in [dentist, jisoo, jisoo2].compactMap({ $0 }) { try? await store.delete(extra.id) }

        // 약속을 적은 뒤의 가는 길 되물음 — 출발지, 그리고 탈것 (`RoutePlanner`). 접속 없이 모습만 세운다.
        let planner = RoutePlanner(store: store, settings: { Settings() })
        let routing = QuickCaptureModel(store: store)
        routing.planner = planner
        let summary = L("밥약속 · 9월 16일 (수) 18:30 · 투파인드피터 잠실점")
        planner.stageForPreview(step: .askingOrigin, question: RoutePlanner.originQuestion, choices: [RoutePlanner.hereChoice, RoutePlanner.skipChoice], summary: summary)
        await render(
            name: "capture-route-origin",
            size: CGSize(width: QuickCaptureController.width, height: 200),
            content: QuickCaptureView(model: routing, onCommit: {}, onCancel: {}),
            into: directory
        )
        planner.stageForPreview(
            step: .choosing,
            question: L("경로 5개를 찾았어요 — 버스 21분 · 지하철 19분 (환승) · 택시 12분 (약 9,800원). 무엇으로 갈까요?"),
            choices: ["버스", "지하철", "택시", RoutePlanner.skipChoice], summary: summary
        )
        await render(
            name: "capture-route-mode",
            size: CGSize(width: QuickCaptureController.width, height: 220),
            content: QuickCaptureView(model: routing, onCommit: {}, onCancel: {}),
            into: directory
        )
        planner.dismiss()

        // 길이 적힌 종이 — 본문 끝의 절(`RouteNote`)이 카드로 선다. 지도 카드 밑, 글 아래.
        if let routed = try? await store.create(body: L("밥약속\nhttps://naver.me/GFB1MHiW"), at: samples.route.arrive,
                                                 place: L("투파인드피터 잠실점"), geo: Coordinate(latitude: 37.5109, longitude: 127.0853)) {
            let body = RouteNote.append(samples.route, to: routed.body)
            if let written = try? await store.update(routed.id, body: body) {
                let routedModel = NoteModel(memo: written, store: store, previews: previews)
                await render(
                    name: "note-route",
                    size: CGSize(width: 300, height: NoteWindowController.paperWithMap + NoteWindowController.routeCardHeight),
                    content: NoteView(model: routedModel, onClose: {}),
                    into: directory
                )
            }
            try? await store.delete(routed.id)
        }

        await render(
            name: "palette",
            size: CGSize(width: 6 * 96 + 5 * 10, height: 112),
            content: PaletteSheet(),
            into: directory
        )

        let calendarSize = CGSize(width: 320, height: 470)
        // 남의 일정이 우리 종이와 어떻게 갈라 보이는지는 **눈으로만** 확인된다 (§14.9).
        // 실제 캘린더 권한 없이 렌더가 돌아야 하므로 표본 문을 하나 세운다.
        let calendar = CalendarModel(store: store, feed: SampleFeed())
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

        await renderDrawer(store: store, into: directory)
    }

    /// 「서랍」 — **여섯 모습이 다 손을 타야만 나타난다.**
    ///
    /// 닫힌 탭은 그냥 열어 두면 보이지만, 펼친 목록도·펼친 줄도·종이가
    /// 위에 떠 있는 순간도 전부 포인터가 있어야 생긴다. 렌더에서 연출하지
    /// 않으면 이 화면에서 새로 만든 것이 통째로 미확인으로 남는다 (§14.9).
    private static func renderDrawer(store: MemoStore, into directory: URL) async {
        // 서랍은 «밀어 둔 종이» 를 담는다. 표본 창고의 메모는 대부분 일정이라
        // (일정은 달력이 맡는다 — `DrawerContents`) 날짜 없는 종이를 몇 장 만든다.
        // 폴더는 셋 — 「전체」와 폴더 칸이 함께 보여야 폴더 띠가 무엇인지 안다.
        let filed: [(String, MemoColor, String?)] = [
            (L("장보기 목록\n- [x] 우유\n- [x] 계란\n- [ ] 세제"), .green, L("장보기")),
            (L("읽다 만 것 — 「종이의 물성」\n3장까지 읽었다"), .blue, L("읽을 것")),
            (L("환불 신청 번호\n8821-0043"), .yellow, nil),
            (L("겨울옷 정리"), .purple, L("집")),
            (L("명함 사진 찍어 두기"), .pink, nil),
            (L("이사 견적 세 군데\n한아름 / 무지개 / 다섯별"), .gray, L("집")),
            (L("자전거 공기압"), .blue, nil),
            (L("도서관 반납\n「종이의 물성」 · 「게으름의 기술」"), .yellow, L("읽을 것")),
            (L("우산 새로 사기"), .green, L("장보기")),
            (L("전구 40W 두 개"), .yellow, L("장보기")),
            (L("커튼 세탁"), .purple, L("집")),
        ]
        for (body, color, folder) in filed {
            _ = try? await store.create(body: body, color: color, folder: folder)
        }

        // 좌표 파일이 없는 렌더에서는 「사람이 치웠는가」를 물을 곳이 없다.
        // 전부 치운 것으로 친다 — 일정은 `DrawerContents` 가 알아서 뺀다.
        let drawer = DrawerModel(
            store: store, putAway: { _ in true }, folders: [L("장보기"), L("읽을 것"), L("집")]
        )
        log("drawer.papers=\(drawer.count) folders=\(drawer.folders)")

        await render(
            name: "drawer",
            size: DrawerGeometry.closedSize,
            content: DrawerView(model: drawer),
            into: directory
        )

        // 종이가 서랍 위에 떠 있는 순간. 놓으면 들어간다는 것을 **놓기 전에**
        // 말해 주는지는 이 그림에서만 확인된다.
        drawer.staged = DrawerModel.Staged(landing: drawer.papers.first?.id)
        await render(
            name: "drawer-landing",
            size: DrawerGeometry.closedSize,
            content: DrawerView(model: drawer),
            into: directory
        )

        let plan = drawer.geometry()
        // 손은 **목록 가운데** 줄에 얹는다 — 조작 셋이 시각 자리를 대신하는지 본다.
        drawer.staged = DrawerModel.Staged(isOpen: true, hovered: drawer.papers[safe: 3]?.id)
        await render(
            name: "drawer-open",
            size: plan.size,
            content: DrawerView(model: drawer),
            into: directory
        )

        // 한 줄을 펼친 모습. 줄이 아래로 자라 본문과 조작이 나오는지.
        if let first = drawer.papers.first {
            drawer.staged = DrawerModel.Staged(
                isOpen: true, expanded: first.id, lastFiled: drawer.papers.last
            )
            await render(
                name: "drawer-expanded",
                size: DrawerGeometry(count: drawer.count, expanded: true).size,
                content: DrawerView(model: drawer),
                into: directory
            )
        }

        // **폴더 하나를 보는 중.** 띠에서 고른 칸이 채워지고 목록이 그 칸의
        // 것만 남는지, 줄에서 폴더 이름표가 사라지는지.
        drawer.staged = DrawerModel.Staged(isOpen: true, folder: L("장보기"))
        await render(
            name: "drawer-folder",
            size: DrawerGeometry(count: drawer.counts[L("장보기")] ?? 0).size,
            content: DrawerView(model: drawer),
            into: directory
        )

        // **새 폴더 이름을 적는 중.**
        drawer.staged = DrawerModel.Staged(isOpen: true, naming: true)
        await render(
            name: "drawer-naming",
            size: plan.size,
            content: DrawerView(model: drawer),
            into: directory
        )

        // **찾는 중.** 글 상자에 커서를 놓을 수 없으므로 연출값으로 세운다
        // (`DrawerModel.Staged.query`).
        drawer.staged = DrawerModel.Staged(isOpen: true, query: "ㅈ")
        await render(
            name: "drawer-searching",
            size: DrawerGeometry(count: drawer.count).size,
            content: DrawerView(model: drawer),
            into: directory
        )

        // **못 찾은 서랍.** 「여기 아무것도 없습니다」와 갈리는지가 요점이다 —
        // 방금 아홉 장을 넣어 둔 사람에게 그 말은 거짓말이다.
        drawer.staged = DrawerModel.Staged(isOpen: true, query: L("없는말"))
        await render(
            name: "drawer-nothing-found",
            size: DrawerGeometry(count: 0).size,
            content: DrawerView(model: drawer),
            into: directory
        )

        // **여러 장을 골라 둔 모습.** 바닥 한 줄이 조작을 내놓는지.
        drawer.staged = DrawerModel.Staged(
            isOpen: true,
            picked: Set(drawer.papers.prefix(3).map(\.id))
        )
        await render(
            name: "drawer-picked",
            size: plan.size,
            content: DrawerView(model: drawer),
            into: directory
        )
        drawer.staged = nil
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
                        L("메모 \(memos.count)장"),
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
                        Text(L("치과 예약"))
                            .font(Theme.label)
                            .foregroundStyle(Paper.fadedInk)
                    }
                    .padding(.top, 12)
                    .padding(.leading, 12)
                    .frame(width: 96, height: 112, alignment: .topLeading)
                    .background(Theme.paper(color.ink))
                    .overlay(Theme.edge())
                }
            }
        }
    }

    // MARK: 표본

    /// 렌더용 표본 캘린더. 실제 시스템 캘린더를 읽지 않는다.
    private struct SampleFeed: CalendarFeed {
        func events(from: CalendarDate, to: CalendarDate) async -> [ForeignEvent] {
            let day = Calendar.current.date(
                from: DateComponents(year: 2026, month: 8, day: 31)
            ) ?? Date()
            return [
                ForeignEvent(
                    id: "sample-standup", title: L("팀 스탠드업"),
                    start: day.addingTimeInterval(10 * 3600), isAllDay: false,
                    calendarName: L("직장")
                ),
                ForeignEvent(
                    id: "sample-holiday", title: L("재택 근무"),
                    start: day, isAllDay: true, calendarName: L("직장")
                ),
            ]
        }
    }

    private struct Samples {
        let scheduled: Memo
        let plain: Memo
        /// 가는 길 한 벌 — 버스 둘에 걷기, 환승 한 번 (사용자가 가져온 네이버 지도의 보기 그대로).
        let route: TransitRoute
    }

    private static func makeSamples(store: MemoStore) async -> Samples {
        let calendar = Calendar.current
        let appointment = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 14, minute: 30)
        ) ?? Date()

        let scheduled = (try? await store.create(
            body: L("치과 예약\n보험증 챙기기"),
            at: appointment,
            // 일이 언제인가(14:30)와 종이가 언제 나오는가(14:00)가 한 조각으로
            // 붙는 것을 눈으로 본다 — 「오후 2:30 · 30분 전」.
            surface: appointment.addingTimeInterval(-1800),
            // 장소가 본문에서 아래 잉크로 옮겨 앉는 것이 이 표본의 볼거리다.
            place: L("강남역 3번 출구"), geo: Coordinate("37.4979,127.0276"),
            tags: [L("병원")], color: .blue
        )) ?? Memo(body: L("치과 예약"))

        // 마크다운 꾸밈과 붙여넣기 결과를 한 장에 담아 눈으로 확인한다.
        let attachment = (try? store.attachments.save(samplePhoto(), fileExtension: "png")) ?? ""
        let plain = (try? await store.create(
            body: L("""
                ## 장보기
                - [x] 우유
                - [ ] **계란** 두 판
                - [ ] 식빵

                > 세제도 떨어졌음

                [example.com/recipes](https://example.com/recipes)
                """) + "\n\n![](\(attachment))",
            color: .yellow
        )) ?? Memo(body: L("장보기"))

        _ = try? await store.create(
            body: L("월세 이체"), due: CalendarDate(year: 2026, month: 8, day: 25), color: .pink
        )
        _ = try? await store.create(
            body: L("치과 정기검진 예약하기"),
            due: CalendarDate(year: 2026, month: 8, day: 20), color: .green
        )

        // 오늘 칸은 넷 이상으로 채운다 — 점 셋과 "많다" 막대, 그리고 아래 판의
        // 여러 줄이 한 장에서 함께 확인되어야 한다.
        let today = CalendarDate(Date(), calendar: calendar)
        for (hour, minute, body, color) in [
            (9, 30, L("팀 회의"), MemoColor.purple),
            (13, 0, L("은행 — 통장 정리"), MemoColor.green),
            (19, 0, L("저녁 약속"), MemoColor.pink),
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
        _ = try? await store.create(body: L("분리수거"), due: today, color: .gray)
        _ = try? await store.create(
            body: L("전기요금"), due: today.adding(days: 3, calendar: calendar), color: .yellow
        )

        let dinner = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 18, minute: 30)) ?? appointment
        let route = TransitRoute(origin: L("석촌고분역"), destination: L("투파인드피터 잠실점"), minutes: 21, arrive: dinner, fare: 1500, legs: [
            .init(mode: .walk, minutes: 2),
            .init(mode: .bus, minutes: 8, line: "3314", kind: L("지선"), from: L("잠실여고후문"), to: L("잠실역.롯데월드"), stops: 4,
                  boardAt: dinner.addingTimeInterval(-19 * 60)),
            .init(mode: .bus, minutes: 6, line: "4318", kind: L("간선"), from: L("잠실역.롯데월드"), to: L("잠실새내역2번출구"), stops: 2,
                  boardAt: dinner.addingTimeInterval(-10 * 60)),
            .init(mode: .walk, minutes: 4),
        ])
        return Samples(scheduled: scheduled, plain: plain, route: route)
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


extension PreviewRenderer {
    /// 웹의 답 장면에 쓰는 결과 다섯 — 2026-09-17 「서울 내일 날씨」 실물을 본떴다.
    static let sampleWebHits: [WebHit] = [
        WebHit(title: L("홈 - 기상청 날씨누리"), url: URL(string: "https://www.weather.go.kr/")!,
               snippet: L("내일 경상권해안, 제주도 중심 비, 강풍과 풍랑 유의. (기상청 예보 26년 9월 17일 05시 기준)")),
        WebHit(title: L("서울 내일 날씨 - Meteocast"), url: URL(string: "https://ko.meteocast.net/tomorrow-forecast/kr/seoul/")!,
               snippet: L("해돋이 06:11, 일몰 18:45. Asia/Seoul, GMT 9. 내일 서울 기온 18~24도, 흐리고 한때 비.")),
        WebHit(title: L("서울특별시 날씨 - 네이버 날씨"), url: URL(string: "https://weather.naver.com/today/09140104")!,
               snippet: L("오늘·내일·모레 날씨와 미세먼지, 시간별 강수 확률을 한눈에.")),
        WebHit(title: L("Seoul weather tomorrow - AccuWeather"), url: URL(string: "https://www.accuweather.com/en/kr/seoul/226081/weather-tomorrow/226081")!,
               snippet: L("Cloudy with a shower in spots. High 24°, low 18°. Winds SE 10 km/h.")),
        WebHit(title: L("기상청 단기예보 — 서울·경기"), url: URL(string: "https://www.weather.go.kr/w/weather/forecast/short-term.do")!,
               snippet: L("서울·경기 내일 오전 구름많음, 오후 흐리고 비. 강수 확률 60%.")),
    ]
}
