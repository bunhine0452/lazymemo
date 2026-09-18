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
///
/// **줄을 누르면 꺼낸다** (§16.12). 앞선 판은 누르면 펼치고, 펼친 안의
/// 「꺼내기」를 한 번 더 눌러야 했다 — 서랍을 여는 사람의 20% 손짓은
/// 「저 종이 도로 꺼내기」인데(WWDC17 802 의 80/20) 그것이 세 번이었다.
/// 펼쳐 보기는 손이 얹혔을 때의 꺾쇠(›)와 Space 로 남긴다 — 호버로 펼치면
/// 판이 출렁인다는 §16.3 의 규칙 그대로.
///
/// ## 손이 얹힌 것은 이 줄만 안다 (2026-09-18)
///
/// 호버는 서랍 **전체**의 `@State` 였다. 그래서 줄 하나에 손이 스칠 때마다
/// `DrawerView.body` 가 다시 돌고, 스물몇 줄이 통째로 다시 지어졌다 — 줄마다
/// 본문을 쪼개 둘째 줄을 만들고(`snippet`), 시각을 서식하고, 판형을 다시 셌다.
/// 게다가 판 전체에 `.animation(…, value: pointed)` 이 걸려 있어 **손이 스치면
/// 목록 전체가 애니메이션 갈래를 탔다.**
///
/// 지금은 줄이 제 손을 스스로 안다. 그리고 이 뷰는 `Equatable` 이라 — 값이
/// 그대로면 SwiftUI 가 `body` 를 건너뛴다 — 손이 옮겨 가면 **떠난 줄과 닿은 줄
/// 둘만** 다시 그려진다. 키보드가 짚은 자리(`isPointed`)는 그대로 밖에서 온다:
/// 짚은 것과 얹힌 것은 같은 표시이지만 정본은 다른 곳에 있다 (§16.10).
struct DrawerRow: View, Equatable {
    let memo: Memo
    /// 시각 한 조각. **부르는 쪽이 한 번만 짓는다** — 줄 안에서 세 번(줄·펼친
    /// 것·소리 이름표) 부르면 `Calendar.current` 를 세 번 뜬다.
    let time: String
    /// **키보드가 짚었다.** 손이 얹힌 것은 이 뷰가 스스로 안다.
    var isPointed = false
    var isPicked = false
    var isExpanded = false
    /// 「전체」를 보는 중이면 어느 폴더인지도 적는다.
    var showsFolder = true
    let folders: [String]

    var onTakeOut: () -> Void = {}
    /// 펼쳐 본다 / 도로 접는다.
    var onZoom: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMove: (String?) -> Void = { _ in }

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rendersStatically) private var rendersStatically
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 닫힘(함수)은 견줄 수 없다 — 부르는 쪽이 매번 새로 만들지만 하는 일은 같다.
    /// 값만 견준다 (달력의 `MonthPanel` 과 같은 규칙).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.memo == rhs.memo && lhs.time == rhs.time && lhs.isPointed == rhs.isPointed
            && lhs.isPicked == rhs.isPicked && lhs.isExpanded == rhs.isExpanded
            && lhs.showsFolder == rhs.showsFolder && lhs.folders == rhs.folders
    }

    /// 손이 얹혔거나 키보드가 짚었다 — 같은 표시다 (§14.10).
    private var isLit: Bool { isPointed || isHovered }

    /// 제목을 뺀 나머지와 둘째 줄. **한 번에 짓는다** — 앞선 판은 `snippet` 이
    /// `rest` 를 부르는 계산 속성이라, 한 번 그릴 때마다 본문을 두 번 쪼갰다.
    private struct Lines {
        var rest: String
        var snippet: String
    }

    private var lines: Lines {
        let all = memo.body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = all.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return Lines(rest: "", snippet: "") }
        let rest = all[(first + 1)...]
            .map(DrawerText.plain)
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
        let snippet = rest.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " · ")
        return Lines(rest: rest, snippet: snippet)
    }

    var body: some View {
        let text = lines
        return VStack(alignment: .leading, spacing: 0) {
            line(text.snippet)
            if isExpanded { detail(text.rest) }
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
        // 손이 얹히고 떠나는 것은 **이 줄 안에서** 애니메이션한다. 판 전체에
        // 걸면 스물몇 줄이 같은 갈래를 함께 탄다.
        .animation(Motion.quick(reduceMotion), value: isLit)
        .animation(Motion.quick(reduceMotion), value: isPicked)
        // `.onHover` 는 키 윈도에서만 산다 (§7.1) — 서랍은 펼치면 앞에 서므로
        // (`window.rise()`) 여기서는 그것으로 족하다. 닫힌 탭은 `HoverSensor` 가 본다.
        .onHover { isHovered = $0 }
    }

    /// 줄의 바탕. 쉬고 있으면 없고, 손이 오면 종이 색이 옅게 스민다 —
    /// 펼친 줄은 그 색으로 남는다. 고른 줄은 강조색이 옅게 깔린다.
    private var fill: Color {
        if isPicked { return Theme.accentInk.opacity(0.10) }
        if isExpanded || isLit {
            return Color(nsColor: PaperTint.surface(
                ink: memo.color.ink, dark: colorScheme == .dark, presence: 1
            ))
        }
        return .clear
    }

    private func line(_ snippet: String) -> some View {
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

            if isLit && !isExpanded {
                controls(compact: true)
            } else if !isExpanded {
                Text(time)
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
    private func detail(_ rest: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            if rest.isEmpty {
                Text(L("첫 줄이 전부입니다"))
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
                Text(time)
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

    /// 꺼내기 · 펼치기 · 폴더 · 지우기 — 종이가 하는 것과 같은 낱말이다 (`NoteView.paperControls`).
    ///
    /// 줄 위(`compact`)의 「꺼내기」는 줄 전체가 이미 하는 일을 **글자로 한 번
    /// 더 적은 것**이다 — 눌리는 것이면 눌리게 생겨야 한다(WWDC17 802 Affordances).
    /// 손이 얹혔을 때 그 말이 보이지 않으면, 줄을 누르면 무엇이 되는지는 눌러
    /// 봐야만 안다.
    private func controls(compact: Bool) -> some View {
        HStack(spacing: compact ? Theme.hairline : Theme.tight) {
            Button(action: onTakeOut) {
                HStack(spacing: 3) {
                    if compact {
                        Image(systemName: "arrow.up.forward").font(.system(size: 9, weight: .bold))
                    }
                    Text(L("꺼내기"))
                        .font(.system(size: 10.5, weight: compact ? .semibold : .medium))
                }
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
            .spoken(L("꺼내기 — 이 종이를 바탕화면으로 되돌립니다 (↩)"))

            Button(action: onZoom) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: Theme.touch, height: Theme.touchRow)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accentInk)
            .spoken(isExpanded
                    ? L("접기 — 본문을 도로 접습니다 (Space)")
                    : L("펼쳐 보기 — 본문을 이 자리에서 읽습니다. 고치려면 꺼냅니다 (Space)"))

            folderMenu

            RowTrash(isLit: true, help: L("지우기 — 메뉴의 되돌리기로 살릴 수 있습니다"), action: onDelete)
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
                Button(L("폴더에서 빼기")) { onMove(nil) }
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
                Text(L("폴더가 없습니다 — 위의 + 로 만듭니다"))
            }
        } label: {
            folderGlyph
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(Theme.accentInk)
        .spoken(L("폴더 — 이 종이를 다른 폴더로 옮깁니다"))
    }
}
