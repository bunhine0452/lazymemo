import LazyMemoCore
import SwiftUI

/// 서랍 목록의 한 줄 — 그리고 펼쳤을 때의 본문.
///
/// **줄과 펼친 것이 같은 뷰다.** 둘을 다른 뷰로 만들면 펼치는 동작이 «줄이
/// 사라지고 종이가 나타나는» 것으로 보인다. 같은 줄이 아래로 자라야 **그
/// 줄이 열린 것**으로 읽힌다.
///
/// 한 줄에 적는 것은 넷이다 — 색, 제목, 둘째 줄, 시각. 앞선 판의 작아진
/// 종이는 제목 한 줄만 들고 있었고 나머지는 손이 얹혀야 드러났다 (§16.3).
/// 목록에서는 둘째 줄이 늘 보인다: 「장보기 목록」 밑의 「☑ 우유 · ☑ 계란」이
/// 곧 그 메모가 무엇인지 말하고, 그것이 사람이 훑을 때 실제로 읽는 줄이다.
struct DrawerRow: View {
    let memo: Memo
    /// 손이 얹혔거나 키보드가 짚었다 — 같은 표시다 (§14.10).
    var isPointed = false
    var isPicked = false
    var isExpanded = false
    /// 「전체」를 보는 중이면 어느 폴더인지도 적는다.
    var showsFolder = true
    let folders: [String]

    var onTakeOut: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMove: (String?) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rendersStatically) private var rendersStatically

    /// 제목을 뺀 나머지. 줄에서는 한 줄만, 펼치면 전부.
    private var rest: String {
        let lines = memo.body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return "" }
        return lines[(first + 1)...]
            .map(DrawerText.plain)
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }

    /// 둘째 줄 — 본문의 다음 줄들을 한 줄로 이은 것.
    private var snippet: String {
        rest.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line
            if isExpanded { detail }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.chipRadius + 2, style: .continuous)
                .fill(fill)
        }
        .overlay {
            if isPicked {
                RoundedRectangle(cornerRadius: Theme.chipRadius + 2, style: .continuous)
                    .strokeBorder(Theme.accentInk.opacity(0.85), lineWidth: 1.5)
            }
        }
        .contentShape(.rect)
    }

    /// 줄의 바탕. 쉬고 있으면 없고, 손이 오면 종이 색이 옅게 스민다 —
    /// 펼친 줄은 그 색으로 남는다. 고른 줄은 강조색이 옅게 깔린다.
    private var fill: Color {
        if isPicked { return Theme.accentInk.opacity(0.10) }
        if isExpanded || isPointed {
            return Color(nsColor: PaperTint.surface(
                ink: memo.color.ink, dark: colorScheme == .dark, presence: 1
            ))
        }
        return .clear
    }

    private var line: some View {
        HStack(spacing: Theme.snug) {
            RoundedRectangle(cornerRadius: 2).fill(memo.color.tint)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(memo.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.ink.opacity(0.92))
                    .lineLimit(1)
                // 펼친 줄은 둘째 줄을 접는다 — 바로 아래 본문이 전부 나오는데
                // 같은 글을 위에 한 번 더 적으면 두 번 읽힌다. 둘째 줄이 없는
                // 메모는 자리를 비운다 — 시각은 오른쪽 끝에 이미 있어, 여기 한 번
                // 더 적으면 「오늘 … 오늘」이 한 줄에 두 번 선다.
                let showsSnippet = !isExpanded && !snippet.isEmpty
                if showsSnippet || (showsFolder && memo.folder != nil) {
                    HStack(spacing: Theme.tight) {
                        if showsFolder, let folder = memo.folder {
                            folderTag(folder)
                        }
                        if showsSnippet {
                            Text(snippet)
                                .font(.system(size: 11))
                                .foregroundStyle(Paper.ink.opacity(0.52))
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: Theme.tight)

            if isPointed && !isExpanded {
                controls(compact: true)
            } else if !isExpanded {
                Text(MemoTimeLabel.text(for: memo))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.40))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.snug)
        .frame(height: DrawerGeometry.rowHeight - 2)
    }

    /// 폴더 이름표 — 작은 글자 하나. 칩으로 만들면 줄마다 단추가 하나씩 선다.
    private func folderTag(_ name: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "folder").font(.system(size: 8, weight: .medium))
            Text(name).font(Theme.micro).lineLimit(1)
        }
        .foregroundStyle(Theme.accentInk.opacity(0.85))
        .fixedSize()
    }

    /// 펼친 줄 — 본문 전부와 조작. **읽기만 한다** (§16.6). 고치려면 「꺼내기」.
    private var detail: some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            if rest.isEmpty {
                Text("첫 줄이 전부입니다")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.ink.opacity(0.38))
            } else {
                Text(rest)
                    .font(.system(size: 12))
                    .lineSpacing(Theme.bodyLineSpacing - 1)
                    .foregroundStyle(Paper.ink.opacity(0.80))
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Theme.tight) {
                Text(MemoTimeLabel.text(for: memo))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.42))
                if !memo.tags.isEmpty {
                    Text(memo.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(Theme.micro)
                        .foregroundStyle(Paper.ink.opacity(0.36))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                controls(compact: false)
            }
        }
        .padding(.horizontal, Theme.snug + 3 + Theme.snug)
        .padding(.bottom, Theme.snug)
        .frame(height: DrawerGeometry.expandedExtra(lines: DrawerText.bodyLines(of: memo.body)), alignment: .top)
        .transition(.opacity)
    }

    /// 꺼내기 · 폴더 · 지우기 — 종이가 하는 것과 같은 낱말이다 (`NoteView.paperControls`).
    private func controls(compact: Bool) -> some View {
        HStack(spacing: compact ? Theme.hairline : Theme.tight) {
            Button(action: onTakeOut) {
                Text("꺼내기")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, compact ? Theme.tight : Theme.snug)
                    .frame(height: Theme.touchRow)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(compact ? Theme.accentInk : Theme.onAccent)
            .background {
                if !compact {
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                        .fill(Theme.accent)
                }
            }
            .spoken("꺼내기 — 이 종이를 바탕화면으로 되돌립니다")

            folderMenu

            RowTrash(isLit: true, help: "지우기 — 메뉴의 되돌리기로 살릴 수 있습니다", action: onDelete)
        }
    }

    /// 다른 폴더로 옮기는 메뉴. 폴더가 하나도 없으면 「새 폴더는 위의 + 로」만 적는다.
    @ViewBuilder
    private var folderMenu: some View {
        if rendersStatically {
            // 화면 밖 렌더는 `Menu` 를 그리지 못한다 (§14.9) — 그림만 남긴다.
            folderGlyph
        } else {
            folderMenuBody
        }
    }

    private var folderGlyph: some View {
        Image(systemName: "folder")
            .font(.system(size: 11, weight: .semibold))
            .frame(width: Theme.touch, height: Theme.touchRow)
            .foregroundStyle(Theme.accentInk)
            .contentShape(.rect)
    }

    private var folderMenuBody: some View {
        Menu {
            if memo.folder != nil {
                Button("폴더에서 빼기") { onMove(nil) }
                Divider()
            }
            ForEach(folders, id: \.self) { name in
                Button {
                    onMove(name)
                } label: {
                    if name == memo.folder {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
            if folders.isEmpty {
                Text("폴더가 없습니다 — 위의 + 로 만듭니다")
            }
        } label: {
            folderGlyph
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(Theme.accentInk)
        .spoken("폴더 — 이 종이를 다른 폴더로 옮깁니다")
    }
}
