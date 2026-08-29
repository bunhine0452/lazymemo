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
///
/// **빈 상자에도 목록이 있다.** 열면 요즘 메모가 아래에 놓여 있고, ↓ 한 번
/// 이면 그리로 내려가 ⌘⏎ 로 연다. 적으러 열었든 찾으러 열었든 같은 단축키
/// 하나로 닿는다 — 메모를 다시 보려고 메뉴바 아이콘을 눌러 목록을 뒤지던
/// 길이 이 앱에서 가장 자주 하면서 가장 멀었다.
struct QuickCaptureView: View {
    @Bindable var model: QuickCaptureModel
    var onCommit: () -> Void
    var onCancel: () -> Void
    /// 그 메모가 지금 바탕화면에 나와 있는가. 찬 점과 빈 점을 가른다
    /// (메뉴 목록과 같은 낱말 — §14.10).
    var isOnDesktop: (ULID) -> Bool = { _ in false }
    /// 화면 밖 렌더에서 휴지통 위에 포인터를 얹어 둘 줄 (§14.9). 포인터가
    /// 없는 렌더에서는 붉은 원이 한 군데도 나타나지 않는다.
    var stagedTrashRow: Int?

    /// 글 높이에 맞춰 자란다. 한 줄에서 시작해 다섯 줄까지.
    @State private var editorHeight: CGFloat = QuickCaptureView.minimumEditorHeight

    static let minimumEditorHeight: CGFloat = 30
    private static let maximumEditorHeight: CGFloat = 150
    private static let arrowSize = CGSize(width: 20, height: 9)

    private var selectedMemo: Memo? {
        model.selection.flatMap { model.listed.indices.contains($0) ? model.listed[$0] : nil }
    }

    // 글머리에 있던 **보라색 점은 걷어냈다.**
    //
    // ⌘⏎ 를 누르면 벌어질 일을 색으로 말하던 것이다 — 보라면 새 메모,
    // 노랑이면 달력행, 메모 색이면 그 메모를 연다. 그런데 그 셋은 이미
    // 글 아래 칩("달력으로")과 목록의 골라진 줄이 **글자로** 말하고 있다.
    // 같은 말을 아무도 배운 적 없는 색으로 한 번 더 하는 셈이라, 남는 것은
    // "이 점은 뭐지" 라는 물음뿐이었다. 뜻이 겹치면 조용한 쪽을 버린다.

    var body: some View {
        VStack(spacing: 0) {
            if model.arrowOffset != nil { arrow }
            bubble
        }
        .frame(width: QuickCaptureController.width)
        .animation(Theme.reveal, value: model.listed.count)
        .animation(Theme.reveal, value: model.selection)
        .animation(Theme.reveal, value: model.scheduleLabel)
        .animation(Theme.reveal, value: model.lastDeleted?.id)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            input

            if !model.listed.isEmpty {
                Divider().opacity(0.3)
                results
            }

            if let deleted = model.lastDeleted {
                Divider().opacity(0.3)
                undoLine(deleted)
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
            MemoTextArea(
                text: $model.query,
                font: .systemFont(ofSize: 19, weight: .light),
                insets: NSSize(width: 0, height: 4),
                // 붙인 사진은 아래 조각으로 보인다. 경로 글자까지 19pt 로
                // 늘어놓으면 말풍선이 그것만으로 가득 찬다.
                hidesImageReferences: true,
                onPasteImage: { model.markdown(forPastedImage: $0, fileExtension: $1) },
                onPasteLink: { LinkLabel.markdown(for: $0) },
                // 열 때마다 바뀐다 (`CapturePrompt`).
                placeholder: model.placeholder,
                onCommand: handle(command:in:),
                onCommandReturn: onCommit,
                // 글이 자라면 **그 자리에서** 상자도 자라야 한다.
                // 여기서는 글 상자 높이만 바꾼다 — 창은 그 결과로 달라진
                // 배치를 스스로 받아 간다 (`CaptureHostingView`).
                onHeightChange: { height in
                    guard height != editorHeight else { return }
                    editorHeight = height
                }
            )
            .frame(height: min(max(editorHeight, Self.minimumEditorHeight), Self.maximumEditorHeight))

            if !model.images.isEmpty {
                PhotoChipRow(images: model.images) { model.originalURL(for: $0) }
            }

            if let schedule = model.scheduleLabel {
                scheduleChip(schedule)
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.normal)
    }

    /// 앱이 대신 읽어 준 것, 그리고 **그것이 어디로 가는지.**
    ///
    /// 이것이 "정리를 대신 해준다" 의 첫 얼굴이다. 그런데 날짜가 붙은 글은
    /// 종이로 남지 않고 달력이 맡으므로(§7.2), 어디로 가는지가 **누르기
    /// 전에** 보여야 한다. 나중에 알려 주면 그건 통보고, 통보는 되돌릴 수
    /// 없다 — 여기서는 한 글자 지우면 도로 종이가 된다.
    ///
    /// 달력 그림을 낱말로 바꿨다. 아이콘은 "날짜다" 까지만 말하고 "달력으로
    /// 간다" 를 말하지 못한다. 달 이동을 `‹ ›` 대신 이웃 달의 이름으로 적은
    /// 것과 같은 이유다 (§10.5 — 누르는 자리가 곧 도착지의 이름).
    private func scheduleChip(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
            Text("달력으로")
                .font(.system(size: 10, weight: .regular))
                .opacity(0.62)
        }
        .foregroundStyle(Theme.highlightInk)
        .padding(.horizontal, Theme.snug)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.highlightWash))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .fixedSize()
    }

    // MARK: 검색 결과

    /// 놓인 메모들. 누르면 열리고, 포인터가 얹히면 화살표로 고른 것과
    /// 같은 자리가 밝아진다 — 손과 키보드가 같은 것을 가리켜야 한다.
    private var results: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.listed.enumerated()), id: \.element.id) { index, memo in
                row(memo, index: index, isSelected: model.selection == index)
                    .onHover { inside in
                        if inside { model.selection = index }
                    }
            }
        }
        .padding(.vertical, Theme.tight)
    }

    /// 한 줄에 셋 — 종이 색 점, 제목, 시간 한 조각.
    ///
    /// 메뉴 목록과 **같은 낱말을 쓴다** (§14.10). 두 곳에서 같은 메모를 다르게
    /// 그리면 사람은 그것을 두 개의 목록으로 배운다. 찬 점은 바탕화면에 나와
    /// 있는 종이, 빈 점은 치워 둔 것 — 누르기 전에 "새로 뜬다" 인지 "앞으로
    /// 나온다" 인지 알 수 있다.
    private func row(_ memo: Memo, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: Theme.snug) {
            // 여는 자리와 지우는 자리를 **한 뷰에 겹치지 않는다.** 겹치면
            // 누르기 하나를 놓고 둘이 다투고, 어느 쪽이 이기는지가 상황마다
            // 달라진다 (달력에서 「미루기」를 끌기 밖에 둔 것과 같은 이유).
            HStack(spacing: Theme.snug) {
                paperDot(memo)

                Text(memo.title)
                    .font(Theme.body)
                    .lineLimit(1)

                Spacer(minLength: Theme.snug)

                Text(MemoTimeLabel.text(for: memo))
                    .font(Theme.micro)
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
            .onTapGesture {
                model.selection = index
                onCommit()
            }

            CaptureRowTrash(isLit: isSelected, staged: stagedTrashRow == index) {
                Task { await model.delete(memo) }
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(memo.color.tint.opacity(0.20))
                    .padding(.horizontal, Theme.snug)
            }
        }
    }

    private func paperDot(_ memo: Memo) -> some View {
        Group {
            if isOnDesktop(memo.id) {
                Circle().fill(memo.color.tint)
            } else {
                Circle().strokeBorder(memo.color.tint.opacity(0.8), lineWidth: 1.5)
            }
        }
        .frame(width: 8, height: 8)
    }

    // MARK: 되돌리기 한 줄

    /// 방금 지운 것을 되살리는 줄. **지운 자리에 그대로 남는다** (D6).
    ///
    /// 잘못 눌렀다는 것을 아는 순간은 지운 직후다. 그때 되돌리는 길이 메뉴
    /// 안에만 있으면 상자를 닫고 아이콘을 눌러 찾아 들어가야 한다 — 지우기는
    /// 한 번인데 되돌리기가 셋이면 그 휴지통은 못 누르는 버튼이 된다.
    private func undoLine(_ memo: Memo) -> some View {
        HStack(spacing: Theme.tight) {
            Text("「\(memo.title)」 지웠습니다")
                .lineLimit(1)
            Spacer(minLength: Theme.snug)
            Button("되돌리기") {
                Task { await model.restoreLastDeleted() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
        .transition(.opacity)
    }

    // MARK: 힌트

    /// 아래 한 줄이 **지금 ⌘⏎ 가 할 일과 ↑↓ 가 훑는 것**을 말한다.
    /// 목록이 요즘 것인지 찾은 것인지도 여기서만 말한다 — 목록 위에 이름표를
    /// 하나 더 얹으면 상자가 그만큼 커지고, 커진 상자는 적을 자리를 밀어낸다.
    private var hint: some View {
        HStack(spacing: Theme.normal) {
            // ⌘⏎ 로 할 일이 없으면 적지 않는다. 빈 상자에 "적기 끝" 이 떠
            // 있으면 그것은 지금 눌러도 아무 일도 안 나는 거짓말이다.
            if let commandLabel {
                Label(commandLabel, systemImage: "command")
            }
            if !model.listed.isEmpty {
                Label(model.listing == .recent ? "요즘 메모" : "찾은 것", systemImage: "arrow.up.arrow.down")
            }
            Spacer(minLength: 0)
            // 고른 줄이 있을 때만 지우는 법을 적는다. **⌘ 를 빼면 안 된다** —
            // ⌫ 하나는 글자를 지우는 키이고, 그렇게 적어 두면 사람은 글을
            // 지우면서 메모가 안 지워진다고 여긴다.
            if selectedMemo != nil {
                Label("⌘⌫ 지우기", systemImage: "trash")
            } else {
                Text("esc 로 닫아도 적던 것은 남습니다").font(Theme.micro)
            }
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.snug)
        .padding(.top, model.listed.isEmpty ? 0 : Theme.tight)
    }

    /// 지금 ⌘⏎ 가 할 일. 없으면 `nil`.
    private var commandLabel: String? {
        if selectedMemo != nil { return "열기" }
        return model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "적기 끝"
    }

    /// 텍스트 뷰가 넘겨준 키 명령. `true` 를 돌려주면 텍스트 뷰는 처리하지 않는다.
    ///
    /// 비공개가 아닌 이유는 **키가 어디로 가는지가 화면에 안 보이기 때문**이다.
    /// ⌘⌫ 가 메모 대신 글자를 지워도 그림으로는 알 수 없어 시험이 직접 부른다.
    ///
    /// **Return 은 넘기지 않는다** — 다음 줄로 가야 한다. ↑↓ 는 글줄 이동과
    /// 찾은 목록 이동을 겸하므로, 커서가 끝 줄에 닿았을 때만 목록으로 넘어간다.
    func handle(command: Selector, in textView: NSTextView) -> Bool {
        switch command {
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel()
            return true

        case #selector(NSResponder.moveDown(_:)):
            if model.selection != nil {
                model.moveSelection(1)
                return true
            }
            guard !model.listed.isEmpty, isCursorAtEnd(textView) else { return false }
            model.moveSelection(1)
            return true

        case #selector(NSResponder.moveUp(_:)):
            guard model.selection != nil else { return false }
            model.moveSelection(-1)
            return true

        // ⌘⌫ — 고른 줄을 지운다. Finder 와 같은 손짓이라 여기서만 쓰는 규칙을
        // 새로 배울 것이 없다. 고른 줄이 없으면 넘긴다 — 그때 이 키는 글자를
        // 지우는 원래 일을 해야 한다.
        case #selector(NSResponder.deleteToBeginningOfLine(_:)):
            return model.deleteSelected() != nil

        default:
            return false
        }
    }

    private func isCursorAtEnd(_ textView: NSTextView) -> Bool {
        let selection = textView.selectedRange()
        return selection.location + selection.length >= (textView.string as NSString).length
    }
}

/// 목록 줄의 휴지통.
///
/// **아주 숨기지는 않는다** — 메뉴 목록과 같은 규칙이다 (`MemoRow`). 포인터가
/// 온 줄에서만 나타나게 하면 화면은 깨끗해지지만, 있는 줄을 모르는 조작은
/// 없는 것과 같다. 골라진 줄에서 또렷해지고(포인터가 얹혀도 그 줄이 골라진다),
/// 휴지통 위에 오면 붉은 원이 깔린다 — 누르기 **전에** 다른 종류의 버튼임을
/// 말한다.
private struct CaptureRowTrash: View {
    /// 이 줄이 골라져 있는가. 손과 키보드가 같은 밝기를 본다.
    let isLit: Bool
    /// 화면 밖 렌더에서 포인터를 흉내 낸다 (§14.9).
    var staged = false
    let action: () -> Void

    @State private var isOver = false

    /// 평상시 세기. 있는 줄을 알 만큼만 (메뉴 목록의 24% 와 같은 뜻).
    private static let resting: Double = 0.28

    private var over: Bool { staged || isOver }

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(over ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.danger))
                .opacity(over ? 1 : (isLit ? 0.85 : Self.resting))
                .frame(width: 20, height: 20)
                .background {
                    if over { Circle().fill(Theme.danger) }
                }
        }
        .buttonStyle(.plain)
        .help("지우기 — 바로 아래 줄에서 되돌릴 수 있습니다")
        .onHover { isOver = $0 }
        .animation(Theme.reveal, value: over)
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
