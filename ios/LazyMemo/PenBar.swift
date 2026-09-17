import CoreLocationUI
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoPlaces
import SwiftUI

/// 유리 위의 펜 (MOBILE_DESIGN §3).
///
/// 조작은 유리, 종이는 콘텐츠 층이다. 그래서 여기에는 종이색도 윗변 선도 없다 —
/// 유리 조각들과 scroll edge effect 가 경계를 만든다. 틴트는 「남기기」 하나뿐이다.
/// 탭바 액세서리로 앉히면(`.inline`) 「적기…」 한 줄 알약이 되지만, 액세서리는
/// 키보드 위로 오르지 않아 지금은 `safeAreaInset` 에 앉는다 (`HomeView`).
struct PenBar: View {
    let pen: PenModel
    var fixing = false
    /// 「위치를 못 잡았습니다」 — 칩 자리에 한 번.
    var hereTrouble: String?
    var onHere: () -> Void = {}

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @FocusState private var focused: Bool
    /// 위젯의 「적기」— 앱이 이 주소로 깨어났거나 떠 있는 채 눌렸거나.
    @State private var links = AppLinks.shared

    var body: some View {
        Group {
            if placement == .inline {
                compact
            } else {
                expanded
            }
        }
        .task {
            // 켜면 펜이다 — 키보드가 이미 올라와 있다. **켤 때 한 번만.** 메모를
            // 읽고 돌아올 때마다 키보드가 튀어 오르면 그건 펜이 아니라 방해다.
            guard pen.takeLaunchFocus() else { return }
            try? await Task.sleep(for: .milliseconds(80))
            focused = true
        }
        .onChange(of: pen.focusRequest) { _, _ in
            // 편집 화면에 다녀오면 `focused` 는 켜진 채인데 키보드는 내려가 있다 — 같은 값을 다시 넣어서는 안 올라온다.
            // 껐다가 다음 턴에 켠다 (2026-09-16 시뮬레이터: 캐럿만 서고 키보드가 안 오르던 것).
            guard focused else { focused = true; return }
            focused = false
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                focused = true
            }
        }
        // 위젯의 「적기」— 펜이 서 있으면 바로, 아직 없었으면 서는 순간(`initial`) 받아 간다.
        // 받아 가면 비운다: 탭을 옮겨 펜이 다시 서도 두 번 오르지 않는다.
        .onChange(of: links.pendingWrite, initial: true) { _, pending in
            guard pending, links.takeWrite() else { return }
            // 첫 실행의 안내가 떠 있으면 그것이 닫힐 때 펜이 오른다 (`releaseLaunchFocus`).
            guard !pen.holdsLaunchFocus else { return }
            pen.requestFocus()
        }
    }

    /// 접힌 탭바 옆의 한 줄. 누르면 펜을 올린다.
    private var compact: some View {
        Button {
            pen.requestFocus()
        } label: {
            HStack {
                Image(systemName: "pencil.line")
                Text(pen.text.isEmpty ? String(localized: "적기…") : pen.text.split(separator: "\n").first.map(String.init) ?? String(localized: "적기…"))
                    .lineLimit(1)
                    .foregroundStyle(pen.text.isEmpty ? .secondary : .primary)
                Spacer()
            }
            .font(.body)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("적기")
        .accessibilityIdentifier("capture-compact")
    }

    private var expanded: some View {
        VStack(spacing: 6) {
            if let question = pen.pendingQuestion { pendingBlock(question) }
            else if let planner = pen.planner, planner.isActive { routeBlock(planner) }
            else if let notice = pen.planner?.notice { noticeRow(notice) }
            else { chips }
            penRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.snappy, value: pen.planner?.step)
    }

    // MARK: 가는 길 되묻기 — 「어디서 출발하시나요?」·「무엇으로 갈까요?」 (`RoutePlanner`, 맥의 상자와 같은 대화)

    private func routeBlock(_ planner: RoutePlanner) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = planner.summary {
                Text(summary).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(spacing: 8) {
                if planner.isBusy { ProgressView().controlSize(.small) }
                Text(planner.question ?? "").font(.subheadline.weight(.semibold))
            }
            if let trouble = planner.trouble {
                Text(trouble).font(.footnote).foregroundStyle(.orange)
            }
            if !planner.choices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(planner.choices, id: \.self) { choice in
                            Button { planner.choose(choice) } label: {
                                Text(LocalizedStringKey(choice))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Theme.accentInk)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 32)
                                    .background(Theme.accentInk.opacity(0.08), in: Capsule())
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("route-question")
    }

    /// 길을 다 적었거나 못 찾았다 — 한 줄. 다음 글자에 물러난다.
    private func noticeRow(_ notice: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: notice.hasPrefix("가는 길을 적었어요") ? "checkmark.circle" : "exclamationmark.circle")
            Text(notice).lineLimit(2)
            Spacer(minLength: 0)
            Button { pen.planner?.acknowledge() } label: {
                Image(systemName: "xmark").font(.caption2.weight(.semibold)).frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("route-notice")
    }

    // MARK: 되묻기 — 한 가지만 묻고 펜은 답을 기다린다 (quick-capture-assistant D6)

    private func pendingBlock(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = pen.pendingSummary {
                Text(summary).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
            Text(question).font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PenModel.timeChoices, id: \.self) { choice in
                        Button {
                            // 선택지도 답과 같은 길로 — 「시각 없이」는 「없어」와 같은 말.
                            pen.text = choice == "시각 없이" ? "없어" : choice
                            Task { await pen.leave() }
                        } label: {
                            Text(LocalizedStringKey(choice))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.accentInk)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(Theme.accentInk.opacity(0.08), in: Capsule())
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // 유리 위에 앉힌다 — 맨 글로 두면 목록의 줄 위에 겹쳐 읽을 수 없다 (2026-09-16, 사용자가 겹친다고 했다).
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("pending-question")
    }

    // MARK: 칩 — 읽은 것을 누르기 전에 보인다

    @ViewBuilder
    private var chips: some View {
        // 묻거나 시키는 말에는 읽은 칩을 세우지 않는다 — 「금요일 10시에 다시 알려줘」의 날짜는 달력으로 가지 않는다.
        // 무엇이 될지는 단추의 동사와, 끝난 뒤의 결과 줄이 말한다.
        let writing = pen.saying == .writing
        let date = writing ? pen.dateChip : nil
        let place = writing ? pen.placeChip : nil
        let every = writing ? pen.everyChip : nil
        let target = pen.targetTitle
        if date != nil || place != nil || every != nil || hereTrouble != nil || target != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let target { targetChip(target) }
                    if let hereTrouble, pen.here == nil {
                        Text(hereTrouble)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 32)
                            .accessibilityIdentifier("here-trouble")
                    }
                    if let date {
                        chip(date, on: pen.readsDate, hint: String(localized: "누르면 날짜로 읽지 않습니다")) { pen.readsDate.toggle() }
                            .accessibilityIdentifier("chip-date")
                    }
                    if let every {
                        chip(every, on: pen.readsDate && pen.readsEvery, hint: String(localized: "누르면 되풀이로 읽지 않습니다")) {
                            // 날짜가 꺼져 있으면 되풀이도 꺼져 보인다 — 누르면 둘 다 켠다.
                            if !pen.readsDate { pen.readsDate = true; pen.readsEvery = true } else { pen.readsEvery.toggle() }
                        }
                        .accessibilityIdentifier("chip-every")
                    }
                    if let place {
                        chip(place, on: pen.readsPlace || pen.here != nil, hint: String(localized: "누르면 장소로 읽지 않습니다")) {
                            if pen.here != nil { pen.here = nil } else { pen.readsPlace.toggle() }
                        }
                        .accessibilityIdentifier("chip-place")
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// 「열린 메모 · 치과 예약 ×」— 편집 화면의 ✦ 로 들고 온 「이거」가 누구인지 (quick-capture-assistant D10). × 로 놓는다.
    private func targetChip(_ title: String) -> some View {
        Button { pen.target = nil } label: {
            HStack(spacing: 6) {
                Text(String(localized: "열린 메모 · \(title)")).lineLimit(1)
                Image(systemName: "xmark").font(.caption2.weight(.semibold))
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Capsule().fill(Paper.ink.opacity(0.08)))
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "열린 메모 \(title)"))
        .accessibilityHint(String(localized: "누르면 열린 메모를 놓습니다"))
        .accessibilityIdentifier("chip-target")
    }

    /// 켜진 칩은 바탕 + 글, 꺼진 칩은 테두리만 — 눌리게 생겨야 한다.
    private func chip(_ label: String, on: Bool, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(on ? Theme.highlightInk : .secondary)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(RoundedRectangle(cornerRadius: Theme.chipRadius).fill(on ? Theme.highlightWash : .clear))
                .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius).stroke(on ? .clear : Color.secondary.opacity(0.6), lineWidth: 1))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(on ? String(localized: "켜짐") : String(localized: "꺼짐"))
        .accessibilityHint(on ? hint : String(localized: "누르면 다시 읽습니다"))
    }

    // MARK: 펜 줄 — 위치 단추 · 글 칸 · 남기기

    /// 빈 칸의 안내 — 열 때마다 바뀌는 문구, 답을 기다릴 때는 답의 예, 「이거」를 들고 있으면 시키는 말의 예.
    private var placeholder: String {
        switch pen.planner?.step {
        case .askingOrigin: return String(localized: "석촌고분역 · 신천동29 · 지도 링크")
        case .choosing: return String(localized: "버스 · 지하철 · 택시")
        case .searching, .writing: return String(localized: "잠깐만요…")
        default: break
        }
        if pen.pendingQuestion != nil { return String(localized: "12시야") }
        if pen.target != nil { return String(localized: "「내일로 미뤄줘」") }
        return pen.prompt
    }

    private var penRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if fixing {
                ProgressView().frame(width: 44, height: 44)
            } else {
                // 시스템 위치 단추 — 생김새를 바꾸지 않는다. 누르는 순간 한 번 허용.
                LocationButton(.currentLocation, action: onHere)
                    .labelStyle(.iconOnly)
                    .symbolVariant(.fill)
                    .tint(pen.here == nil ? .secondary : Theme.accentInk)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("지금 여기")
                    .accessibilityIdentifier("here")
            }

            HStack(alignment: .bottom, spacing: 4) {
                TextField(placeholder, text: Bindable(pen).text, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($focused)
                    .frame(minHeight: 36)
                    .accessibilityLabel("적기")
                    .accessibilityIdentifier("capture")
                if !pen.text.isEmpty || pen.pendingQuestion != nil || pen.planner?.isActive == true {
                    Button {
                        // 되묻는 중의 ⊗ 는 「시각 없이」— 이미 남기라 한 글이다 (D12). 가는 길을 묻는 중이면 「됐어」.
                        if let draft = pen.takePendingDraft() { Task { await pen.create(draft) } }
                        pen.planner?.dismiss()
                        pen.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("지우기")
                    .accessibilityIdentifier("clear")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

            if pen.assistant?.phase == .thinking {
                // 읽는 동안 — 누르면 그만둔다 (맥의 「esc 그만」).
                Button { pen.cancelReading() } label: {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text(pen.assistant?.task == .webAnswer ? "찾는 중" : "읽는 중") }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 4)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("thinking")
            } else {
                Button(action: { Task { await pen.leave() } }) {
                    Text(pen.leaveLabel)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 4)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .foregroundStyle(Theme.onAccent)
                .disabled(!pen.canLeave)
                .accessibilityIdentifier("leave")
            }
        }
    }
}
