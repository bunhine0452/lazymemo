import LazyMemoCore
import LazyMemoPlaces
import SwiftUI

/// 바탕화면에 놓인 메모 한 장.
///
/// **기본 상태는 글자와 종이뿐이다** (철학 4). 머리글도 아이콘 줄도 색 점도
/// 없다. 조작은 포인터가 올 때 내용 **위에 겹쳐** 뜨고 자리를 차지하지 않는다.
///
/// 시간이 지난 메모는 스스로 물러난다 (철학 3, `MemoAge`). 포인터를 올리면
/// 즉시 또렷해진다 — 읽으려는 뜻이 곧 되살리는 신호다.
struct NoteView: View {
    @Bindable var model: NoteModel
    var onClose: () -> Void
    /// Esc — 종이를 치운다. ×와 같은 곳으로 가되 **키보드를 돌려주는 일**이 하나
    /// 더 있어 창(`NoteWindowController.escape`)이 맡는다.
    var onEscape: () -> Void = {}
    /// 달력으로 건너가는 길 (설계문서 §7.2).
    ///
    /// 날짜가 없으면 **놓을 날을 고르러** 가고, 있으면 그 일정이 달력의
    /// 어디에 있는지 **보러** 간다. 어느 쪽인지는 부르는 쪽이 정한다 —
    /// 종이는 달력 창을 알지 못한다.
    var onCalendar: () -> Void = {}
    /// 자리 카드가 처음 섰다 — 창이 종이를 늘릴 자리다 (`NoteWindowController`).
    var onPlacesAppear: () -> Void = {}
    /// 가는 길 카드가 섰다 — 같은 이유로 종이가 자란다.
    var onRouteAppear: () -> Void = {}
    /// 글이 차지한 높이가 바뀌었다 — 종이가 글에 맞춰 자랄 근거다 (`PaperFit`).
    var onTextHeight: (CGFloat) -> Void = { _ in }
    /// 종이가 얼마나 진한가. 창 전체가 함께 쓰는 값이다 (`PaperAppearance`).
    var appearance: PaperAppearance? = nil
    /// 화면 밖 렌더에서 조작 줄을 펴 보이기 위한 연출값 (설계문서 §14.9).
    /// 포인터가 없는 렌더에서는 겹쳐 뜨는 조작이 하나도 나타나지 않는다.
    var staged = false

    @State private var isHovering = false
    @State private var isPickingColor = false
    /// 보이는 칸 아래에 글이 더 있다 (`MemoTextEditor.onOverflowChange`).
    @State private var textOverflows = false
    /// 종이의 높이. 사진이 가질 수 있는 몫을 여기서 잰다.
    @State private var paperHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: MemoColor { model.memo.color }

    /// 아래 캡슐에 든 버튼 수. 「다듬기」가 있으면 하나 더다 — 이 값이 어긋나면
    /// 캡슐이 꼬리를 덮는다 (`NoteControlLayout` 이 지키는 그 규칙).
    private var controlCount: Int { NoteControlLayout.paperButtons(hasTidy: model.canTidy) }
    private var hasFooter: Bool { NoteFooter.isVisible(for: model.memo) }

    /// 조작 줄이 떠 있는가 — 포인터가 왔거나, 색을 고르는 중이거나.
    private var showsControls: Bool { staged || isHovering || isPickingColor }

    /// 포인터가 올라오면 나이를 잊는다.
    ///
    /// 기준 시각을 모델에서 받는다 — `Date()` 를 여기서 부르면 값이 바뀌어도
    /// 뷰가 다시 그려질 이유가 없어, **하루가 지나도 어제의 나이가 그대로**
    /// 화면에 남는다 (`NoteModel.asOf`).
    private var age: MemoAge {
        showsControls ? .fresh : MemoAge.of(model.memo, now: model.asOf)
    }

    /// 지금 이 종이의 진하기. **포인터가 오면 언제나 원래대로 진해진다** —
    /// 읽으려는 뜻이 곧 되살리는 신호라는 규칙(철학 3)을 그대로 쓴다.
    /// 그래서 많이 비치게 두어도 읽을 수 없게 되는 일이 없다.
    private var paperOpacity: Double {
        showsControls ? 1 : (appearance?.opacity ?? PaperAppearance.standard)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                if !model.placeList.isEmpty { placeCards }
                editor
                if let route = model.route { routeCard(route) }
                if !model.images.isEmpty { photographs }
                if !model.links.isEmpty { linkCards }
                if model.isUnsaved { unsavedMark }
                if hasFooter { footer }
            }
            // 종이는 누레지지만 잉크는 그만큼 사라지지 않는다. 오래된 메모도
            // 읽을 수는 있어야 한다 — 물러나는 것과 안 보이는 것은 다르다.
            .opacity(0.72 + 0.28 * age.presence)
            // 머리의 손잡이 — 색띠이자 종이를 집는 자리. 조작(×)보다 **아래**에
            // 두어 모서리에서는 치우기가 이긴다 (`PaperGrip`). 본문 위 여백보다
            // 조금 길어 첫 줄의 윗머리까지 덮지만 글자에는 닿지 않는다.
            .overlay(alignment: .top) { PaperGrip(tint: color.tint) }

            if showsControls, model.justDeleted == nil {
                // 치우기는 모서리에 남고, 나머지는 종이 아래로 내려간다.
                closeControl
                paperControls
            }

            // 방금 지웠으면 그 자리에 되돌리는 줄이 덮인다 (D6).
            if let deleted = model.justDeleted { deletedVeil(deleted) }

            // 기다리는 중이거나 방금 다듬었으면 아래에 한 줄이 뜬다.
            if model.thinking != .none { thinkingBar }
        }
        .background {
            Theme.paper(color.ink, age: age)
            // 사진 몫을 종이 높이에 비례해 정하려면 그 높이를 알아야 한다.
            // 배경에서 재는 이유는 본문 배치에 영향을 주지 않기 위해서다.
            GeometryReader { proxy in
                Color.clear.onAppear { paperHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, height in paperHeight = height }
            }
        }
        .overlay(Theme.edge())
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        // 캡슐에서 덜어 낸 것들이 여기 있다. macOS 사람이 이미 아는 자리이고,
        // 화면에 자리를 차지하지 않으므로 철학 4 와도 부딪히지 않는다.
        .contextMenu { paperMenu }
        // `.onHover` 는 키 윈도에서만 반응한다. 바탕화면의 종이는 다른 앱을
        // 쓰는 동안에도 되살아나야 하므로 감지기를 따로 둔다.
        .overlay { HoverSensor { isHovering = $0 } }
        .opacity(paperOpacity)
        .animation(reduceMotion ? nil : Theme.reveal, value: isHovering)
        .animation(Theme.reveal, value: model.isUnsaved)
        .animation(Theme.reveal, value: model.justDeleted?.id)
        .animation(Theme.settle, value: age)
        .animation(Theme.settle, value: paperOpacity)
        // 이름이 바뀔 때만 다시 묻는다. 좌표는 카드가 알아내 파일에 적는 것이라 그것까지
        // 열쇠에 넣으면 적는 순간 자기 자신을 다시 시작한다.
        .onChange(of: model.route != nil, initial: true) { _, hasRoute in
            if hasRoute { onRouteAppear() }
        }
        .task(id: model.placeList.map(\.name)) {
            let places = model.placeList
            guard !places.isEmpty else { return }
            onPlacesAppear()
            await model.places.load(places: places) { geo in
                Task { await model.adoptGeo(geo) }
            }
        }
    }

    // MARK: 자리 카드

    /// 종이 머리의 지도 — 폰과 같은 자리, 같은 물건 (`PlaceCardsView`).
    private var placeCards: some View {
        PlaceCardsView(resolver: model.places, mapHeight: mapHeight)
            .padding(.bottom, Theme.tight)
    }

    /// 지도 한 장이 종이에서 가질 수 있는 키. 사진과 같은 규칙이다 — 기본 종이(200pt)에서
    /// 지도가 절반을 먹으면 글은 두 줄만 남는다. 크게 보는 것은 종이를 늘리거나 지도 앱이다.
    private var mapHeight: CGFloat {
        let share = paperHeight > 0 ? paperHeight * 0.34 : 68
        return max(56, min(share, 120))
    }

    /// 가는 길 — 글 아래, 사진 위. 본문 끝의 절(`RouteNote`)을 카드로 (폰과 같은 물건, `RouteCard`).
    private func routeCard(_ route: TransitRoute) -> some View {
        RouteCard(
            route: route,
            style: RouteCardStyle(
                ink: Paper.ink, faded: Paper.fadedInk, accent: Theme.accentInk, softAccent: Theme.softAccent,
                surface: Paper.ink.opacity(0.04), edge: Paper.ink.opacity(0.08), radius: Theme.controlRadius
            ),
            // 맥에는 지도 앱이 애플뿐이고 애플은 한국의 대중교통을 모른다 — 웹의 카카오맵으로.
            open: { route in if let url = RouteLinks.kakaoWeb(route) { NSWorkspace.shared.open(url) } },
            remove: { Task { await model.removeRoute() } }
        )
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
    }

    // MARK: 본문

    private var editor: some View {
        MemoTextArea(
            text: $model.text,
            insets: NSSize(width: Theme.loose, height: Theme.loose),
            linePitch: Paper.linePitch,
            stylesMarkdown: true,
            onPasteImage: { data, ext in
                model.markdown(forPastedImage: data, fileExtension: ext)
            },
            onPasteLink: { model.markdown(forPastedLink: $0) },
            onDelete: { Task { await model.delete() } },
            // 본문이 종이의 거의 전부다. 여기서 끌기를 창에 넘겨주지 않으면
            // 메모를 옮길 자리가 남지 않는다.
            movesWindow: true,
            blursOnEscape: true,
            // Esc 는 손을 떼는 데서 끝나지 않는다 — 종이째 서랍으로 (§7.1 일곱째 규칙).
            onEscape: onEscape,
            placeholder: "…",
            onEdit: model.edited,
            onHeightChange: onTextHeight,
            onOverflowChange: { textOverflows = $0 }
        )
        // 아래로 글이 더 있으면 바닥에 작은 화살표 하나 — 스크롤러는 숨어 있어서, 카드가 종이 아래를
        // 차지해 글 칸이 짧아지면 잘린 줄이 «사라진 글»로 읽혔다 (2026-09-18 사용자). 페이드 대신 화살표인
        // 이유: 종이는 색이 스미고 테마가 갈려 바탕과 같은 색을 지어 덮을 수가 없다.
        .overlay(alignment: .bottom) {
            if textOverflows {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.ink.opacity(0.35))
                    .padding(.bottom, 2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .animation(Theme.reveal, value: textOverflows)
    }

    // MARK: 겹쳐 뜨는 조작

    // 조작 줄은 **두 모서리로 나뉜다.**
    //
    // 한 줄에 다섯을 담으면 캡슐이 106pt 가 되는데, 기본 종이는 260pt 이고
    // 글이 놓이는 폭은 220pt 다. 그것이 첫 줄 위에 뜨니 **제목의 절반이
    // 덮였다** — 그런데 캡슐을 부르는 손짓(포인터 올리기)이 곧 읽으려는
    // 손짓이다. 읽으려고 다가가면 읽을 것이 가려지는, 스스로를 무는 조작이었다.
    //
    // 첫 줄은 이 앱에서 가장 비싼 한 줄이다 — 메뉴 목록도, 빠른 입력도,
    // 달력도 그 줄을 제목으로 쓴다. 그래서 첫 줄을 비우는 쪽을 골랐다.
    //
    // 치우기(×)만 오른쪽 위에 남긴다. 창을 닫으러 가는 손은 오른쪽 위 모서리로
    // 가고, 그 습관을 이 앱만 다르게 만들 이유가 없다. 혼자 남으면 24pt 라
    // 첫 줄의 끝자락만 스친다.
    //
    // 나머지 넷은 종이 아래로 내린다. 마지막 줄은 제목이 아니고, 꼬리(날짜·태그)는
    // 왼쪽에 붙으므로 오른쪽 아래는 대개 비어 있다. 덤으로 **지우기와 치우기가
    // 종이의 높이만큼 멀어졌다** — §6 이 원하던 갈라 놓기가 더 세졌다.

    /// 오른쪽 위 — 치우기 하나.
    private var closeControl: some View {
        QuietButton(symbol: "xmark", help: L("치우기 — 서랍에 들어갑니다. 지워지지 않습니다"), action: onClose)
            .padding(NoteControlLayout.capsulePadding)
            .background { RaisedSurface(ink: color.ink) }
            .padding(NoteControlLayout.closeInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .transition(.opacity)
    }

    /// 오른쪽 아래 — 종이를 다루는 나머지.
    private var paperControls: some View {
        HStack(spacing: NoteControlLayout.spacing) {
            // 지우기는 **가장 먼 왼쪽**에 두고 색으로 갈라 놓는다. 붉은 휴지통과
            // 회색 ×는 반쯤 보고도 구별된다 (설계문서 §6).
            QuietButton(symbol: "trash", help: L("지우기 — 메뉴의 되돌리기로 살릴 수 있습니다"), isDestructive: true) {
                Task { await model.delete() }
            }

            // 시스템 `Divider` 는 이 작은 캡슐 안에서 거의 안 보였다 —
            // 지우기와 나머지를 가르는 것이 §6 의 안전장치인데 그 선이
            // 안 보이면 장치가 아니다. 잉크로 직접 긋는다.
            Rectangle()
                .fill(Paper.ink.opacity(0.20))
                .frame(width: 1, height: 12)
                .padding(.horizontal, Theme.hairline)

            // **`claude` 가 없으면 이 자리도 없다.** 안 되는 버튼을 놓아 두는
            // 것보다 아예 없는 편이 낫다 (`ClaudeCLI` — 있으면 켜지고 없으면
            // 조용히 없다). 그래서 아래 꼬리가 비워 둘 폭도 함께 달라진다.
            if model.canTidy {
                QuietButton(
                    symbol: "sparkles",
                    help: L("다듬기 — Claude 가 이 메모를 읽기 좋게 고칩니다. 8초 안에 되돌릴 수 있습니다")
                ) {
                    Task { await model.tidyWithClaude() }
                }
            }

            // **색과 고정은 여기 없다 — 우클릭으로 갔다** (`paperMenu`).
            //
            // 다섯이 서 있을 때 캡슐이 136pt 였고, 260pt 짜리 종이의 꼬리에
            // 남는 자리가 87pt 였다. 날짜 한 줄이 100pt 남짓이므로 **날짜가
            // 캡슐 밑으로 들어가고 있었다.** 그리고 그 다섯을 1pt 간격으로
            // 붙여 둔 탓에 겨냥까지 필요했다.
            //
            // 덜어 낼 것은 «자주 하지 않고, 잘못 눌러도 값이 싼» 것이다 —
            // 색과 고정이 그렇다. 지우기는 값이 비싸서, 달력과 다듬기는
            // 자주 써서 남는다.

            // 자리를 옮기는 길 (§7.2). 날짜를 얻으면 이 종이는 달력이 맡으므로
            // 바탕화면에서 물러난다 — 그것이 이 버튼이 하는 일의 전부다.
            //
            // 강조하지 않는다. "이 메모는 달력에 있다" 는 꼬리의 날짜가 이미
            // 말하고 있고, 조작 줄에서 색을 쓰는 것은 되돌아오지 않는 쪽
            // (붉은 휴지통)과 다른 표시가 없는 것(고정)뿐이다.
            QuietButton(
                symbol: model.memo.isScheduled ? "calendar" : "calendar.badge.plus",
                help: model.memo.isScheduled
                    ? L("달력에서 보기")
                    : L("달력에 놓기 — 날을 고르면 이 종이는 달력이 맡습니다"),
                action: onCalendar
            )
        }
        .padding(NoteControlLayout.capsulePadding)
        // 글자 위에 겹치므로 얇은 바탕이 필요하다. 없으면 아이콘이 본문에 묻힌다.
        // **떠 있는 것은 바탕보다 밝다** — 맨 종이로 칠하면 다크에서 이 조각이
        // 색이 스민 종이보다 어두워져 파인 구멍으로 보인다 (`PaperTint.raised`).
        .background { RaisedSurface(ink: color.ink) }
        .padding(NoteControlLayout.paperInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .transition(.opacity)
    }

    /// 우클릭 메뉴. 캡슐이 감당 못 하는 것들이 여기 산다.
    ///
    /// **지우기도 여기 둔다.** 캡슐에 이미 있지만, 우클릭으로 열었을 때
    /// «여기서는 못 지우나» 가 되면 안 된다 — 한 길만 있는 것보다 두 길이
    /// 같은 것을 하는 편이 낫다.
    @ViewBuilder private var paperMenu: some View {
        // 다시 보기 — 일정은 두고 이 종이를 다시 펼칠 시각. 알림 켜기도 같은 창에 있다.
        Button { model.showRecall() } label: { Label(L("다시 보기…"), systemImage: "bell") }
        // 말로 시킨다 — 「금요일 10시에 다시 알려줘」. 빠른 입력 상자가 이 메모를 「열린 메모」로 들고 열린다.
        if let openAssistant = model.openAssistant {
            Button { openAssistant(model.memo.id) } label: { Label(L("이 메모에게 시키기…"), systemImage: "sparkles") }
        }
        Divider()
        if model.canTidy {
            Button(L("다듬기")) { Task { await model.tidyWithClaude() } }
        }
        Button(model.memo.pinned ? L("고정 해제") : L("고정")) {
            Task { await model.togglePin() }
        }
        Menu(L("색")) {
            ForEach(MemoColor.allCases, id: \.self) { candidate in
                Button(candidate.label) { Task { await model.setColor(candidate) } }
            }
        }
        Divider()
        // **폴더에 넣기 = 서랍에 넣기 + 이름표.** 이름표만 달고 종이를 그대로
        // 두면 사람은 아무 일도 안 일어난 것으로 본다 — 폴더는 서랍의 칸이므로
        // (`MemoFolders`) 넣는 순간 종이는 서랍으로 간다.
        Menu(L("서랍에 넣기")) {
            Button(L("폴더 없이")) { onClose() }
            let folders = model.folderNames()
            if !folders.isEmpty {
                Divider()
                ForEach(folders, id: \.self) { name in
                    Button {
                        Task {
                            await model.setFolder(name)
                            onClose()
                        }
                    } label: {
                        if name == model.memo.folder {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            }
            if model.memo.folder != nil {
                Divider()
                Button(L("폴더 이름표 떼기")) { Task { await model.setFolder(nil) } }
            }
        }
        Divider()
        Button(L("지우기"), role: .destructive) { Task { await model.delete() } }
    }

    private var colorButton: some View {
        Button { isPickingColor.toggle() } label: {
            Circle()
                .fill(color.tint)
                .frame(width: 11, height: 11)
                // 캡슐의 폭 셈이 버튼 하나를 이만큼으로 친다
                // (`NoteControlLayout.capsuleWidth`). 여기만 작으면 그림도
                // 어긋나고 시험이 지키는 숫자도 어긋난다.
                .frame(width: NoteControlLayout.button, height: NoteControlLayout.button)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .spoken(L("색 바꾸기 — 지금은 \(color.label)"))
        .popover(isPresented: $isPickingColor, arrowEdge: .bottom) {
            colorPicker
        }
    }

    private var colorPicker: some View {
        HStack(spacing: Theme.snug) {
            ForEach(MemoColor.allCases, id: \.self) { candidate in
                Button {
                    isPickingColor = false
                    Task { await model.setColor(candidate) }
                } label: {
                    Circle()
                        .fill(candidate.tint)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    candidate == color ? Color.primary.opacity(0.55) : .clear,
                                    lineWidth: 2
                                )
                                .padding(-3)
                        }
                        // 여섯 개가 나란히 선 자리다. 원만 한 과녁이면 사이의
                        // 여백이 전부 헛손질이 된다.
                        .hitTarget(Theme.touch + 2)
                }
                .buttonStyle(.plain)
                .spoken(candidate.label)
            }
        }
        .padding(.horizontal, Theme.snug)
        .padding(.vertical, Theme.tight)
    }

    // MARK: 붙인 사진

    /// 붙여넣은 사진. 본문에는 마크다운 참조가 남고 실제 그림은 여기 붙는다.
    ///
    /// 높이에 뚜껑이 있고 포인터를 올리면 원본 크기로 펼친다 — 까닭은
    /// `PhotoStrip` 에 적어 두었다.
    ///
    /// 글줄 사이에 그림을 끼워 넣지 않는 이유: 편집기의 글자를 건드리지 않는다는
    /// 규칙(`MarkdownScanner`)을 지키면서 인라인 그림을 그리려면 원문을 숨기는
    /// 편법이 필요하고, 그러면 커서와 되돌리기가 어긋난다. 종이에 사진을
    /// 붙이는 것도 대개 글 아래다.
    private var photographs: some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            ForEach(model.images) { attachment in
                PhotoStrip(
                    attachment: attachment,
                    originalURL: model.originalURL(for: attachment),
                    maxHeight: photoCap
                )
                // 사진은 사진에서 뗀다 — 본문의 참조는 감춰져 있어 글 칸에는 잡을 것이 없다.
                // 종이의 메뉴는 그대로 뒤에 붙는다: 사진 위에서도 종이는 종이다.
                .contextMenu {
                    Button(role: .destructive) { Task { await model.removePhoto(attachment.path) } } label: {
                        Label(L("사진 떼기"), systemImage: "photo.badge.minus")
                    }
                    Divider()
                    paperMenu
                }
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
    }

    // MARK: 붙인 링크

    /// 링크를 카드로 펼친다.
    ///
    /// 본문에는 여전히 `[이름](주소)` 가 남아 있고 카드는 그 아래에 붙는다 —
    /// 사진과 같은 규칙이다. 날 것의 주소는 사람이 읽어도 무엇인지 모르는데,
    /// 게으른 사람에게 "이게 뭐였더라" 를 남기는 것이 이 앱의 가장 흔한 실패다.
    private var linkCards: some View {
        // 둘 이상이면 한 줄씩 — 카드마다 두 줄과 그림을 주면 종이 아래를 카드가 다 차지해 글이
        // 잘린다 (정리한 메모의 「출처」는 늘 둘·셋이다).
        let compact = model.links.count >= 2
        return VStack(alignment: .leading, spacing: compact ? Theme.hairline : Theme.tight) {
            ForEach(model.links) { card in
                Button {
                    NSWorkspace.shared.open(card.url)
                } label: {
                    linkCard(card, compact: compact)
                }
                .buttonStyle(.plain)
                .help(card.url.absoluteString)
                .accessibilityLabel(Text("\(card.title), \(card.host)"))
                .accessibilityHint(Text(L("링크 열기")))
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
    }

    private func linkCard(_ card: LinkPreviewStore.Card, compact: Bool = false) -> some View {
        let side: CGFloat = compact ? 18 : 40
        return HStack(spacing: compact ? Theme.tight : Theme.snug) {
            if let image = card.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Paper.ink.opacity(0.06))
                    .frame(width: side, height: side)
                    .overlay {
                        Image(systemName: "link")
                            .font(.system(size: compact ? 9 : 13))
                            .foregroundStyle(Paper.fadedInk)
                    }
            }

            if compact {
                // 좁은 종이에서는 제목이 이긴다 — 「2025 다이…  aiart0114.tistory.com」은 무엇인지 모른다.
                Text(card.title)
                    .font(Theme.label)
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Text(card.host)
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.40))
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(Theme.label)
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(card.host)
                        .font(Theme.micro)
                        .foregroundStyle(Paper.ink.opacity(0.40))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? Theme.hairline + 1 : Theme.tight)
        .padding(.horizontal, Theme.tight)
        .background {
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(Paper.ink.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(Paper.ink.opacity(0.08), lineWidth: 0.75)
        }
        .contentShape(.rect)
    }

    // MARK: 방금 지운 종이

    /// 지운 자리에 그대로 남는 되돌리기 (D6) — **창이 소리 없이 사라지지 않는다.**
    ///
    /// 지우는 길이 셋인데(종이·메뉴 목록·빠른 입력) 되돌리는 줄이 그 자리에
    /// 생기는 것은 둘뿐이었다. 종이의 휴지통만 창이 사라지고 화면에 흔적이
    /// 하나도 안 남아서, 잘못 눌렀다는 것을 아는 그 순간에 되돌릴 길이 메뉴
    /// 안에만 있었다 — 상자를 닫고 아이콘을 눌러 찾아 들어가야 하는 길이다.
    ///
    /// 8초 뒤에는 스스로 물러난다. 그 뒤로도 되돌릴 수는 있다 — 메뉴가 5분
    /// 동안 들고 있고, 휴지통은 30일이다 (`MenuBarController`).
    /// Claude 가 다듬는 동안, 그리고 다듬은 직후에 뜨는 한 줄.
    ///
    /// **본문을 덮지 않는다.** 지우기의 되돌리기는 종이를 통째로 덮지만(그때는
    /// 글이 없어진 것이므로), 다듬기는 글이 **바뀐** 것이라 바뀐 글이 보여야
    /// 되돌릴지 말지를 정할 수 있다.
    @ViewBuilder private var thinkingBar: some View {
        HStack(spacing: Theme.tight) {
            switch model.thinking {
            case .working:
                Text(L("다듬는 중…"))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.fadedInk)
            case .done:
                Text(L("다듬었습니다"))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.fadedInk)
                Button { Task { await model.undoTidy() } } label: {
                    // 8초 안에 닿아야 하는 자리다. 급한 손에 13pt 를 내밀지 않는다.
                    Text(L("되돌리기"))
                        .font(Theme.micro)
                        .padding(.horizontal, Theme.tight)
                        .hitTarget(Theme.touchRow)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accentInk)
                .spoken(L("되돌리기 — 다듬기 전의 글로 되돌립니다"))
            case .failed(let reason):
                Text(reason)
                    .font(Theme.micro)
                    .foregroundStyle(Paper.fadedInk)
                    .lineLimit(2)
            case .none:
                EmptyView()
            }
            Spacer(minLength: NoteControlLayout.footerReserve(buttons: controlCount))
        }
        .padding(.horizontal, NoteControlLayout.footerInset)
        .padding(.bottom, Theme.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .transition(.opacity)
    }

    private func deletedVeil(_ deleted: Memo) -> some View {
        VStack(spacing: Theme.tight) {
            Text(L("「\(deleted.title)」 지웠습니다"))
                .font(Theme.label)
                .foregroundStyle(Paper.fadedInk)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button {
                Task { await model.restoreDeleted() }
            } label: {
                // 방금 잘못 지운 사람이 오는 자리다 — 이 종이에서 가장 넉넉해야 한다.
                Text(L("되돌리기"))
                    .font(Theme.label)
                    .padding(.horizontal, Theme.snug)
                    .hitTarget(Theme.touch)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accentInk)
            .spoken(L("되돌리기 — 방금 지운 이 메모를 되살립니다"))
        }
        .padding(Theme.normal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 지운 종이는 글이 아니라 이 한 줄만 든다. 아래에 본문이 비쳐
        // 보이면 "안 지워졌나" 가 된다.
        .background { Theme.paper(color.ink, dotted: false) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .transition(.opacity)
    }

    // MARK: 아직 안 적힌 종이

    /// 저장이 안 됐다는 것을 **종이가 스스로 말한다.**
    ///
    /// 이 앱에는 저장 버튼이 없으므로 "적혔겠지" 가 기본 믿음이다. 그런데 안
    /// 적힌 글도 화면에는 그대로 있어서 적힌 것과 **똑같이 보이고**, 그 상태로
    /// 창을 닫으면 그대로 잃는다.
    ///
    /// 조용한 화면(철학 4)에 여는 예외다. 이건 앱이 자기를 드러내는 것이
    /// 아니라 사용자의 글을 지키는 일이고, 포인터가 오기를 기다릴 수도 없다 —
    /// 겹쳐 뜨는 조작과 달리 **보러 오지 않아도 보여야 하는** 종류다.
    private var unsavedMark: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
            Text(L("아직 안 적혔습니다"))
                .font(Theme.micro)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.dangerInk)
        .padding(.horizontal, NoteControlLayout.footerInset)
        .padding(.bottom, hasFooter ? Theme.hairline : Theme.normal)
        .help(L("파일에 쓰지 못했습니다 — 글이 사라지지 않게 다른 곳에 옮겨 두세요"))
        .transition(.opacity)
    }

    // MARK: 꼬리 — 날짜와 태그가 있을 때만

    /// 종이의 마지막 줄 — 언제·어디·무엇에 대하여.
    ///
    /// **한 줄이 원칙이고, 두 줄은 양보다.** 이 줄은 겹쳐 뜨는 캡슐이 덮지 않도록
    /// 오른쪽을 미리 비워 둔 자리라(`NoteControlLayout.footerReserve`), 셋을 억지로
    /// 밀어 넣으면 날짜가 접혀 세 줄이 된다 — 실제로 그렇게 됐다. 자리가 모자라면
    /// **장소가 아랫줄로 내려앉는다.** 접히는 것이지 사라지는 것이 아니고, 캡슐이
    /// 비워야 할 자리도 그때는 아랫줄로 함께 옮겨 간다.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.tight) {
                scheduleMark
                surfaceMark
                placeMark
                tagMark
                Spacer(minLength: NoteControlLayout.footerReserve(buttons: controlCount))
            }
            .padding(.bottom, Theme.normal)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.tight) {
                    scheduleMark
                    surfaceMark
                    tagMark
                    Spacer(minLength: 0)
                }
                HStack(spacing: Theme.tight) {
                    placeMark
                    Spacer(minLength: NoteControlLayout.footerReserve(buttons: controlCount))
                }
            }
            // 두 줄이면 꼬리가 캡슐 위로 올라선다 (`footerTwoLineInset`) —
            // 윗줄에는 비워 둘 자리가 없기 때문이다.
            .padding(.bottom, NoteControlLayout.footerTwoLineInset)
        }
        .padding(.horizontal, NoteControlLayout.footerInset)
    }

    /// 날짜는 **적힌 것이자 누를 수 있는 것**이다. 이 메모가 달력의 어느 칸에
    /// 서 있는지는 여기서 한 번에 가는 길이 없으면 달력을 열어 그 달까지 손으로
    /// 넘겨야 알 수 있다.
    @ViewBuilder private var scheduleMark: some View {
        if scheduleLabel != nil {
            Button(action: onCalendar) {
                Label {
                    // **한 조각이다.** 「오후 3:00」과 「30분 전」을 두 칩으로
                    // 나누면 무엇이 일정이고 무엇이 알림인지 매번 읽어야 한다.
                    Text(scheduleText).font(Theme.micro).lineLimit(1)
                } icon: {
                    Image(systemName: model.memo.at != nil ? "clock" : "calendar")
                        .font(.system(size: 9))
                }
                .foregroundStyle(isPast ? Paper.ink.opacity(0.35) : Paper.fadedInk)
                // 글자는 그대로 두고 누르는 자리만 위아래로 넓힌다. 이 줄의
                // 높이는 `NoteControlLayout.footerLine` 이 알고 있다 — 캡슐이
                // 이 줄에 닿는지 그 숫자로 셈하므로 둘이 함께 움직여야 한다.
                .frame(minHeight: NoteControlLayout.footerLine)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .spoken(L("달력에서 보기 — 이 일정이 달력의 어디에 있는지 펼칩니다"))
        }
    }

    /// 일정이 없는데 나올 때만 정해진 종이. 「금요일 아침에 이거 다시 보여줘」다.
    ///
    /// 누를 수 있게 만들지 않았다 — 달력에 없는 시각이라 **갈 곳이 없다.**
    /// 날짜 칩이 누를 수 있는 이유는 그 메모가 달력의 어딘가에 서 있기 때문이고,
    /// 이것은 그렇지 않다 (`Memo.surface` — 자리를 바꾸지 않는다).
    @ViewBuilder private var surfaceMark: some View {
        if !model.memo.isScheduled, let surface = model.memo.surface {
            Label {
                Text(Self.surfaceText(surface)).font(Theme.micro).lineLimit(1)
            } icon: {
                Image(systemName: "arrow.up").font(.system(size: 9))
            }
            .foregroundStyle(surface <= model.asOf ? Paper.ink.opacity(0.35) : Paper.fadedInk)
            .help(L("이 시각에 종이가 앞으로 나옵니다"))
            .accessibilityLabel(Text(L("\(Self.surfaceText(surface))에 이 종이가 앞으로 나옵니다")))
        }
    }

    static func surfaceText(_ surface: Date) -> String {
        L("\(surface.formatted(.dateTime.month().day())) \(surface.formatted(.dateTime.hour().minute())) 나옴")
    }

    /// 장소도 누를 수 있다. 다만 날짜와 다르다 — 날짜를 누르면 이 메모가 옮겨
    /// 앉은 곳(달력)으로 가지만, 장소를 눌러도 **이 종이는 그대로 있고** 지도만
    /// 바깥에서 열린다. 장소는 자리를 정하지 않는다 (§14.2, `MapLink`).
    @ViewBuilder private var placeMark: some View {
        if let mark = NoteFooter.placeLabel(for: model.memo) {
            Button {
                if let url = MapLink.url(for: model.memo) { NSWorkspace.shared.open(url) }
            } label: {
                Label {
                    Text(mark).font(Theme.micro).lineLimit(1).truncationMode(.tail)
                } icon: {
                    Image(systemName: "mappin").font(.system(size: 9))
                }
                .foregroundStyle(Paper.fadedInk)
                .frame(minHeight: NoteControlLayout.footerLine)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .spoken(L("지도에서 보기 — \(mark) 을(를) 지도 앱에서 엽니다"))
        }
    }

    @ViewBuilder private var tagMark: some View {
        if !model.memo.tags.isEmpty {
            Text(model.memo.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                .font(Theme.micro)
                .foregroundStyle(Paper.ink.opacity(0.40))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    /// 사진 한 장이 종이에서 가질 수 있는 최대 높이.
    ///
    /// **고정값으로 두었다가 작은 메모를 통째로 잡아먹었다.** 기본 창은
    /// 260×200 인데 116pt 를 사진이 가져가면 글은 한 줄만 남는다. 종이는
    /// 글을 적는 곳이지 앨범이 아니므로, 몫을 높이에 비례해 나누고 여러
    /// 장이면 그 몫을 다시 나눈다. 제대로 보는 것은 포인터를 올렸을 때다.
    private var photoCap: CGFloat {
        let share = paperHeight > 0 ? paperHeight * 0.4 : 116
        let each = model.images.count > 1 ? share / 1.6 : share
        return max(44, min(each, 116))
    }

    /// 지난 일정은 한 걸음 더 물러난다. 지우라고 재촉하지는 않는다 (철학 1).
    private var isPast: Bool {
        guard let scheduled = model.memo.scheduledDate() else { return false }
        return scheduled < CalendarDate(Date())
    }

    /// 일정 칩에 적히는 말. 「나올 때」가 따로 있으면 한 조각으로 붙인다.
    private var scheduleText: String {
        guard let schedule = scheduleLabel else { return "" }
        // 「9월 1일 화 · 30분 전 · 매주」. 셋 다 같은 시각을 가리키는 말이라
        // 한 조각으로 붙는다 — 되풀이는 날짜를 **한정하는 말**이지 별개의 값이
        // 아니다 (`Recurrence` — 주기만 말하고 언제인지는 날짜가 들고 있다).
        return [schedule, model.memo.surfaceLead, model.memo.every?.text()]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var scheduleLabel: String? {
        if let at = model.memo.at {
            // 날과 시각을 따로 적는다 — 한 벌로 적으면 영어가 「Aug 31 at 2:30 PM」으로
            // 늘어나 꼬리에서 잘린다. 한국어는 어느 쪽이든 「8월 31일 오후 2:30」이다.
            return "\(at.formatted(.dateTime.month().day())) \(at.formatted(.dateTime.hour().minute()))"
        }
        if let due = model.memo.due, let start = due.startOfDay() {
            return start.formatted(.dateTime.month().day().weekday(.abbreviated))
        }
        return nil
    }
}
