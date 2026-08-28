import LazyMemoCore
import SwiftUI

/// 바탕화면에 떠 있는 메모 한 장.
///
/// 조작 버튼은 평소에 숨어 있다가 포인터가 올라오면 나타난다 — 메모가 열 장
/// 떠 있어도 화면이 버튼밭이 되지 않아야 한다.
struct NoteView: View {
    @Bindable var model: NoteModel
    var onClose: () -> Void

    @State private var isHovering = false
    @State private var isPickingColor = false

    private var color: MemoColor { model.memo.color }

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
            if model.memo.isScheduled || !model.memo.tags.isEmpty {
                footer
            }
        }
        .background {
            // 유리 위에 색을 아주 옅게 얹는다. 원색 포스트잇을 그대로 쓰면
            // macOS 26 의 재질과 부딪혀 싸구려로 보인다.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.tint.opacity(0.22))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.tint.opacity(0.35), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 6) {
            colorButton

            // 여백 자체가 창을 끄는 손잡이다 (isMovableByWindowBackground).
            Spacer(minLength: 0)
                .contentShape(.rect)

            if model.memo.pinned || isHovering {
                iconButton(
                    model.memo.pinned ? "pin.fill" : "pin",
                    help: model.memo.pinned ? "고정 해제" : "고정"
                ) {
                    Task { await model.togglePin() }
                }
                .foregroundStyle(model.memo.pinned ? color.tint : .secondary)
            }

            if isHovering {
                iconButton("xmark", help: "닫기 (메모는 지워지지 않습니다)", action: onClose)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .frame(height: 28)
    }

    private var colorButton: some View {
        Button {
            isPickingColor.toggle()
        } label: {
            Circle()
                .fill(color.tint)
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("색 바꾸기")
        .popover(isPresented: $isPickingColor, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                ForEach(MemoColor.allCases, id: \.self) { candidate in
                    Button {
                        isPickingColor = false
                        Task { await model.setColor(candidate) }
                    } label: {
                        Circle()
                            .fill(candidate.tint)
                            .frame(width: 18, height: 18)
                            .overlay {
                                if candidate == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.6))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(candidate.label)
                }
            }
            .padding(12)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    // MARK: 본문

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            MemoTextEditor(text: $model.text, onEdit: model.edited)

            if model.text.isEmpty {
                Text("여기에 적으세요")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: 꼬리

    private var footer: some View {
        HStack(spacing: 6) {
            if let schedule = scheduleLabel {
                Label(schedule, systemImage: model.memo.at != nil ? "clock" : "calendar")
                    .font(.caption2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(color.tint.opacity(0.30)))
            }

            ForEach(model.memo.tags.prefix(3), id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
        .padding(.top, 2)
    }

    private var scheduleLabel: String? {
        if let at = model.memo.at {
            return at.formatted(.dateTime.month().day().hour().minute())
        }
        if let due = model.memo.due {
            return due.description
        }
        return nil
    }
}
