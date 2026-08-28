import AppKit
import LazyMemoCore
import SwiftUI

/// 단축키 한 번으로 열리는 입력 상자.
struct QuickCaptureView: View {
    @Bindable var model: QuickCaptureModel
    var onCommit: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            input

            if !model.matches.isEmpty {
                Divider().opacity(0.5)
                results
            }

            Divider().opacity(0.5)
            hint
        }
        .frame(width: 380)
    }

    private var input: some View {
        ZStack(alignment: .topLeading) {
            MemoTextEditor(
                text: $model.query,
                font: .systemFont(ofSize: 15),
                insets: NSSize(width: 14, height: 12),
                onCommand: handle(command:)
            )
            .frame(height: 76)

            if model.query.isEmpty {
                Text("무엇이든 적으세요")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 19)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
        }
    }

    private var results: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.matches.enumerated()), id: \.element.id) { index, memo in
                HStack(spacing: 8) {
                    Circle()
                        .fill(memo.color.tint)
                        .frame(width: 7, height: 7)
                    Text(memo.title)
                        .lineLimit(1)
                        .font(.system(size: 12))
                    Spacer(minLength: 8)
                    if let schedule = memo.scheduledDate() {
                        Text(schedule.description)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    if model.selection == index {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.tint.opacity(0.18))
                            .padding(.horizontal, 6)
                    }
                }
                .contentShape(.rect)
                .onTapGesture {
                    model.selection = index
                    onCommit()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var hint: some View {
        HStack(spacing: 10) {
            Label(model.selection == nil ? "새 메모" : "열기", systemImage: "return")
            Label("이동", systemImage: "arrow.up.arrow.down")
            Spacer()
            Text("esc 닫기")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
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
