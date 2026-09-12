import LazyMemoCore
import SwiftUI

/// 「서랍」 — 바탕화면에 상주하는 폴더.
///
/// ## 왜 있는가
///
/// 이 앱에는 종이를 **밀어 두는** 길이 이미 둘 있었다. 사람이 ×를 누르는 것과,
/// 낡은 것이 스스로 물러나는 것(`Tidy`). 그런데 밀어 둔 종이가 **어디로 갔는지
/// 보여주는 자리**가 없었다 — ×를 누르면 그 순간 화면에서 없어졌고, 스스로
/// 물러난 것은 메뉴 안쪽의 숫자 하나로만 남았다. 설계문서가 걱정하던 그대로다:
/// *"목록에서 빠지기만 하면, 사람은 그것을 「정리됐다」가 아니라 「없어졌다」로
/// 읽는다."* 서랍은 그 N장에 **몸을 준다** (`DrawerContents`).
///
/// ## 세 가지 크기와 그 사이의 동작
///
/// | 무엇 | 어떻게 |
/// |---|---|
/// | 닫힌 폴더 | 바탕화면에 늘 앉아 있다. 종이 몇 장이 삐죽 나와 몇 장인지 말한다 |
/// | 누르면 | 창이 **왼쪽 위를 붙박은 채** 자라고, 종이들이 한 장씩 차례로 놓인다 |
/// | 종이를 누르면 | 그 한 장이 **원래 크기로** 자란다 (`matchedGeometryEffect`) |
/// | 한 번 더 누르면 | 도로 작아져 제 칸으로 돌아간다 |
/// | 손을 얹으면 | 잠깐 들린다 — 무엇을 누르게 되는지 먼저 말한다 |
///
/// 차례로 놓이는 것(stagger)은 장식이 아니다. 열둘이 한꺼번에 나타나면 눈이
/// 어디를 봐야 할지 모르고, 그 순간 서랍은 «내용물» 이 아니라 «격자» 로 읽힌다.
/// 한 장씩 놓이면 그것이 **종이 무더기**라는 것이 동작만으로 전해진다.
///
/// **움직임을 줄이라고 한 사람에게는 움직이지 않는다** (`accessibilityReduceMotion`).
/// 이 화면에서 동작은 뜻을 나르지만, 뜻은 자리와 크기에도 이미 들어 있다 —
/// 차례로 놓이는 대신 그냥 놓이고, 자라는 대신 그냥 커진다.
struct DrawerView: View {
    @Bindable var model: DrawerModel

    @Namespace private var papers
    @State private var hovered: ULID?
    @State private var isHovering = false
    /// 찾기 상자의 커서. **진짜 글 상자여야 한다** — 한글은 조합 입력이라
    /// 날 키 이벤트를 모아 글자를 만들면 「장」을 치는데 「wkd」가 쌓인다
    /// (`DrawerKeys`).
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rendersStatically) private var rendersStatically

    private var plan: DrawerGeometry { model.geometry() }
    /// 지금 «짚힌» 한 장. **손이 얹힌 것과 키보드가 짚은 것이 같은 자리다** —
    /// 두 곳에서 같은 일을 다르게 그리면 두 개의 물건이 된다 (§14.10).
    private var pointed: ULID? { model.staged?.hovered ?? hovered ?? model.focused }

    // MARK: 움직임

    /// 펼치고 접는 속도. 창의 크기 변화와 **같은 시간**이어야 한다
    /// (`DrawerWindowController.duration`) — 둘이 다르면 내용이 먼저 나오고
    /// 창이 뒤따라 커지면서 한 프레임 잘려 보인다.
    private var opening: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.34, dampingFraction: 0.86)
    }

    /// 한 장이 자라고 줄어드는 속도. 펼치는 것보다 조금 빠르고 덜 튄다 —
    /// 종이 한 장은 서랍 전체보다 가볍다.
    private var zooming: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.30, dampingFraction: 0.84)
    }

    private var lifting: Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.22, dampingFraction: 0.7)
    }

    /// 몇 번째 종이가 얼마나 늦게 놓이는가. 열둘째까지만 밀린다 — 그 뒤로도
    /// 밀면 마지막 장이 나오기까지 사람이 기다려야 한다.
    private func stagger(_ index: Int) -> Double {
        reduceMotion ? 0 : Double(min(index, 11)) * 0.022
    }

    var body: some View {
        Group {
            if model.shownOpen {
                opened
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.paper(MemoColor.gray.ink, radius: shellRadius, dotted: false))
                    .overlay(Theme.edge(radius: shellRadius))
                    // 닿는 자리와 퍼지는 자리를 나눈다 (`DrawerPaper`).
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
                    .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            } else {
                // **닫힌 서랍에는 판이 없다.** 폴더를 종이 카드 위에 얹으면
                // 바탕화면에 사각형이 두 개 놓인 것으로 보인다 — 서랍은
                // 창이 아니라 **바탕화면에 놓인 물건**이어야 한다 (철학 4).
                closed
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay { HoverSensor { isHovering = $0 } }
        .animation(opening, value: model.shownOpen)
        .animation(zooming, value: model.shownZoomed)
        .animation(lifting, value: pointed)
        .animation(opening, value: model.shownLanding)
        .animation(opening, value: model.count)
        .animation(opening, value: plan.stacked)
        .animation(lifting, value: model.shownPicked)
        // **한 겹씩 되돌린다** — 고르기 → 찾기 → 펼친 종이 → 짚은 자리 → 서랍
        // (`DrawerModel.escape`). 한 번에 전부 닫으면 세 글자를 찾다가 한 번
        // 잘못 눌렀을 때 서랍이 통째로 닫힌다.
        .onExitCommand { model.escape() }
        // 커서를 옮겨 달라는 부탁 (`DrawerModel.focusRequest`) — ⌘F 로 들어오고,
        // esc 로 빠져나온다.
        .onChange(of: model.focusRequest.count) { searchFocused = model.focusRequest.wantsSearch }
        // 서랍을 접으면 커서도 놓는다. 안 놓으면 다음에 펼쳤을 때 커서만
        // 찾기 줄에 남아 있어서, ↑↓ 가 무더기 대신 상자로 간다.
        .onChange(of: model.shownOpen) { if !model.shownOpen { searchFocused = false } }
        // **커서가 어디 있는지는 여기만 확실히 안다.** 창이 키를 나눌 때 이
        // 값을 본다 (`DrawerModel.isEditingSearch`).
        .onChange(of: searchFocused) { model.isEditingSearch = searchFocused }
    }

    private var shellRadius: CGFloat { model.shownOpen ? Theme.panelRadius : Theme.cardRadius }

    // MARK: 닫힌 무더기

    /// 닫힌 서랍 — **밀어 둔 종이 무더기의 끝.**
    ///
    /// 폴더 그림이었다. 뒤판·탭·앞판을 그리고 앞판 한가운데에 「8장」이라고
    /// 크게 적었는데, 그 순간 바탕화면에 **위젯이 하나 늘어난 것**으로 보였다.
    /// 이 앱의 재질은 종이 하나이고(§14.5), 화면에 머리글도 숫자 배지도 두지
    /// 않기로 했다(철학 4) — 폴더는 그 둘을 한꺼번에 어겼다.
    ///
    /// 지금은 **종이만 그린다.** 맨 위 한 장이 첫 줄을 들고, 그 아래 것들은
    /// 끝만 삐죽 나와 두께로 몇 장인지 말한다 — 달력의 번진 얼룩과 같은 낱말이다
    /// (§10.4). 숫자는 적지 않는다: 두께가 이미 말하고, 정확한 수가 필요한
    /// 사람에게는 메뉴가 「치워 둔 N장」으로 말한다.
    private var closed: some View {
        Button { model.toggle() } label: {
            ZStack(alignment: .topLeading) {
                underEdges
                topSheet
            }
            .frame(width: Self.box.width, height: Self.box.height, alignment: .topLeading)
            .shadow(color: .black.opacity(landing != nil ? 0.14 : 0.22), radius: 1, y: 0.5)
            .shadow(
                color: .black.opacity(landing != nil ? 0.24 : 0.11),
                radius: landing != nil ? 10 : 5, y: landing != nil ? 3 : 1.5
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // 손이 오면 잠깐 들린다 — 다만 «누를 수 있다» 를 크기 혼자 말하지는
        // 않는다. 무더기가 함께 **느슨해진다** (`looseness`).
        .scaleEffect(landing != nil ? 1.06 : (isHovering ? 1.03 : 1))
        .animation(lifting, value: isHovering)
        .animation(lifting, value: landing)
        .spoken("서랍 — \(model.title). 눌러서 펼칩니다")
    }

    /// 무더기가 얼마나 **풀어져** 있는가. 1 이면 가지런하고, 클수록 흐트러진다.
    ///
    /// 닫힌 서랍의 어려움은 «이것이 누를 수 있는 물건이다» 를 말하는 자리가
    /// 없다는 것이다. 머리글도 배지도 두지 않기로 했으므로(철학 4) 남은 말은
    /// 크기뿐인데, 3%든 6%든 108pt 짜리 물건에서 크기 변화는 잘 안 보인다.
    ///
    /// 그래서 **종이 무더기가 실제로 하는 일**을 시킨다 — 손이 닿으면 미끄러지고
    /// 흐트러진다. 그 한 번이 «눌러도 된다» 와 «이건 낱장이 아니라 무더기다» 를
    /// 동시에 말하고, 펼쳤을 때 무엇이 나올지까지 미리 말한다.
    ///
    /// 종이가 위에 떠 있을 때 가장 크게 벌어진다 — 받으려고 입을 여는 셈이다.
    private var looseness: Double {
        if landing != nil { return 2.2 }
        return isHovering ? 1.7 : 1
    }

    /// 닫힌 무더기가 그려지는 상자.
    private static let box = CGSize(width: 108, height: 76)
    /// 아래 장이 위 장보다 이만큼씩 어긋나 끝을 내민다.
    private static let edgeStep: CGFloat = 5

    /// 아래 장들이 **비뚤게** 놓인 각도. 깊이마다 다르고, 부호가 번갈아 간다.
    ///
    /// 계단만으로 쌓았더니 사각형 넷이 자로 잰 듯 겹쳐서, 바탕화면에서 그것이
    /// **그림자 진 카드 한 장**으로 보였다 — 메모 한 장과 구별되지 않았다.
    /// 사람이 밀어 둔 종이는 가지런하지 않다. 몇 도만 어긋나면 그 순간
    /// «여러 장» 이 되고, 이 앱의 재질(종이)에서 벗어나지도 않는다.
    private static let tilts: [Double] = [-5.0, 3.4, -2.1]
    /// 계단 셋이 다 들어가고 남는 종이 크기.
    private static let sheetSide = CGSize(
        width: box.width - edgeStep * 3, height: box.height - edgeStep * 3
    )

    /// 맨 위 한 장 아래로 삐죽 나온 종이들 — **두께가 곧 장수다.**
    private var underEdges: some View {
        ForEach(Array(model.peekingInks.enumerated().reversed()), id: \.offset) { depth, paper in
            let step = CGFloat(depth + 1) * Self.edgeStep
            RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                .fill(Color(nsColor: PaperTint.surface(ink: paper.ink, dark: isDark, presence: 1)))
                // **작아진 종이도 종이다.** 사방을 같은 세기로 두르면 §14.5 가
                // 걷어내려 한 그 «색칠한 사각형» 이 작은 크기에서 되살아난다
                // (`PaperEdge`) — 큰 종이만 두께를 갖고 작은 종이는 칩이 된다.
                .overlay { Theme.edge(radius: Theme.chipRadius) }
                // **크기는 같고 자리만 계단이다.** 깊은 장을 더 작게 만들면서
                // 더 밀어 두었더니 오른쪽 아래 끝이 같은 자리에 모여 서로를
                // 통째로 덮었다 — 세 겹을 그려 놓고 한 겹만 보였다.
                .frame(width: Self.sheetSide.width, height: Self.sheetSide.height)
                .rotationEffect(.degrees(Self.tilts[depth % Self.tilts.count] * looseness))
                .offset(x: step * CGFloat(looseness), y: step * CGFloat(looseness))
        }
    }

    /// 맨 위 종이. **첫 줄을 든다** — 무더기가 무엇인지 한 줄로 말하는 유일한 자리다.
    private var topSheet: some View {
        RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
            .fill(Color(nsColor: PaperTint.surface(
                ink: model.papers.first?.color.ink ?? MemoColor.yellow.ink,
                dark: isDark, presence: 1
            )))
            .overlay { Theme.edge(radius: Theme.chipRadius) }
            .overlay(alignment: .topLeading) {
                Text(model.papers.first?.title ?? "여기 아무것도 없습니다")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Paper.ink.opacity(model.papers.isEmpty ? 0.30 : 0.80))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, Theme.tight + 1)
                    .padding(.top, Theme.tight)
            }
            .overlay {
                // 종이가 서랍 위에 떠 있다 — 놓으면 들어온다.
                if landing != nil {
                    RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                        .strokeBorder(Theme.accentInk.opacity(0.7), lineWidth: 1.5)
                }
            }
            .frame(width: Self.sheetSide.width, height: Self.sheetSide.height)
    }



    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private var landing: ULID? { model.shownLanding }

    // MARK: 펼친 서랍

    private var opened: some View {
        VStack(spacing: 0) {
            drawerHeading
            content
            footer
        }
        .padding(DrawerGeometry.padding)
        // 한 장이 원래 크기로 나와 있으면 **뒤가 물러난다.** 겹쳐 뜬 종이의
        // 뒤에 또렷한 제목 여덟 줄이 그대로 있으면 눈이 둘로 갈리고, 그러면
        // 앞의 종이는 «펼쳐진 것» 이 아니라 «위에 얹힌 딴것» 으로 보인다.
        .blur(radius: model.shownZoomed == nil ? 0 : 2.5)
        .overlay { zoomedPaper }
    }

    private var drawerHeading: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full.fill")
                .foregroundStyle(Theme.accentInk)
            Text("서랍").font(.system(size: 17, weight: .bold))
            Text("\(model.total)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.accentInk)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Theme.softAccent, in: Capsule())
            Spacer()
            QuietButton(symbol: "xmark", help: "접기 — 서랍을 닫습니다") {
                model.setOpen(false)
            }
        }
        .frame(height: DrawerGeometry.headerHeight, alignment: .top)
    }

    /// 제목과 조작 아래에 보관한 메모를 겹쳐 보여 준다.
    @ViewBuilder
    private var content: some View {
        if model.shown.isEmpty {
            empty
        } else {
            pile
        }
    }

    /// 빈 서랍. **채우라고 말하지 않는다** (철학 1) — 무엇이 여기 오는지만 적는다.
    /// 아무것도 안 보이는 서랍. **빈 것과 못 찾은 것은 다른 말이다.**
    ///
    /// 찾는 중에 「여기 아무것도 없습니다」라고 하면 사람은 그것을 «서랍이
    /// 비었다» 로 읽는다 — 방금 종이 여덟 장을 넣어 둔 사람에게 그 말은
    /// 거짓말이고, 이 화면에서 가장 비싼 오해다 (`DrawerContents`).
    private var empty: some View {
        VStack(spacing: 5) {
            Text(model.isSearching ? "「\(model.shownQuery)」로 찾은 것이 없습니다" : "여기 아무것도 없습니다")
                .font(Theme.label)
                .foregroundStyle(Paper.ink.opacity(0.42))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(model.isSearching
                ? "서랍에는 \(model.total)장이 들어 있습니다 — esc 로 되돌립니다"
                : "종이를 끌어다 놓거나, 종이의 ×를 누르면 들어옵니다")
                .font(Theme.micro)
                .foregroundStyle(Paper.ink.opacity(0.28))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// **겹쳐 쌓인 무더기.** 격자였던 자리다.
    ///
    /// 격자는 여덟 장을 색으로만 갈라 놓아서, 원하는 것을 찾으려면 하나씩
    /// 눌러 봐야 했다 — 메뉴 목록보다 나빴다. 겹쳐 쌓으면 **첫 줄이 동시에 다
    /// 읽힌다.** 그리고 그 모양이 곧 «밀어 둔 종이 무더기» 라, §16.2 가 스스로
    /// 걱정하던 「격자로 읽힌다」에서 벗어난다.
    private var pile: some View {
        ZStack(alignment: .top) {
            ForEach(Array(model.shown.prefix(plan.stacked).enumerated()), id: \.element.id) { index, memo in
                sheet(memo, index: index, top: index == plan.stacked - 1)
            }
            .animation(lifting, value: pointedIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 무더기의 한 장.
    ///
    /// **손이 얹히면 반쯤 빠져나온다.** 셋이 한꺼번에 온다 — 잠깐 커지고
    /// (`hoverScale`), 옆으로 밀려 나오고(`slide`), 아래 것들이 한 뼘 내려간다
    /// (`lift`). 그러면 30pt 짜리 띠가 80pt 남짓으로 벌어지면서 **제목 밑에
    /// 잠들어 있던 두 줄이 그 자리에서 드러난다** (`DrawerPaper`).
    ///
    /// 예전에는 그 한 장을 **통째로** 드러냈다. 잘 보이긴 했지만 창이 그
    /// 124pt 를 늘 비워 두고 있어야 했고, 손을 치우면 판의 아래 4분의 1이
    /// 빈 채로 남았다. 「원래 크기로 펼치기」가 이미 통째로 보여주는데 —
    /// 손만 얹어도 통째로 보여주려다 판 전체를 빈자리에 저당 잡힌 것이다.
    private func sheet(_ memo: Memo, index: Int, top: Bool) -> some View {
        let lifted = pointed == memo.id
        let hidden = model.shownZoomed == memo.id
        // **고른 장에는 테두리 하나만 두른다.** 체크상자도 배지도 두지 않는다
        // (철학 4) — 이 앱의 종이에 없는 물건이다.
        //
        // 처음에는 손이 얹혔을 때처럼 **옆으로 밀어 내** 두었다. 그러자 §16.3
        // 이 이미 적어 둔 고장이 그대로 돌아왔다 — 묻힌 장은 띠만 보이는데
        // 그것을 옆으로 밀면 **덮인 줄 알았던 몸통이 다음 장들 오른쪽으로
        // 빠져나온다.** 골라 둔 세 장이 무더기 옆에 색 띠 하나를 그렸다.
        // 겹친 무더기에서는 «자리» 로 말할 수 없다. 자리는 이미 겹침이 쓰고 있다.
        let isPicked = model.shownPicked.contains(memo.id)
        // **무더기의 맨 앞 한 장만 통째로 적는다.** 뒤엣것들은 어차피 다음
        // 장이 덮으므로 거기에 본문을 다 그려 두면 읽을 수 없는 회색 줄무늬가
        // 될 뿐이다 — 대신 두 줄만 잠들어 있다가 손이 오면 드러난다.
        //
        // 손이 얹혔다고 이 값을 뒤집지 않는다. 뒤집으면 글이 새로 짜이면서
        // 종이가 «드러난» 것이 아니라 «갈아 끼운» 것으로 보인다.
        let whole = top

        // 맨 앞 한 장만 종이 크기 그대로다. 뒤엣것들은 보일 수 있는 만큼만
        // 그린다 (`DrawerGeometry.peek`) — 안 그러면 커질 때 덮인 몸통이
        // 옆으로 빠져나온다.
        let size = whole
            ? DrawerGeometry.sheet
            : CGSize(width: DrawerGeometry.sheet.width, height: DrawerGeometry.peek)

        return DrawerPaper(memo: memo, size: size, detail: whole, lifted: lifted)
            // 펼쳐 놓은 장은 **원본이 아니다.** 자리는 비워 두되(`opacity`)
            // 뷰는 남겨 두는데, 그러면 같은 id 를 가진 것이 둘이 되어
            // `matchedGeometryEffect` 가 펼친 종이를 무더기 자리에 놓는다 —
            // 창 위로 잘려 제목이 안 보였다.
            .matchedGeometryEffect(id: memo.id, in: papers, isSource: !hidden)
            // 되돌려 놓은 종이의 자리는 **비워 두고 지킨다** — 자리가 사라지면
            // 나머지가 다시 짜이고, 그러면 한 장을 여는 동작이 무더기를 흔든다.
            .opacity(hidden ? 0 : 1)
            // 잠깐 커진다 — 사람이 부탁한 그 동작이다. 위쪽을 붙박고 자라야
            // 제목이 제자리에 있고, 자라는 몫이 전부 **아래로** 간다.
            .scaleEffect(lifted ? DrawerGeometry.hoverScale : 1, anchor: .top)
            // 골라 둔 표시 — 종이의 색을 덮지 않는 가는 테두리 하나다.
            .overlay {
                if isPicked {
                    RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                        .strokeBorder(Theme.accentInk.opacity(0.85), lineWidth: 1.5)
                }
            }
            // 얹힌 장 **아래**의 것들이 한 뼘 내려간다. 맨 위로 올리지 않는
            // 이유는 그때 그 위의 장들이 슬라이버로 뭉개지기 때문이다 —
            // 겹친 무더기에서 한 장을 위로 빼면 반드시 무언가를 가린다.
            .offset(
                x: lifted ? Self.slide : 0,
                y: plan.offset(of: index) + (opensBelow(index) ? DrawerGeometry.lift : 0)
            )
            .zIndex(Double(index))
            // **⌘ 를 누른 채 누르면 고른다.** Finder 와 같은 손짓이라 배울
            // 것이 없고, 그냥 누르는 것(펼치기)을 빼앗지도 않는다.
            .onTapGesture { model.zoom(memo.id) }
            .simultaneousGesture(TapGesture().modifiers(.command).onEnded {
                model.pick(memo.id)
            })
            .overlay {
                HoverSensor { inside in
                    if inside { hovered = memo.id }
                    else if hovered == memo.id { hovered = nil }
                }
            }
            // 한 장씩 차례로 놓인다 (`stagger`).
            .transition(
                .scale(scale: 0.9, anchor: .topLeading)
                    .combined(with: .opacity)
                    .animation(opening.delay(stagger(index)))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(
                isPicked
                    ? "\(memo.title) — 골랐습니다. \(MemoTimeLabel.text(for: memo))"
                    : "\(memo.title) — \(MemoTimeLabel.text(for: memo))"
            ))
            .accessibilityHint(Text("눌러서 원래 크기로 펼칩니다. ⌘ 를 누른 채 누르면 고릅니다"))
            .help("\(memo.title) — 눌러서 펼치고, ⌘ 를 누른 채 누르면 고릅니다")
    }

    /// 지금 손이 얹힌 장의 차례. 없으면 `nil`.
    private var pointedIndex: Int? {
        guard let pointed else { return nil }
        return model.shown.prefix(plan.stacked).firstIndex { $0.id == pointed }
    }

    /// 이 장이 «벌어진 자리» 의 아래쪽인가 — 그러면 한 뼘 내려간다.
    private func opensBelow(_ index: Int) -> Bool {
        guard let pointedIndex else { return false }
        return index > pointedIndex
    }

    /// 얹힌 장이 옆으로 밀려 나오는 거리 — 무더기에서 살짝 빠져나온 느낌만.
    private static let slide: CGFloat = 8

    @ViewBuilder
    private var zoomedPaper: some View {
        if let id = model.shownZoomed, let memo = model.shown.first(where: { $0.id == id }) {
            ZStack {
                Rectangle()
                    .fill(Paper.ink.opacity(0.20))
                    .contentShape(.rect)
                    .onTapGesture { model.shrink() }
                    .transition(.opacity)

                DrawerPaper(memo: memo, size: model.fullSize(of: id), detail: true, lifted: true)
                    // 무더기에서 **한 장만 집어 든** 높이. 서랍 안의 다른 장들은
                    // 바닥에 놓여 있고 이것만 손에 들려 있다.
                    .shadow(color: .black.opacity(0.26), radius: 20, y: 8)
                    .matchedGeometryEffect(id: id, in: papers)
                    .onTapGesture { model.shrink() }
                    .overlay(alignment: .bottomTrailing) { zoomedControls(memo) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(memo.title))
                    .accessibilityHint(Text("눌러서 도로 작아집니다"))
            }
            .zIndex(2)
        }
    }

    /// 펼친 종이의 조작 — 종이가 하는 것과 같은 낱말이다 (`NoteView.paperControls`).
    ///
    /// 여기서는 **늘 보인다.** 겹쳐 뜨는 조작은 «읽으러 온 손» 을 방해하지 않으려는
    /// 규칙인데(철학 4), 이 종이는 사람이 방금 눌러서 펼친 것이라 이미 손이 와 있다.
    private func zoomedControls(_ memo: Memo) -> some View {
        HStack(spacing: NoteControlLayout.spacing) {
            Button { model.takeOut(memo.id) } label: {
                Text("꺼내기")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, Theme.tight)
                    .frame(height: Theme.touch)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accentInk)
            .spoken("꺼내기 — 이 종이를 바탕화면으로 되돌립니다")

            Rectangle()
                .fill(Paper.ink.opacity(0.18))
                .frame(width: 1, height: 13)
                .padding(.horizontal, Theme.hairline)

            RowTrash(isLit: true, help: "지우기 — 메뉴의 되돌리기로 살릴 수 있습니다") {
                model.delete(memo.id)
            }
        }
        .padding(.horizontal, NoteControlLayout.capsulePadding)
        .background {
            RaisedSurface(ink: memo.color.ink, radius: Theme.controlRadius, shadow: 4, lift: 1)
        }
        .padding(NoteControlLayout.paperInset)
    }

    /// 바닥 한 줄 — **서랍이 말하는 유일한 자리.**
    ///
    /// 이 줄 하나가 다섯 가지 일을 나눠 맡는다. 자리를 늘리지 않는 것이
    /// 요점이다 — 머리글도 도구 막대도 두지 않기로 했으므로(철학 4), 새 조작이
    /// 생길 때마다 **이 한 줄이 무엇을 말할지 고르는 방식**으로 늘린다.
    ///
    /// | 언제 | 무엇을 말하나 |
    /// |---|---|
    /// | 골라 둔 장이 있으면 | 「3장 골랐습니다」와 꺼내기·지우기 |
    /// | 방금 넣은 것이 있으면 | 「「x」 넣었습니다」와 되돌리기 |
    /// | 종이가 떠 있으면 | 「놓으면 들어옵니다」 |
    /// | 그 밖에 | **찾기 줄** — 쉬고 있을 때의 기본값이다 |
    ///
    /// 오른쪽 끝은 늘 같다 — 가려진 장이 몇 장인지, 그리고 그것을 펼치는 길.
    private var footer: some View {
        HStack(spacing: Theme.tight) {
            lead
            Spacer(minLength: Theme.tight)
            more
        }
        .frame(height: DrawerGeometry.footerHeight, alignment: .bottom)
    }

    /// 왼쪽 — 지금 말할 것이 있는 쪽이 이긴다.
    ///
    /// **찾는 중이면 찾기가 이긴다.** 글자를 치는 동안 종이 한 장이 서랍에
    /// 떨어졌다고 상자가 사라지면, 사람은 치던 글을 잃는다.
    @ViewBuilder
    private var lead: some View {
        if model.pickedLabel != nil {
            pickedControls
        } else if model.isSearching || searchFocused {
            searchField
        } else if let filed = model.shownLastFiled {
            filedNotice(filed)
        } else if landing != nil {
            Text("놓으면 들어옵니다")
                .font(Theme.micro)
                .foregroundStyle(Theme.accentInk)
        } else {
            searchField
        }
    }

    /// **찾기 — 진짜 글 상자다.**
    ///
    /// 날 키 이벤트를 모아 글자를 만들지 않는다. 한글은 조합 입력이라 그렇게
    /// 하면 「장」을 치는데 「wkd」가 쌓인다 — 한국어를 쓰는 사람에게 그 찾기는
    /// 없는 것과 같다 (`DrawerKeys` 가 글자 키를 아예 맡지 않는 이유다).
    ///
    /// 쉬고 있을 때는 **거의 보이지 않는다.** 늘 또렷한 상자를 두면 그것이 곧
    /// 도구 막대이고, 서랍은 다시 «앱» 이 된다 (철학 4). 손이 오거나 글자가
    /// 들어가면 그때 또렷해진다.
    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9, weight: .medium))
            // 화면 밖 렌더는 `NSViewRepresentable` 을 그리지 못한다 (§14.9) —
            // 글 상자 자리에 「금지」 표가 박힌 노란 막대가 남는다. 같은 글꼴·
            // 같은 자리의 `Text` 로 대신 그린다 (`MemoTextArea` 와 같은 셈).
            if rendersStatically {
                Text(model.shownQuery.isEmpty ? "찾기" : model.shownQuery)
                    .font(Theme.micro)
                    .lineLimit(1)
            } else {
                TextField("찾기", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(Theme.micro)
                    .focused($searchFocused)
                    .frame(maxWidth: 132)
            }
            if model.isSearching, let found = model.searchSummary {
                Text(found)
                    .font(Theme.micro)
                    .foregroundStyle(Paper.ink.opacity(0.40))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.secondaryInk)
        .padding(.horizontal, 8)
        .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 7))
        .hitTarget(Theme.touchRow)
        .onTapGesture { searchFocused = true }
        .spoken("찾기 — 서랍에 든 종이를 글자로 거릅니다. 첫소리로도 찾습니다")
    }

    /// 고른 장에 대한 조작 — **여기 말고는 자리가 없다.**
    ///
    /// 종이마다 조작을 붙이면 무더기가 단추밭이 된다. 고르기는 여러 장에
    /// 한 번에 거는 일이므로, 말도 한 번에 한 자리에서 한다.
    private var pickedControls: some View {
        HStack(spacing: Theme.tight) {
            Text(model.pickedLabel ?? "")
                .font(Theme.micro)
                .foregroundStyle(Theme.accentInk)
                .lineLimit(1)

            Button { model.takeOutPicked() } label: {
                Text("모두 꺼내기")
                    .font(Theme.micro)
                    .padding(.horizontal, Theme.tight)
                    .hitTarget(Theme.touchRow)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accentInk)
            .spoken("모두 꺼내기 — 고른 종이를 전부 바탕화면으로 되돌립니다")

            RowTrash(isLit: true, help: "모두 지우기 — 메뉴의 되돌리기로 살릴 수 있습니다") {
                model.deletePicked()
            }
        }
    }

    private func filedNotice(_ filed: Memo) -> some View {
        HStack(spacing: Theme.tight) {
            Text("「\(short(filed.title))」 넣었습니다")
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Button { model.takeOut(filed.id) } label: {
                // 방금 넣은 것을 도로 꺼내는 자리다 — 되돌리기와 같은 급이라
                // 글자 크기가 곧 과녁이면 안 된다.
                Text("꺼내기")
                    .font(Theme.micro)
                    .padding(.horizontal, Theme.tight)
                    .hitTarget(Theme.touchRow)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accentInk)
            .spoken("꺼내기 — 방금 넣은 종이를 도로 바탕화면으로 보냅니다")
        }
    }

    /// 오른쪽 끝 — **가려진 장, 그리고 그것을 펼치는 길.**
    ///
    /// 예전에는 글자였다. 「그리고 4장 더」라고 적어 놓고 **누를 수는 없었다** —
    /// 조용히 자르지는 않았지만, 그 넉 장을 보려면 앞의 여덟 장을 먼저 꺼내야
    /// 했다. 말만 하고 길을 안 내는 것은 자른 것과 크게 다르지 않다.
    @ViewBuilder
    private var more: some View {
        if let label = DrawerContents.overflow(count: model.count, shown: plan.stacked) {
            Button { model.revealMore() } label: {
                HStack(spacing: 3) {
                    Text(label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                }
                .font(Theme.micro)
                .lineLimit(1)
                .padding(.horizontal, Theme.tight)
                .hitTarget(Theme.touchRow)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Paper.ink.opacity(isHovering ? 0.60 : 0.34))
            .spoken("더 보기 — 가려진 종이를 여덟 장씩 더 펼칩니다")
        }
    }

    private func short(_ title: String) -> String {
        title.count > 14 ? String(title.prefix(14)) + "…" : title
    }
}
