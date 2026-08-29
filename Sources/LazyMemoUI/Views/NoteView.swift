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
    private var age: MemoAge {
        showsControls ? .fresh : MemoAge.of(model.memo)
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
                if hasFooter { footer }
            }
            // 종이는 누레지지만 잉크는 그만큼 사라지지 않는다. 오래된 메모도
            // 읽을 수는 있어야 한다 — 물러나는 것과 안 보이는 것은 다르다.
            .opacity(0.72 + 0.28 * age.presence)

            if showsControls {
                controls
            }
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

    private var controls: some View {
        HStack(spacing: 1) {
            // 지우기는 **가장 먼 왼쪽**에 두고 색으로 갈라 놓는다. 닫기(×)를
            // 향해 모서리로 뻗는 손이 지나가지 않는 자리이며, 붉은 휴지통과
            // 회색 ×는 반쯤 보고도 구별된다 (설계문서 §6).
            QuietButton(symbol: "trash", help: "지우기 — 메뉴의 되돌리기로 살릴 수 있습니다", isDestructive: true) {
                Task { await model.delete() }
            }

            Divider()
                .frame(height: 11)
                .padding(.horizontal, Theme.hairline)
                .opacity(0.35)

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

            QuietButton(symbol: "xmark", help: "치우기 — 메모는 지워지지 않습니다", action: onClose)
        }
        .padding(3)
        .background {
            // 글자 위에 겹치므로 얇은 바탕이 필요하다. 없으면 아이콘이 본문에 묻힌다.
            Capsule().fill(Paper.surface).shadow(color: .black.opacity(0.14), radius: 3, y: 1)
        }
        .padding(Theme.tight)
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
        .help("색 바꾸기")
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
                .help(candidate.label)
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
                .help("달력에서 보기")
            }

            if !model.memo.tags.isEmpty {
                Text(model.memo.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.loose + 5)
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
