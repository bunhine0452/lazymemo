import AppKit
import LazyMemoCore
import SwiftUI

/// 단축키 한 번으로 열리는 입력 (설계문서 §8).
///
/// 여기도 종이다. 처음엔 "잠깐 떴다 사라지는 것이니 유리" 라고 생각했다가
/// 되돌렸다 — 유리 위에서는 **지금 치고 있는 글자가 씻겨 나간다.** 떠 있다는
/// 느낌은 투명도가 아니라 큰 글자와 그림자, 그리고 화면 위쪽이라는 자리가 만든다.
///
/// 한 상자가 입력·검색·일정 인식을 겸한다. 날짜 표현이 보이면 오른쪽에 칩이
/// 떠오르는데, 인식한 원문이 아니라 **해석한 결과**를 보인다 — "내일" 이라고
/// 되쓰면 제대로 읽었는지 확인할 수 없다 (철학 2).
struct QuickCaptureView: View {
    @Bindable var model: QuickCaptureModel
    var onCommit: () -> Void
    var onCancel: () -> Void

    private var selectedMemo: Memo? {
        model.selection.flatMap { model.matches.indices.contains($0) ? model.matches[$0] : nil }
    }

    /// Return 을 누르면 벌어질 일의 색.
    private var intentColor: Color {
        if let selectedMemo { return selectedMemo.color.tint }
        return model.schedule == nil ? Theme.accent : Theme.highlight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            input

            if !model.matches.isEmpty {
                Divider().opacity(0.3)
                results
            }

            hint
        }
        .frame(width: QuickCaptureController.width)
        .background(Theme.paper(MemoColor.gray.ink, radius: Theme.panelRadius, dotted: false))
        .overlay(Theme.edge(radius: Theme.panelRadius))
        .animation(Theme.reveal, value: model.matches.count)
        .animation(Theme.reveal, value: model.selection)
        .animation(Theme.reveal, value: model.scheduleLabel)
    }

    // MARK: 입력

    private var input: some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            HStack(alignment: .center, spacing: Theme.normal) {
                Circle()
                    .fill(intentColor)
                    .frame(width: 9, height: 9)

                // 칩을 같은 줄에 두면 긴 글과 가로 공간을 다투다 글자가 눌린다.
                // 아래 줄로 내리면 경쟁이 없고, "이렇게 읽었습니다" 라는
                // 주석처럼 읽혀 뜻도 더 분명해진다.
                MemoTextArea(
                    text: $model.query,
                    font: .systemFont(ofSize: 19),
                    insets: NSSize(width: 0, height: 0),
                    onPasteLink: { LinkLabel.markdown(for: $0) },
                    placeholder: "무엇이든",
                    onCommand: handle(command:)
                )
                .frame(height: 28)
                .layoutPriority(1)
            }

            if let schedule = model.scheduleLabel {
                scheduleChip(schedule)
                    .padding(.leading, 9 + Theme.normal)
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.loose)
    }

    /// 앱이 대신 읽어 준 것. 이것이 "정리를 대신 해준다" 의 첫 얼굴이다.
    private func scheduleChip(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Theme.highlight)
        .padding(.horizontal, Theme.snug)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.highlight.opacity(0.16)))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .fixedSize()
    }

    // MARK: 검색 결과

    private var results: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.matches.enumerated()), id: \.element.id) { index, memo in
                row(memo, isSelected: model.selection == index)
                    .contentShape(.rect)
                    .onTapGesture {
                        model.selection = index
                        onCommit()
                    }
            }
        }
        .padding(.vertical, Theme.tight)
    }

    private func row(_ memo: Memo, isSelected: Bool) -> some View {
        HStack(spacing: Theme.snug) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(memo.color.tint)
                .frame(width: 3, height: 14)

            Text(memo.title)
                .font(Theme.label)
                .lineLimit(1)

            Spacer(minLength: Theme.snug)

            if let scheduled = memo.scheduledDate(), let start = scheduled.startOfDay() {
                Text(start.formatted(.dateTime.month().day()))
                    .font(Theme.microMono)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight + 1)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(memo.color.tint.opacity(0.20))
                    .padding(.horizontal, Theme.snug)
            }
        }
    }

    // MARK: 힌트

    private var hint: some View {
        HStack(spacing: Theme.normal) {
            Label(selectedMemo == nil ? "새 메모" : "열기", systemImage: "return")
            if !model.matches.isEmpty {
                Label("이동", systemImage: "arrow.up.arrow.down")
            }
            Spacer(minLength: 0)
            Text("esc").font(Theme.microMono)
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
        .padding(.top, model.matches.isEmpty ? 0 : Theme.tight)
    }

    /// 텍스트 뷰가 넘겨준 키 명령. `true` 를 돌려주면 텍스트 뷰는 처리하지 않는다.
    private func handle(command: Selector) -> Bool {
        switch command {
        case #selector(NSResponder.insertNewline(_:)):
            onCommit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel()
            return true
        case #selector(NSResponder.moveDown(_:)):
            model.moveSelection(1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            model.moveSelection(-1)
            return true
        default:
            return false
        }
    }
}
