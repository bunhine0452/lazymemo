import LazyMemoCore
import SwiftUI

/// 「달력」 — 바탕화면에 놓인, **손으로 만지는** 달 (설계문서 §10).
///
/// 앞선 판은 아래로 흐르는 목록이었고 조작이 하나도 없었다. 게으른 사람이
/// 달력에 하는 일은 셋뿐인데 — **보고, 옮기고, 미룬다** — 그 셋 중 어느 것도
/// 할 수 없는 화면이었다는 뜻이다. 그래서 통째로 바꿨다.
///
/// 화면은 두 층이다. 위는 **조망**(어느 날이 붐비는가), 아래는 **조작**(그 날의
/// 일을 집어 옮긴다). 두 층이 한 창에 있어야 "31일로 옮기기" 가 한 동작이 된다 —
/// 목록만 있으면 날짜를 글자로 쳐야 하고, 격자만 있으면 무엇을 옮기는지 알 수 없다.
///
/// 격자가 빈칸을 보여주는 것은 철학 1("완성을 요구하지 않는다")과 부딪히지
/// 않는다. **빈칸이 아니라 바탕이다** — 15일이 무슨 요일인지는 그 사이 빈 칸들이
/// 말해 준다. 채우라고 말하는 것은 빈 칸이 아니라 "일정 없음" 같은 글자와
/// 칸마다 붙은 ＋ 표시이고, 그런 것은 여기에 하나도 없다.
struct CalendarView: View {
    @Bindable var model: CalendarModel
    var onClose: () -> Void
    var onSelectMemo: (ULID) -> Void

    /// 집어 든 일정. 격자 위로 끌고 가는 동안만 존재한다.
    private struct Grip: Equatable {
        let memo: Memo
        var point: CGPoint
        var cell: Int?
        /// 손이 실제로 움직였는가. 안 움직였으면 그것은 끌기가 아니라 누르기다.
        var isDragging: Bool
    }

    private static let space = "calendar"
    private static let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    /// 한 주의 높이. 여기서 격자의 모든 좌표가 나온다.
    private static let weekHeight: CGFloat = 32
    /// 날짜가 앉는 원. 오늘 표시·고른 날 고리가 모두 이 지름을 기준으로 한다.
    private static let markSize: CGFloat = 18
    /// 끌어서 놓을 때 제목 대신 보이는 조각의 최대 글자 수.
    private static let chipLimit = 14

    @State private var isHovering = false
    @State private var hoveredRow: ULID?
    @State private var grip: Grip?
    @State private var geometry = MonthGridGeometry(frame: .zero, rows: 0)
    @State private var isWriting = false
    @State private var draft = ""
    @FocusState private var writerFocused: Bool
    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayRow
            monthGrid
            Rectangle()
                .fill(Paper.ink.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, Theme.normal)
                .padding(.top, Theme.tight)
            dayPanel
        }
        .coordinateSpace(.named(Self.space))
        .background(Theme.paper(MemoColor.gray.ink, dotted: false))
        .overlay(Theme.edge())
        .overlay { carriedChip }
        .overlay { HoverSensor { isHovering = $0 } }
        .animation(Theme.reveal, value: isHovering)
        .animation(Theme.reveal, value: hoveredRow)
        .animation(Theme.reveal, value: dropTarget)
        .animation(Theme.settle, value: model.selected)
        .task { await model.refresh() }
        .onChange(of: model.selected) { closeWriter() }
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(verbatim: "\(model.grid.year)")
                    .font(Theme.micro)
                    .foregroundStyle(.tertiary)
                Text("\(model.grid.month)월")
                    .font(Theme.title)
                    .foregroundStyle(Paper.ink)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: Theme.tight)

            // 오늘로 돌아오는 길은 길을 잃었을 때만 나타난다.
            if !model.isOnToday {
                Button("오늘") { model.goToday() }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.ink.opacity(0.66))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.highlight.opacity(0.32)))
                    .padding(.trailing, 2)
            }

            // 달 이동은 이 창에서 가장 잦은 조작이라 감추지 않는다.
            QuietButton(symbol: "chevron.left", help: "이전 달") { model.stepMonth(-1) }
            QuietButton(symbol: "chevron.right", help: "다음 달") { model.stepMonth(1) }

            if isHovering {
                QuietButton(symbol: "xmark", help: "치우기", action: onClose)
            }
        }
        .padding(.horizontal, Theme.normal)
        .padding(.top, Theme.snug)
        .padding(.bottom, Theme.tight)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { column, symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(columnColor(column).opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.normal)
        .padding(.bottom, 3)
    }

    // MARK: 달 격자 — 조망

    private var monthGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                        cell(day, column: column)
                    }
                }
            }
        }
        // 칸마다 자리를 묻지 않고 격자 하나만 잰다 — 나머지는 산수다
        // (`MonthGridGeometry`). 화면에 뷰 42개를 더 만들지 않기 위한 선택이다.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.space))
        } action: { frame in
            geometry = MonthGridGeometry(frame: frame, rows: model.grid.weeks.count)
        }
        .onChange(of: model.grid.weeks.count) { _, rows in
            geometry.rows = rows
        }
        .padding(.horizontal, Theme.normal)
    }

    private func cell(_ day: MonthGrid.Day, column: Int) -> some View {
        let isToday = model.isToday(day.date)
        let isSelected = day.date == model.selected
        let isTarget = dropTarget == day.date

        return VStack(spacing: 3) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Theme.highlight)
                        .frame(width: Self.markSize, height: Self.markSize)
                } else if isSelected {
                    Circle()
                        .fill(Paper.ink.opacity(0.06))
                        .frame(width: Self.markSize, height: Self.markSize)
                    Circle()
                        .strokeBorder(Paper.ink.opacity(0.28), lineWidth: 1)
                        .frame(width: Self.markSize, height: Self.markSize)
                }

                // 놓을 자리는 고른 날보다 세게 말한다. 손이 이미 움직이는 중이라
                // 흘긋 보고 판단해야 하기 때문이다.
                if isTarget {
                    Circle()
                        .fill(Theme.accent.opacity(0.16))
                        .frame(width: Self.markSize + 4, height: Self.markSize + 4)
                    Circle()
                        .strokeBorder(Theme.accent.opacity(0.9), lineWidth: 1.2)
                        .frame(width: Self.markSize + 4, height: Self.markSize + 4)
                }

                Text("\(day.date.day)")
                    .font(.system(size: 11, weight: isToday ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(numeralColor(day, column: column, isToday: isToday))
            }
            .frame(width: Self.markSize + 6, height: Self.markSize + 2)

            density(model.memos(on: day.date), dimmed: dimness(day))
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.weekHeight)
        .contentShape(.rect)
        .onTapGesture { model.select(day.date) }
        .help(dayHelp(day.date))
    }

    /// 그 날에 일이 얼마나 있는가 — **숫자를 쓰지 않는다.**
    ///
    /// 칸마다 "3" 이라고 적으면 날짜 숫자와 섞여 둘 다 안 읽힌다. 점은 색까지
    /// 들고 올 수 있어서 "파란 그거" 를 자리로 기억하게 해 준다. 넷을 넘으면
    /// 셋째 점이 막대로 늘어난다 — 세는 대신 "많다" 를 말한다.
    @ViewBuilder
    private func density(_ memos: [Memo], dimmed: Double) -> some View {
        if memos.isEmpty {
            Color.clear.frame(height: 3.5)
        } else {
            HStack(spacing: 2.5) {
                ForEach(Array(memos.prefix(3).enumerated()), id: \.offset) { index, memo in
                    Capsule()
                        .fill(memo.color.ink)
                        .opacity(dimmed)
                        .frame(
                            width: index == 2 && memos.count > 3 ? 8 : 3.5,
                            height: 3.5
                        )
                }
            }
        }
    }

    // MARK: 고른 날 — 조작

    private var dayPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(dayTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Paper.ink.opacity(0.72))
                .padding(.bottom, 5)

            rowList

            writer

            if let failure = model.failure {
                Text(failure)
                    .font(Theme.micro)
                    .foregroundStyle(Theme.sunday)
                    .lineLimit(2)
                    .padding(.top, 4)
            } else if let move = model.lastMove {
                undoLine(move)
            }
        }
        .padding(.horizontal, Theme.normal)
        .padding(.top, Theme.snug)
        .padding(.bottom, Theme.snug)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var rowList: some View {
        // ScrollView 는 화면 밖 렌더에서 내용을 그리지 않는다 (`PreviewRenderer`).
        if rendersStatically {
            rows
        } else {
            ScrollView(.vertical) { rows }
                .scrollIndicators(.never)
                .frame(maxHeight: .infinity)
        }
    }

    /// 빈 날에 "일정 없음" 이라고 적지 않는다. 그것은 채우라는 말이고,
    /// 이 앱은 완성을 요구하지 않는다 (철학 1). 아무것도 없으면 아무것도 없다.
    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.selectedMemos) { memo in
                row(memo)
            }
        }
    }

    private func row(_ memo: Memo) -> some View {
        let isCarried = grip?.memo.id == memo.id && grip?.isDragging == true

        return HStack(spacing: Theme.tight + 1) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(memo.color.ink)
                .frame(width: 3, height: 14)

            // 시각은 고정 폭 자리에 둔다. 시각 없는 것이 섞여도 제목이 한 줄로
            // 서고, 콜론이 세로로 맞아 훑어보기가 쉽다.
            Text(clockLabel(memo))
                .font(Theme.microMono)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            Text(memo.title)
                .font(Theme.label)
                .foregroundStyle(Paper.ink.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: Theme.tight)

            if hoveredRow == memo.id, !isCarried {
                postponeButton(memo)
            }
        }
        .padding(.vertical, 3)
        .opacity(isCarried ? 0.22 : 1)
        .contentShape(.rect)
        .overlay {
            HoverSensor { inside in
                if inside { hoveredRow = memo.id }
                else if hoveredRow == memo.id { hoveredRow = nil }
            }
        }
        .gesture(carry(memo))
    }

    /// 하루 미루기 — 게으른 사람이 달력에 가장 자주 하는 일이라 한 번에 닿는다.
    ///
    /// 끌어 놓기로도 되지만 그건 겨냥이 필요하다. 「내일」은 겨냥할 필요가 없어야 한다.
    private func postponeButton(_ memo: Memo) -> some View {
        Button {
            Task { await model.postpone(memo) }
        } label: {
            Text("미루기")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Paper.ink.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        // 누르기 **전에** 어디로 가는지 말해 준다.
        .help(model.postponeTarget(memo).map { "\(dayText($0))로 미룹니다" } ?? "하루 미룹니다")
    }

    // MARK: 집어서 옮기기

    /// 한 제스처가 누르기와 끌기를 겸한다.
    ///
    /// 손이 움직이지 않았으면 **누르기**(메모 열기), 움직였으면 **끌기**(날짜
    /// 옮기기)다. 둘을 따로 두면 목록 위에서 무엇을 하려는 건지 앱이 먼저
    /// 물어봐야 하는데, 그 물음이 곧 불편이다.
    private func carry(_ memo: Memo) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let moved = max(abs(value.translation.width), abs(value.translation.height)) > 3
                grip = Grip(
                    memo: memo,
                    point: value.location,
                    cell: geometry.index(at: value.location),
                    isDragging: moved || grip?.isDragging == true
                )
            }
            .onEnded { value in
                let carried = grip?.isDragging == true
                let landing = geometry.index(at: value.location)
                grip = nil

                guard carried else {
                    onSelectMemo(memo.id)
                    return
                }
                guard let index = landing, let day = model.grid.days[safe: index] else { return }
                Task { await model.move(memo, to: day.date) }
            }
    }

    private var dropTarget: CalendarDate? {
        guard let grip, grip.isDragging, let index = grip.cell else { return nil }
        return model.grid.days[safe: index]?.date
    }

    /// 끌고 다니는 종이 조각. 손끝보다 조금 위에 떠서 목표 칸을 가리지 않는다.
    @ViewBuilder
    private var carriedChip: some View {
        if let grip, grip.isDragging {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(grip.memo.color.ink)
                    .frame(width: 3, height: 11)
                Text(shortTitle(grip.memo.title))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Paper.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Paper.ink.opacity(0.14), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.20), radius: 5, y: 2)
            .fixedSize()
            .position(x: grip.point.x + 6, y: grip.point.y - 13)
            .allowsHitTesting(false)
        }
    }

    // MARK: 적기

    /// 고른 날에 한 줄. 상자를 따로 띄우지 않는다 — 날을 고르고 그 자리에서 친다.
    @ViewBuilder
    private var writer: some View {
        if isWriting {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .font(Theme.label)
                .foregroundStyle(Paper.ink)
                .focused($writerFocused)
                .onSubmit(commit)
                .onExitCommand(perform: closeWriter)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.accent.opacity(0.55)).frame(height: 1)
                }
        } else {
            Button(action: openWriter) {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 8, weight: .semibold))
                    Text("이 날에 적기").font(Theme.micro)
                }
                .foregroundStyle(Paper.ink.opacity(0.26))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }

    private func openWriter() {
        isWriting = true
        writerFocused = true
    }

    private func closeWriter() {
        isWriting = false
        writerFocused = false
        draft = ""
    }

    /// 빈 채로 Return 이면 손을 뗀 것으로 본다. 적었으면 그대로 두고 다음 줄을 기다린다 —
    /// 하나 적고 상자가 닫히면 둘째 줄을 적으려고 다시 눌러야 한다.
    private func commit() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            closeWriter()
            return
        }
        draft = ""
        Task { await model.add(text) }
    }

    // MARK: 되돌리기

    private func undoLine(_ move: CalendarModel.Move) -> some View {
        HStack(spacing: Theme.tight) {
            Text("\(dayText(move.to))로 옮겼습니다")
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
            Button("되돌리기") { Task { await model.undo() } }
                .buttonStyle(.plain)
                .font(Theme.micro)
                .foregroundStyle(Theme.accent)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: 글자와 색

    private var dayTitle: String {
        guard let start = model.selected.startOfDay() else { return model.selected.description }
        let formatted = start.formatted(.dateTime.month().day().weekday(.wide))
        return model.isToday(model.selected) ? "오늘 · \(formatted)" : formatted
    }

    private func dayText(_ date: CalendarDate) -> String {
        "\(date.month)월 \(date.day)일"
    }

    private func dayHelp(_ date: CalendarDate) -> String {
        let count = model.memos(on: date).count
        return count > 0 ? "\(dayText(date)) — \(count)개" : dayText(date)
    }

    /// `14:30`. 로케일 형식(오후 2:30)은 폭이 들쭉날쭉해 세로로 안 맞는다.
    private func clockLabel(_ memo: Memo) -> String {
        guard let at = memo.at else { return "" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: at)
        guard let hour = parts.hour, let minute = parts.minute else { return "" }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func shortTitle(_ title: String) -> String {
        title.count > Self.chipLimit ? String(title.prefix(Self.chipLimit)) + "…" : title
    }

    /// 한국 달력 관행 — 일요일 빨강, 토요일 파랑.
    private func columnColor(_ column: Int) -> Color {
        switch column {
        case 0: Theme.sunday
        case 6: Theme.saturday
        default: Paper.ink
        }
    }

    /// 지난 날은 스스로 물러난다 (철학 3). 앞뒤 달에서 넘어온 칸은 더 물러난다.
    private func dimness(_ day: MonthGrid.Day) -> Double {
        if day.isOverflow { return 0.3 }
        if day.date < model.today { return 0.45 }
        return 1
    }

    private func numeralColor(_ day: MonthGrid.Day, column: Int, isToday: Bool) -> Color {
        // 노란 원 위에서는 잉크보다 검정이 또렷하다. 다크 모드에서도 원은 노랗다.
        if isToday { return Color.black.opacity(0.82) }
        return columnColor(column).opacity(0.9 * dimness(day))
    }
}
