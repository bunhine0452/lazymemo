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

    @State private var isHovering = false
    @State private var isPickingColor = false

    private var color: MemoColor { model.memo.color }
    private var hasFooter: Bool { model.memo.isScheduled || !model.memo.tags.isEmpty }

    /// 포인터가 올라오면 나이를 잊는다.
    private var age: MemoAge {
        (isHovering || isPickingColor) ? .fresh : MemoAge.of(model.memo)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                editor
                if hasFooter { footer }
            }
            .opacity(age.presence)

            if isHovering || isPickingColor {
                controls
            }
        }
        .background(Theme.paper(color.tint, age: age))
        .overlay(Theme.edge(color.tint, age: age))
        .onHover { isHovering = $0 }
        .animation(Theme.reveal, value: isHovering)
        .animation(Theme.settle, value: age)
    }

    // MARK: 본문

    private var editor: some View {
        MemoTextArea(
            text: $model.text,
            insets: NSSize(width: Theme.normal, height: Theme.normal),
            placeholder: "…",
            onEdit: model.edited
        )
    }

    // MARK: 겹쳐 뜨는 조작

    private var controls: some View {
        HStack(spacing: 1) {
            colorButton

            QuietButton(
                symbol: model.memo.pinned ? "pin.fill" : "pin",
                help: model.memo.pinned ? "고정 해제" : "고정",
                isActive: model.memo.pinned
            ) {
                Task { await model.togglePin() }
            }

            QuietButton(symbol: "xmark", help: "치우기 — 메모는 지워지지 않습니다", action: onClose)
        }
        .padding(3)
        .background {
            // 글자 위에 겹치므로 얇은 바탕이 필요하다. 없으면 아이콘이 본문에 묻힌다.
            Capsule().fill(.regularMaterial)
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

    // MARK: 꼬리 — 날짜와 태그가 있을 때만

    private var footer: some View {
        HStack(spacing: Theme.tight) {
            if let schedule = scheduleLabel {
                Label {
                    Text(schedule).font(Theme.micro)
                } icon: {
                    Image(systemName: model.memo.at != nil ? "clock" : "calendar")
                        .font(.system(size: 9))
                }
                .foregroundStyle(isPast ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            }

            if !model.memo.tags.isEmpty {
                Text(model.memo.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .font(Theme.micro)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.normal + 5)
        .padding(.bottom, Theme.snug)
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
