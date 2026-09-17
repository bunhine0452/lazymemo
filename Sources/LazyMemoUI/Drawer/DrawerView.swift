import AppKit
import LazyMemoCore
import SwiftUI

/// 「서랍」 — 바탕화면에 상주하는 폴더들.
///
/// ## 왜 있는가
///
/// 이 앱에는 종이를 **밀어 두는** 길이 이미 둘 있었다. 사람이 ×를 누르는 것과,
/// 낡은 것이 스스로 물러나는 것(`Tidy`). 그런데 밀어 둔 종이가 **어디로 갔는지
/// 보여주는 자리**가 없었다. 서랍은 그 N장에 **몸을 준다** (`DrawerContents`).
/// 그리고 그 안을 **폴더**로 나눈다 (`MemoFolders`) — 서른 장이 한 무더기에
/// 있을 이유가 없다.
///
/// ## 두 가지 크기
///
/// | 무엇 | 어떻게 |
/// |---|---|
/// | 닫힌 탭 | 바탕화면에 늘 앉아 있다. 「서랍」과 몇 장인지, 그 밑에 최근 두 장의 제목. 종이를 끌어다 놓는 자리다 |
/// | 누르면 · 메뉴바 「서랍」 | 창이 **탭이 있던 모서리를 붙박은 채** 자라 **앞으로** 나오고, 찾기·폴더·목록이 선다 |
/// | 줄을 누르면 · ↩ | **꺼낸다** — 종이가 제자리로 돌아가 잠깐 앞에 선다. 바닥 줄에 「도로 넣기」 (§16.12) |
/// | 줄의 › · Space | 그 줄이 아래로 자라 본문을 보인다. 한 번 더 누르면 접힌다 |
/// | ⌘ 누른 채 누르면 · ⇧↑↓ | 고른다. 바닥 줄에 「모두 꺼내기 · 옮기기 · 지우기」 |
/// | 줄을 폴더로 끌면 | 그 폴더로 옮긴다 |
/// | 종이를 판 어디에나 놓으면 | 들어온다 — 보고 있는 폴더로. 떠 있는 동안 판 전체가 「놓으면 들어옵니다」 |
///
/// **움직임을 줄이라고 한 사람에게는 움직이지 않는다** (`accessibilityReduceMotion`).
struct DrawerView: View {
    @Bindable var model: DrawerModel

    @State private var hovered: ULID?
    @State private var isHovering = false
    @State private var newFolderName = ""
    @State private var renameText = ""
    /// 글 상자의 커서. **진짜 글 상자여야 한다** — 한글은 조합 입력이라
    /// 날 키 이벤트를 모아 글자를 만들면 「장」을 치는데 「wkd」가 쌓인다
    /// (`DrawerKeys`).
    @FocusState private var searchFocused: Bool
    @FocusState private var namingFocused: Bool
    @FocusState private var renamingFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rendersStatically) private var rendersStatically
    @Environment(\.colorScheme) private var colorScheme

    private var plan: DrawerGeometry { model.geometry() }
    /// 지금 «짚힌» 한 줄. **손이 얹힌 것과 키보드가 짚은 것이 같은 자리다** —
    /// 두 곳에서 같은 일을 다르게 그리면 두 개의 물건이 된다 (§14.10).
    private var pointed: ULID? { model.staged?.hovered ?? hovered ?? model.shownTarget }
    private var landing: ULID? { model.shownLanding }
    private var isEditing: Bool { searchFocused || namingFocused || renamingFocused }

    // MARK: 움직임

    /// 펼치고 접는 속도. 창의 크기 변화와 **같은 시간**이어야 한다
    /// (`DrawerWindowController.duration`) — 둘이 다르면 내용이 먼저 나오고
    /// 창이 뒤따라 커지면서 한 프레임 잘려 보인다.
    private var opening: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.22, 0.9, 0.24, 1, duration: 0.30)
    }

    private var quick: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.14)
    }

    var body: some View {
        Group {
            if model.shownOpen {
                opened
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.paper(MemoColor.gray.ink, radius: Theme.panelRadius, dotted: false))
                    .overlay(Theme.edge(radius: Theme.panelRadius))
                    // 종이가 떠 있으면 **판 전체가 놓을 자리다** — 바닥 한 줄의
                    // 작은 글자로는 겨눌 자리가 어디까지인지 보이지 않았다.
                    .overlay { if landing != nil { landingVeil } }
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                    .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            } else {
                closed
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay { HoverSensor { isHovering = $0 } }
        .animation(opening, value: model.shownOpen)
        .animation(quick, value: model.shownExpanded)
        .animation(quick, value: pointed)
        .animation(quick, value: model.shownLanding)
        .animation(quick, value: model.shownLastTakenOut?.id)
        .animation(quick, value: model.shownPicked)
        .animation(quick, value: model.shownFolder)
        .animation(quick, value: model.shownNaming)
        // **한 겹씩 되돌린다** (`DrawerModel.escape`).
        .onExitCommand { model.escape() }
        // 커서를 옮겨 달라는 부탁 (`DrawerModel.focusRequest`) — ⌘F 로 들어오고,
        // esc 로 빠져나온다.
        .onChange(of: model.focusRequest.count) { searchFocused = model.focusRequest.wantsSearch }
        // 서랍을 접으면 커서도 놓는다. 안 놓으면 다음에 펼쳤을 때 커서만
        // 찾기 줄에 남아 있어서, ↑↓ 가 목록 대신 상자로 간다.
        .onChange(of: model.shownOpen) {
            if !model.shownOpen { searchFocused = false; namingFocused = false; renamingFocused = false }
        }
        .onChange(of: model.isNamingFolder) { if model.isNamingFolder { newFolderName = ""; namingFocused = true } }
        .onChange(of: model.renamingFolder) {
            if let name = model.renamingFolder { renameText = name; renamingFocused = true }
        }
        // 이름을 적다 다른 데를 누르면 적던 것을 버린다 — 반쯤 적은 이름으로
        // 폴더가 생기는 것보다 낫다.
        .onChange(of: namingFocused) { if !namingFocused, model.isNamingFolder { model.isNamingFolder = false } }
        .onChange(of: renamingFocused) { if !renamingFocused, model.renamingFolder != nil { model.renamingFolder = nil } }
        // **커서가 어디 있는지는 여기만 확실히 안다.** 창이 키를 나눌 때 이
        // 값을 본다 (`DrawerModel.isEditingSearch`).
        .onChange(of: isEditing) { model.isEditingSearch = isEditing }
    }

    // MARK: 닫힌 탭

    /// 닫힌 서랍 — **탭 하나.**
    ///
    /// 앞선 판은 종이 세 장을 비뚤게 깔아 «무더기» 를 그렸다. 바탕화면에서
    /// 그것은 흐트러진 카드로 보였고, 몇 장인지는 두께로만 말해서 열어 보기
    /// 전에는 알 수 없었다. 탭은 이름과 수를 그대로 적는다 — 서랍이 «앱처럼»
    /// 보일까 걱정했지만, 안 읽히는 물건이 더 나쁘다.
    private var closed: some View {
        Button { model.toggle() } label: {
            HStack(spacing: Theme.snug) {
                Image(systemName: landing != nil ? "tray.and.arrow.down.fill" : "tray.full.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.tight) {
                        Text(L("서랍"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Paper.ink.opacity(0.9))
                        countPill(model.total)
                        Spacer(minLength: 0)
                    }
                    // 둘째 줄 — 열어 보기 전에 무엇이 들었는지 한 줄은 읽힌다.
                    // 종이가 떠 있으면 그 줄이 「놓으면 들어옵니다」가 된다.
                    Text(tabSubtitle)
                        .font(.system(size: 11, weight: landing != nil ? .semibold : .regular))
                        .foregroundStyle(landing != nil ? Theme.accentInk : Paper.ink.opacity(0.48))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Theme.normal - 2)
            .frame(width: DrawerGeometry.closedSize.width, height: DrawerGeometry.closedSize.height)
            .background(Theme.paper(MemoColor.gray.ink, radius: Theme.cardRadius - 2, dotted: false))
            .overlay(Theme.edge(radius: Theme.cardRadius - 2))
            .overlay {
                if landing != nil {
                    RoundedRectangle(cornerRadius: Theme.cardRadius - 2, style: .continuous)
                        .strokeBorder(Theme.accentInk.opacity(0.8), lineWidth: 1.5)
                }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.06), radius: 1, y: 0.5)
            .shadow(color: .black.opacity(landing != nil ? 0.18 : 0.10), radius: landing != nil ? 10 : 6, y: 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // **탭은 잡으면 끌린다.** 단추가 판 전체를 덮으면 창을 옮길 데가 한 군데도 없다 —
        // 잡아서 끌면 옮기고, 안 끌고 놓으면 누른 것이다 (`WindowDragSurface`). 화면 밖
        // 렌더는 NSView 를 그리지 못하므로 뺀다 (§14.9).
        .overlay {
            if !rendersStatically {
                WindowDragSurface(onClick: { model.toggle() }, menu: { tabMenu })
            }
        }
        .scaleEffect(landing != nil ? 1.04 : (isHovering ? 1.02 : 1))
        .animation(quick, value: isHovering)
        .spoken(L("서랍 — \(model.title). 눌러서 펼칩니다"))
    }

    /// 탭의 오른쪽 클릭 — 펼치기, 그리고 **바탕화면에서 치우기.**
    ///
    /// 치우는 길이 메뉴바의 ⌥ 항목뿐이었더니 「서랍이 사라지지 않는다」가 됐다
    /// (2026-09-17, 사용자). 물건 위에서 그 물건을 치우는 길이 하나는 있어야 한다.
    private var tabMenu: NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: L("펼치기"), action: #selector(DrawerMenuTarget.open), keyEquivalent: "")
        let dismiss = NSMenuItem(title: L("바탕화면에서 치우기"), action: #selector(DrawerMenuTarget.dismiss), keyEquivalent: "")
        let target = DrawerMenuTarget(model: model)
        for item in [open, dismiss] {
            item.target = target
            item.representedObject = target   // 메뉴가 사는 동안 표적도 산다.
            menu.addItem(item)
        }
        return menu
    }

    /// 닫힌 탭의 둘째 줄.
    private var tabSubtitle: String {
        if landing != nil { return L("놓으면 들어옵니다") }
        let titles = model.recentTitles
        if titles.isEmpty { return L("비어 있습니다 — 종이를 여기 끌어다 놓습니다") }
        return titles.map(short).joined(separator: " · ")
    }

    /// 종이가 떠 있는 동안 펼친 판을 덮는 한 겹 — **판 전체가 과녁**이라는 말.
    private var landingVeil: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                .fill(Paper.surface.opacity(0.82))
            RoundedRectangle(cornerRadius: Theme.panelRadius - 5, style: .continuous)
                .strokeBorder(Theme.accentInk.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [9, 6]))
                .padding(6)
            VStack(spacing: Theme.tight) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 30, weight: .semibold))
                Text(landingTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.accentInk)
            .padding(Theme.loose)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var landingTitle: String {
        if let folder = model.shownFolder { return L("놓으면 「\(folder)」에 들어옵니다") }
        return L("놓으면 들어옵니다")
    }

    private func countPill(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Theme.softAccent, in: Capsule())
    }

    // MARK: 펼친 서랍

    private var opened: some View {
        VStack(spacing: 0) {
            heading
            searchField
                .frame(height: DrawerGeometry.searchHeight, alignment: .top)
            folderStrip
                .frame(height: DrawerGeometry.foldersHeight, alignment: .top)
            list
                .frame(height: plan.listHeight)
            footer
        }
        .padding(DrawerGeometry.padding)
    }

    private var heading: some View {
        HStack(spacing: Theme.tight + 2) {
            // 머리 줄이 펼친 판의 손잡이다 — 종이의 색띠와 같은 자리, 같은 길 (`PaperGrip`).
            HStack(spacing: Theme.tight + 2) {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(Theme.accentInk)
                Text(L("서랍")).font(.system(size: 17, weight: .bold))
                countPill(model.total)
                Spacer()
            }
            .contentShape(.rect)
            .background { if !rendersStatically { WindowDragSurface() } }
            QuietButton(symbol: "xmark", help: L("접기 — 서랍을 닫습니다")) {
                model.setOpen(false)
            }
        }
        .frame(height: DrawerGeometry.headerHeight, alignment: .top)
    }

    /// **찾기 — 진짜 글 상자다.** 위에 늘 있다.
    ///
    /// 앞선 판은 바닥 한 줄에 거의 안 보이게 두었다 — 도구 막대가 되는 것이
    /// 싫어서였는데, 그 결과 찾기가 있는 줄도 모르는 사람이 생겼다. 열두 장이
    /// 넘는 서랍에서 찾기는 장식이 아니라 문이다.
    private var searchField: some View {
        HStack(spacing: Theme.tight) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
            if rendersStatically {
                // 화면 밖 렌더는 `NSViewRepresentable` 을 그리지 못한다 (§14.9).
                Text(model.shownQuery.isEmpty ? L("찾기 — 첫소리로도 됩니다") : model.shownQuery)
                    .font(.system(size: 12))
                    .foregroundStyle(model.shownQuery.isEmpty ? Theme.secondaryInk.opacity(0.7) : Paper.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                TextField(L("찾기 — 첫소리로도 됩니다"), text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
            }
            if model.isSearching, let found = model.searchSummary {
                Text(found)
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.42))
                    .lineLimit(1)
            }
            if model.isSearching {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Paper.ink.opacity(0.35))
                        .hitTarget(Theme.touchRow)
                }
                .buttonStyle(.plain)
                .spoken(L("지우기 — 찾던 글자를 지웁니다"))
            }
        }
        .padding(.horizontal, Theme.snug)
        .frame(height: 30)
        .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .contentShape(.rect)
        .onTapGesture { searchFocused = true }
        .spoken(L("찾기 — 서랍에 든 종이를 글자로 거릅니다. 첫소리로도 찾습니다"))
    }

    // MARK: 폴더 띠

    /// 「전체」, 폴더들, 그리고 새 폴더. 줄을 여기로 끌어다 놓으면 옮겨진다.
    @ViewBuilder
    private var folderStrip: some View {
        // 화면 밖 렌더는 `ScrollView` 의 속을 그리지 못한다 (§14.9) — 그때는
        // 그냥 늘어놓는다. 실제 창에서는 폴더가 많으면 옆으로 넘긴다.
        if rendersStatically {
            HStack(spacing: Theme.tight) { folderChips }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)
                .clipped()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.tight) { folderChips }
                    .padding(.vertical, 2)
            }
            .frame(height: 30)
        }
    }

    @ViewBuilder
    private var folderChips: some View {
        chip(nil, count: model.total)
        ForEach(model.folders, id: \.self) { name in
            if model.renamingFolder == name {
                renameField(name)
            } else {
                chip(name, count: model.counts[name] ?? 0)
            }
        }
        if model.shownNaming {
            namingField
        } else {
            newFolderButton
        }
    }

    @ViewBuilder
    private func chip(_ folder: String?, count: Int) -> some View {
        // 우클릭 메뉴와 놓을 자리는 화면 밖 렌더가 그리지 못한다 (§14.9) —
        // 렌더에서는 칩만 그린다. 실제 창에서는 셋이 다 있다.
        if rendersStatically {
            chipButton(folder, count: count)
        } else {
            chipButton(folder, count: count)
                .contextMenu {
                    if let folder {
                        Button(L("이름 바꾸기")) { model.renamingFolder = folder }
                        Button(L("폴더 지우기 — 종이는 서랍에 남습니다"), role: .destructive) {
                            model.deleteFolder(folder)
                        }
                    }
                }
                // 목록의 줄을 여기로 끌어다 놓으면 그 폴더로 간다 (`DrawerRow` 의 `draggable`).
                .dropDestination(for: String.self) { items, _ in
                    let ids = items.compactMap(ULID.init)
                    guard !ids.isEmpty else { return false }
                    for id in ids { model.move(id, to: folder) }
                    model.clearPicked()
                    return true
                }
        }
    }

    private func chipButton(_ folder: String?, count: Int) -> some View {
        let selected = model.shownFolder == folder
        return Button {
            model.selectedFolder = folder
        } label: {
            HStack(spacing: 4) {
                if folder == nil {
                    Image(systemName: "tray").font(.system(size: 9, weight: .semibold))
                }
                Text(folder ?? DrawerContents.everything)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text("\(count)")
                    .font(Theme.micro)
                    .opacity(0.72)
            }
            .padding(.horizontal, Theme.snug)
            .frame(height: 26)
            .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryInk)
            .background(
                selected ? Theme.accent : Theme.softAccent,
                in: Capsule()
            )
            .fixedSize()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .spoken(folder.map { L("\($0) — \(count)장. 눌러서 이 폴더만 봅니다") }
                ?? L("전체 — \(count)장. 눌러서 서랍 전체를 봅니다"))
    }

    private var newFolderButton: some View {
        Button { model.isNamingFolder = true } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                Text(L("새 폴더")).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, Theme.snug)
            .frame(height: 26)
            .foregroundStyle(Theme.accentInk)
            .overlay(Capsule().strokeBorder(Theme.accentInk.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .spoken(L("새 폴더 — 이름을 적고 ↩ 를 누르면 생깁니다"))
    }

    /// 새 폴더 이름을 적는 자리. ↩ 로 만들고 esc 로 그만둔다.
    private var namingField: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.badge.plus").font(.system(size: 10, weight: .medium))
            if rendersStatically {
                Text(L("새 폴더 이름")).font(.system(size: 11)).foregroundStyle(Theme.secondaryInk.opacity(0.7))
            } else {
                TextField(L("새 폴더 이름"), text: $newFolderName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($namingFocused)
                    .onSubmit { model.createFolder(newFolderName) }
                    .frame(width: 104)
            }
        }
        .padding(.horizontal, Theme.snug)
        .frame(height: 26)
        .foregroundStyle(Theme.accentInk)
        .background(Theme.softAccent, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.accentInk.opacity(0.6), lineWidth: 1))
    }

    private func renameField(_ old: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "pencil").font(.system(size: 10, weight: .medium))
            TextField(L("폴더 이름"), text: $renameText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($renamingFocused)
                .onSubmit { model.renameFolder(old, to: renameText) }
                .frame(width: 104)
        }
        .padding(.horizontal, Theme.snug)
        .frame(height: 26)
        .foregroundStyle(Theme.accentInk)
        .background(Theme.softAccent, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.accentInk.opacity(0.6), lineWidth: 1))
    }

    // MARK: 목록

    @ViewBuilder
    private var list: some View {
        if model.shown.isEmpty {
            empty
        } else if rendersStatically {
            // 화면 밖 렌더는 `ScrollView` 의 속을 그리지 못한다 — 들어가는 만큼만 놓는다.
            VStack(spacing: 2) {
                ForEach(model.shown) { memo in row(memo) }
            }
            .padding(.vertical, 2)
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
        } else {
            ScrollViewReader { reader in
                ScrollView(.vertical, showsIndicators: plan.scrolls) {
                    VStack(spacing: 2) {
                        ForEach(model.shown) { memo in
                            row(memo).id(memo.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: model.focused) { _, id in
                    if let id { withAnimation(quick) { reader.scrollTo(id, anchor: .center) } }
                }
                .onChange(of: model.expanded) { _, id in
                    if let id { withAnimation(quick) { reader.scrollTo(id, anchor: .top) } }
                }
            }
        }
    }

    /// 아무것도 안 보이는 서랍. **빈 것과 못 찾은 것은 다른 말이다.**
    ///
    /// 찾는 중에 「여기 아무것도 없습니다」라고 하면 사람은 그것을 «서랍이
    /// 비었다» 로 읽는다 — 방금 종이 여덟 장을 넣어 둔 사람에게 그 말은
    /// 거짓말이고, 이 화면에서 가장 비싼 오해다 (`DrawerContents`).
    private var empty: some View {
        VStack(spacing: 5) {
            Text(emptyTitle)
                .font(Theme.label)
                .foregroundStyle(Paper.ink.opacity(0.42))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(emptyHint)
                .font(Theme.micro)
                .foregroundStyle(Paper.ink.opacity(0.28))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        if model.isSearching { return L("「\(model.shownQuery)」로 찾은 것이 없습니다") }
        if let folder = model.shownFolder { return L("「\(folder)」는 비어 있습니다") }
        return L("여기 아무것도 없습니다")
    }

    private var emptyHint: String {
        if model.isSearching { return L("서랍에는 \(model.total)장이 들어 있습니다 — esc 로 되돌립니다") }
        if model.shownFolder != nil {
            return L("줄을 이 폴더로 끌어다 놓거나, 이 폴더를 연 채로 종이를 서랍에 넣으면 여기로 옵니다")
        }
        return L("종이를 끌어다 놓거나, 종이의 ×를 누르면 들어옵니다")
    }

    private func row(_ memo: Memo) -> some View {
        DrawerRow(
            memo: memo,
            isPointed: pointed == memo.id,
            isPicked: model.shownPicked.contains(memo.id),
            isExpanded: model.shownExpanded == memo.id,
            showsFolder: model.shownFolder == nil,
            folders: model.folders,
            onTakeOut: { model.takeOut(memo.id) },
            onZoom: { model.zoom(memo.id) },
            onDelete: { model.delete(memo.id) },
            onMove: { model.move(memo.id, to: $0) }
        )
        // **누르면 꺼낸다** (§16.12). 펼쳐 보는 것은 줄의 › 와 Space 다.
        // **⌘ 를 누른 채 누르면 고른다.** Finder 와 같은 손짓이라 배울
        // 것이 없고, 그냥 누르는 것을 빼앗지도 않는다.
        .onTapGesture { model.takeOut(memo.id) }
        .simultaneousGesture(TapGesture().modifiers(.command).onEnded { model.pick(memo.id) })
        .draggable(memo.id.stringValue)
        .onHover { inside in
            if inside { hovered = memo.id } else if hovered == memo.id { hovered = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(
            model.shownPicked.contains(memo.id)
                ? L("\(memo.title) — 골랐습니다. \(MemoTimeLabel.text(for: memo))")
                : "\(memo.title) — \(MemoTimeLabel.text(for: memo))"
        ))
        .accessibilityHint(Text(L("눌러서 꺼냅니다. Space 로 펼쳐 보고, ⌘ 를 누른 채 누르면 고릅니다")))
    }

    // MARK: 바닥 한 줄

    /// 바닥 한 줄 — **지금 말할 것이 있는 쪽이 이긴다.**
    ///
    /// | 언제 | 무엇을 말하나 |
    /// |---|---|
    /// | 골라 둔 줄이 있으면 | 「3장 골랐습니다」와 모두 꺼내기·옮기기·지우기 |
    /// | 방금 꺼낸 것이 있으면 | 「「x」 꺼냈습니다」와 도로 넣기 — 줄 한 번이 꺼내기가 된 값을 싸게 |
    /// | 방금 넣은 것이 있으면 | 「「x」 넣었습니다」와 꺼내기 |
    /// | 종이가 떠 있으면 | 「놓으면 들어옵니다」 (판 전체의 덮개가 크게 말하고, 여기는 받쳐 준다) |
    /// | 그 밖에 | 손짓 안내 — 거의 안 보이게 |
    @ViewBuilder
    private var footer: some View {
        HStack(spacing: Theme.tight) {
            if model.pickedLabel != nil {
                pickedControls
            } else if let out = model.shownLastTakenOut {
                takenOutNotice(out)
            } else if let filed = model.shownLastFiled {
                filedNotice(filed)
            } else if landing != nil {
                Text(landingTitle)
                    .font(Theme.micro)
                    .foregroundStyle(Theme.accentInk)
            } else {
                Text(L("줄을 누르면 꺼냅니다 · Space 펼쳐 보기 · ⌘-클릭으로 여러 장 · 줄을 폴더로 끌기"))
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(isHovering ? 0.42 : 0.26))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(height: DrawerGeometry.footerHeight, alignment: .bottom)
    }

    /// 「「x」 꺼냈습니다 · 도로 넣기」 — 되돌리는 길이 보이면 잘못 누른 것은
    /// 사고가 아니라 한 번 더 누르는 일이다 (HIG Undo and redo).
    private func takenOutNotice(_ out: Memo) -> some View {
        HStack(spacing: Theme.tight) {
            Text(L("「\(short(out.title))」 꺼냈습니다"))
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            footerButton(L("도로 넣기"), help: L("도로 넣기 — 방금 꺼낸 종이를 다시 서랍에 넣습니다")) {
                model.putBack()
            }
        }
    }

    /// 고른 줄에 대한 조작 — **여기 말고는 자리가 없다.**
    ///
    /// 줄마다 조작을 붙이면 목록이 단추밭이 된다. 고르기는 여러 장에
    /// 한 번에 거는 일이므로, 말도 한 번에 한 자리에서 한다.
    private var pickedControls: some View {
        HStack(spacing: Theme.tight) {
            Text(model.pickedLabel ?? "")
                .font(Theme.micro)
                .foregroundStyle(Theme.accentInk)
                .lineLimit(1)

            footerButton(L("모두 꺼내기"), help: L("모두 꺼내기 — 고른 종이를 전부 바탕화면으로 되돌립니다")) {
                model.takeOutPicked()
            }

            if rendersStatically {
                moveLabel
            } else {
                Menu {
                    Button(L("폴더에서 빼기")) { model.movePicked(to: nil) }
                    if !model.folders.isEmpty { Divider() }
                    ForEach(model.folders, id: \.self) { name in
                        Button(name) { model.movePicked(to: name) }
                    }
                } label: {
                    moveLabel
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(Theme.accentInk)
                .spoken(L("옮기기 — 고른 종이를 다른 폴더로 보냅니다"))
            }

            RowTrash(isLit: true, help: L("모두 지우기 — 메뉴의 되돌리기로 살릴 수 있습니다")) {
                model.deletePicked()
            }
        }
    }

    private var moveLabel: some View {
        HStack(spacing: 2) {
            Text(L("옮기기"))
            Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
        }
        .font(Theme.micro)
        .foregroundStyle(Theme.accentInk)
        .padding(.horizontal, Theme.tight)
        .frame(height: Theme.touchRow)
        .contentShape(.rect)
    }

    private func filedNotice(_ filed: Memo) -> some View {
        HStack(spacing: Theme.tight) {
            Text(L("「\(short(filed.title))」 넣었습니다"))
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            footerButton(L("꺼내기"), help: L("꺼내기 — 방금 넣은 종이를 도로 바탕화면으로 보냅니다")) {
                model.takeOut(filed.id)
            }
        }
    }

    private func footerButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.micro)
                .padding(.horizontal, Theme.tight)
                .hitTarget(Theme.touchRow)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accentInk)
        .spoken(help)
    }

    private func short(_ title: String) -> String {
        title.count > 14 ? String(title.prefix(14)) + "…" : title
    }
}

/// 탭의 오른쪽 클릭 메뉴가 부르는 곳. `NSMenuItem` 은 셀렉터를 원해서 한 겹 둔다.
@MainActor
private final class DrawerMenuTarget: NSObject {
    private let model: DrawerModel
    init(model: DrawerModel) { self.model = model }
    @objc func open() { model.setOpen(true) }
    @objc func dismiss() { model.onDismiss() }
}
