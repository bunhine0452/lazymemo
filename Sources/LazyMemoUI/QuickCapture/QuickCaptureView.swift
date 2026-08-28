import AppKit
import LazyMemoCore
import SwiftUI

/// 단축키 한 번으로 열리는 입력 (설계문서 §8).
///
/// 여기도 종이다. 처음엔 "잠깐 떴다 사라지는 것이니 유리" 라고 생각했다가
/// 되돌렸다 — 유리 위에서는 **지금 치고 있는 글자가 씻겨 나간다.**
///
/// **메뉴바 아이콘에 매달린 말풍선**이다. 화면 한가운데 띄우던 것을 되돌렸는데,
/// 사람이 단축키를 누르든 아이콘을 누르든 "이 앱이 열렸다" 를 같은 자리에서
/// 보는 편이 배울 것이 적기 때문이다. 아이콘이 가려져 자리를 알 수 없을 때만
/// 화면 위쪽으로 물러난다.
///
/// **Return 은 다음 줄로 간다.** 메모는 한 줄로 끝나지 않는다. 적기를 끝내는
/// 것은 ⌘⏎ 이고, esc 로 닫아도 적던 글은 상자가 기억한다 — 다시 열면 그대로
/// 있고 전부 선택돼 있어 그냥 치면 덮어쓴다.
struct QuickCaptureView: View {
    @Bindable var model: QuickCaptureModel
    var onCommit: () -> Void
    var onCancel: () -> Void

    /// 글 높이에 맞춰 자란다. 한 줄에서 시작해 다섯 줄까지.
    @State private var editorHeight: CGFloat = QuickCaptureView.minimumEditorHeight

    static let minimumEditorHeight: CGFloat = 30
    private static let maximumEditorHeight: CGFloat = 150
    private static let arrowSize = CGSize(width: 20, height: 9)

    private var selectedMemo: Memo? {
        model.selection.flatMap { model.matches.indices.contains($0) ? model.matches[$0] : nil }
    }

    /// ⌘⏎ 를 누르면 벌어질 일의 색.
    private var intentColor: Color {
        if let selectedMemo { return selectedMemo.color.tint }
        return model.schedule == nil ? Theme.accent : Theme.highlight
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.arrowOffset != nil { arrow }
            bubble
        }
        .frame(width: QuickCaptureController.width)
        .animation(Theme.reveal, value: model.matches.count)
        .animation(Theme.reveal, value: model.selection)
        .animation(Theme.reveal, value: model.scheduleLabel)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            input

            if !model.matches.isEmpty {
                Divider().opacity(0.3)
                results
            }

            hint
        }
        .background(Theme.paper(MemoColor.gray.ink, radius: Theme.panelRadius, dotted: false))
        .overlay(Theme.edge(radius: Theme.panelRadius))
    }

    /// 말풍선의 꼬리. 메뉴바 아이콘을 가리킨다.
    private var arrow: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: max((model.arrowOffset ?? 0) - Self.arrowSize.width / 2, Theme.snug))
            Theme.paper(MemoColor.gray.ink, radius: 0, dotted: false)
                .frame(width: Self.arrowSize.width, height: Self.arrowSize.height + 1)
                .clipShape(BubbleTail())
            Spacer(minLength: 0)
        }
        .frame(height: Self.arrowSize.height)
        // 1pt 겹쳐 놓아야 말풍선 테두리와 만나는 자리에 이음매가 안 보인다.
        .zIndex(1)
    }

    // MARK: 입력

    private var input: some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            HStack(alignment: .top, spacing: Theme.normal) {
                Circle()
                    .fill(intentColor)
                    .frame(width: 9, height: 9)
                    // 첫 글줄의 눈높이에 맞춘다. 위에 붙이면 글이 여러 줄일 때 떠 보인다.
                    .padding(.top, 9)

                MemoTextArea(
                    text: $model.query,
                    font: .systemFont(ofSize: 19, weight: .light),
                    insets: NSSize(width: 0, height: 4),
                    onPasteImage: { model.markdown(forPastedImage: $0, fileExtension: $1) },
                    onPasteLink: { LinkLabel.markdown(for: $0) },
                    placeholder: "무엇이든",
                    onCommand: handle(command:in:),
                    onCommandReturn: onCommit,
                    // 글이 자라면 **그 자리에서** 상자도 자라야 한다.
                    // 검색 결과가 돌아올 때까지(120ms) 기다리면, 그동안 새 줄이
                    // 창 밖으로 밀려 "줄바꿈이 됐다가 되돌아온" 것처럼 보인다.
                    onHeightChange: { height in
                        guard height != editorHeight else { return }
                        editorHeight = height
                        model.requestLayout()
                    }
                )
                .frame(height: min(max(editorHeight, Self.minimumEditorHeight), Self.maximumEditorHeight))
                .layoutPriority(1)
            }

            if let schedule = model.scheduleLabel {
                scheduleChip(schedule)
                    .padding(.leading, 9 + Theme.normal)
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.normal)
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
            Label(selectedMemo == nil ? "적기 끝" : "열기", systemImage: "command")
            if !model.matches.isEmpty {
                Label("찾은 것", systemImage: "arrow.up.arrow.down")
            }
            Spacer(minLength: 0)
            Text("esc 로 닫아도 적던 것은 남습니다").font(Theme.micro)
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
        .padding(.top, model.matches.isEmpty ? 0 : Theme.tight)
    }

    /// 텍스트 뷰가 넘겨준 키 명령. `true` 를 돌려주면 텍스트 뷰는 처리하지 않는다.
    ///
    /// **Return 은 넘기지 않는다** — 다음 줄로 가야 한다. ↑↓ 는 글줄 이동과
    /// 찾은 목록 이동을 겸하므로, 커서가 끝 줄에 닿았을 때만 목록으로 넘어간다.
    private func handle(command: Selector, in textView: NSTextView) -> Bool {
        switch command {
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel()
            return true

        case #selector(NSResponder.moveDown(_:)):
            if model.selection != nil {
                model.moveSelection(1)
                return true
            }
            guard !model.matches.isEmpty, isCursorAtEnd(textView) else { return false }
            model.moveSelection(1)
            return true

        case #selector(NSResponder.moveUp(_:)):
            guard model.selection != nil else { return false }
            model.moveSelection(-1)
            return true

        default:
            return false
        }
    }

    private func isCursorAtEnd(_ textView: NSTextView) -> Bool {
        let selection = textView.selectedRange()
        return selection.location + selection.length >= (textView.string as NSString).length
    }
}

/// 말풍선 꼬리 모양. 위를 가리킨다.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
