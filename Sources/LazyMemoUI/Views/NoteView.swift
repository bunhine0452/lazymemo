import LazyMemoCore
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
    /// 달력으로 건너가는 길 (설계문서 §7.2).
    ///
    /// 날짜가 없으면 **놓을 날을 고르러** 가고, 있으면 그 일정이 달력의
    /// 어디에 있는지 **보러** 간다. 어느 쪽인지는 부르는 쪽이 정한다 —
    /// 종이는 달력 창을 알지 못한다.
    var onCalendar: () -> Void = {}
    /// 종이가 얼마나 진한가. 창 전체가 함께 쓰는 값이다 (`PaperAppearance`).
    var appearance: PaperAppearance? = nil
    /// 화면 밖 렌더에서 조작 줄을 펴 보이기 위한 연출값 (설계문서 §14.9).
    /// 포인터가 없는 렌더에서는 겹쳐 뜨는 조작이 하나도 나타나지 않는다.
    var staged = false

    @State private var isHovering = false
    @State private var isPickingColor = false
    /// 종이의 높이. 사진이 가질 수 있는 몫을 여기서 잰다.
    @State private var paperHeight: CGFloat = 0

    private var color: MemoColor { model.memo.color }
    private var hasFooter: Bool { model.memo.isScheduled || !model.memo.tags.isEmpty }

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
                editor
                if !model.images.isEmpty { photographs }
                if !model.links.isEmpty { linkCards }
                if model.isUnsaved { unsavedMark }
                if hasFooter { footer }
            }
            // 종이는 누레지지만 잉크는 그만큼 사라지지 않는다. 오래된 메모도
            // 읽을 수는 있어야 한다 — 물러나는 것과 안 보이는 것은 다르다.
            .opacity(0.72 + 0.28 * age.presence)

            if showsControls, model.justDeleted == nil {
                // 치우기는 모서리에 남고, 나머지는 종이 아래로 내려간다.
                closeControl
                paperControls
            }

            // 방금 지웠으면 그 자리에 되돌리는 줄이 덮인다 (D6).
            if let deleted = model.justDeleted { deletedVeil(deleted) }
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
        // `.onHover` 는 키 윈도에서만 반응한다. 바탕화면의 종이는 다른 앱을
        // 쓰는 동안에도 되살아나야 하므로 감지기를 따로 둔다.
        .overlay { HoverSensor { isHovering = $0 } }
        .opacity(paperOpacity)
        .animation(Theme.reveal, value: isHovering)
        .animation(Theme.reveal, value: model.isUnsaved)
        .animation(Theme.reveal, value: model.justDeleted?.id)
        .animation(Theme.settle, value: age)
        .animation(Theme.settle, value: paperOpacity)
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
            placeholder: "…",
            onEdit: model.edited
        )
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
        QuietButton(symbol: "xmark", help: "치우기 — 메모는 지워지지 않습니다", action: onClose)
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
            QuietButton(symbol: "trash", help: "지우기 — 메뉴의 되돌리기로 살릴 수 있습니다", isDestructive: true) {
                Task { await model.delete() }
            }

            // 시스템 `Divider` 는 이 작은 캡슐 안에서 거의 안 보였다 —
            // 지우기와 나머지를 가르는 것이 §6 의 안전장치인데 그 선이
            // 안 보이면 장치가 아니다. 잉크로 직접 긋는다.
            Rectangle()
                .fill(Paper.ink.opacity(0.20))
                .frame(width: 1, height: 12)
                .padding(.horizontal, Theme.hairline)

            colorButton

            QuietButton(
                symbol: model.memo.pinned ? "pin.fill" : "pin",
                help: model.memo.pinned ? "고정 해제" : "고정",
                isActive: model.memo.pinned
            ) {
                Task { await model.togglePin() }
            }

            // 자리를 옮기는 길 (§7.2). 날짜를 얻으면 이 종이는 달력이 맡으므로
            // 바탕화면에서 물러난다 — 그것이 이 버튼이 하는 일의 전부다.
            //
            // 강조하지 않는다. "이 메모는 달력에 있다" 는 꼬리의 날짜가 이미
            // 말하고 있고, 조작 줄에서 색을 쓰는 것은 되돌아오지 않는 쪽
            // (붉은 휴지통)과 다른 표시가 없는 것(고정)뿐이다.
            QuietButton(
                symbol: model.memo.isScheduled ? "calendar" : "calendar.badge.plus",
                help: model.memo.isScheduled
                    ? "달력에서 보기"
                    : "달력에 놓기 — 날을 고르면 이 종이는 달력이 맡습니다",
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

    private var colorButton: some View {
        Button { isPickingColor.toggle() } label: {
            Circle()
                .fill(color.tint)
                .frame(width: 10, height: 10)
                .frame(width: 18, height: 18)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .spoken("색 바꾸기 — 지금은 \(color.label)")
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
                        .frame(width: 17, height: 17)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    candidate == color ? Color.primary.opacity(0.55) : .clear,
                                    lineWidth: 2
                                )
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
                .spoken(candidate.label)
            }
        }
        .padding(Theme.normal)
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
        VStack(alignment: .leading, spacing: Theme.tight) {
            ForEach(model.links) { card in
                Button {
                    NSWorkspace.shared.open(card.url)
                } label: {
                    linkCard(card)
                }
                .buttonStyle(.plain)
                .help(card.url.absoluteString)
                .accessibilityLabel(Text("\(card.title), \(card.host)"))
                .accessibilityHint(Text("링크 열기"))
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
    }

    private func linkCard(_ card: LinkPreviewStore.Card) -> some View {
        HStack(spacing: Theme.snug) {
            if let image = card.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Paper.ink.opacity(0.06))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "link")
                            .font(.system(size: 13))
                            .foregroundStyle(Paper.fadedInk)
                    }
            }

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

            Spacer(minLength: 0)
        }
        .padding(Theme.tight)
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
    private func deletedVeil(_ deleted: Memo) -> some View {
        VStack(spacing: Theme.tight) {
            Text("「\(deleted.title)」 지웠습니다")
                .font(Theme.label)
                .foregroundStyle(Paper.fadedInk)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button("되돌리기") {
                Task { await model.restoreDeleted() }
            }
            .buttonStyle(.plain)
            .font(Theme.label)
            .foregroundStyle(Theme.accentInk)
            .spoken("되돌리기 — 방금 지운 이 메모를 되살립니다")
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
            Text("아직 안 적혔습니다")
                .font(Theme.micro)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.dangerInk)
        .padding(.horizontal, NoteControlLayout.footerInset)
        .padding(.bottom, hasFooter ? Theme.hairline : Theme.normal)
        .help("파일에 쓰지 못했습니다 — 글이 사라지지 않게 다른 곳에 옮겨 두세요")
        .transition(.opacity)
    }

    // MARK: 꼬리 — 날짜와 태그가 있을 때만

    private var footer: some View {
        HStack(spacing: Theme.tight) {
            if let schedule = scheduleLabel {
                // 날짜는 **적힌 것이자 누를 수 있는 것**이다. 이 메모가 달력의
                // 어느 칸에 서 있는지는 여기서 한 번에 가는 길이 없으면
                // 달력을 열어 그 달까지 손으로 넘겨야 알 수 있다.
                Button(action: onCalendar) {
                    Label {
                        Text(schedule).font(Theme.micro)
                    } icon: {
                        Image(systemName: model.memo.at != nil ? "clock" : "calendar")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(isPast ? Paper.ink.opacity(0.35) : Paper.fadedInk)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .spoken("달력에서 보기 — 이 일정이 달력의 어디에 있는지 펼칩니다")
            }

            if !model.memo.tags.isEmpty {
                Text(model.memo.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.40))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // 아래 캡슐이 뜰 자리를 **미리 비워 둔다** (`NoteControlLayout`).
            // 첫 줄을 비우려고 조작을 내렸더니 이번에는 이 줄이 덮였다 —
            // 태그의 오른쪽이 캡슐 밑으로 들어가 있었다. 가려진 것은 가려진
            // 줄도 모르고, 잘린 것은 잘린 줄 안다.
            Spacer(minLength: NoteControlLayout.footerReserve())
        }
        .padding(.horizontal, NoteControlLayout.footerInset)
        .padding(.bottom, Theme.normal)
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

    private var scheduleLabel: String? {
        if let at = model.memo.at {
            return at.formatted(.dateTime.month().day().hour().minute())
        }
        if let due = model.memo.due, let start = due.startOfDay() {
            return start.formatted(.dateTime.month().day().weekday(.abbreviated))
        }
        return nil
    }
}
