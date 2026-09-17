import AppKit
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoPlaces
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let minimumEditorHeight: CGFloat = 30
    private static let maximumEditorHeight: CGFloat = 150
    private static let arrowSize = CGSize(width: 20, height: 9)

    /// 키보드로 고른 메모. **포인터가 얹힌 줄은 여기 오지 않는다** — 아래
    /// 힌트 줄이 말하는 「열기」와 「⌘⌫ 지우기」가 곧 지금 키가 할 일이라,
    /// 손이 스쳤다는 이유로 바뀌면 그 줄은 거짓말이 된다.
    private var selectedMemo: Memo? {
        model.selectedID.flatMap { id in model.listed.first { $0.id == id } }
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
        .animation(reduceMotion ? nil : Theme.reveal, value: model.listed.count)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.selectedID)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.pointed)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.scheduleLabel)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.lastDeleted?.id)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.isExpanded)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.pendingQuestion)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.planner?.step)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.planner?.notice)
        .animation(reduceMotion ? nil : Theme.reveal, value: model.assistant?.phase)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 머리 줄(로고·lazymemo·「잠깐, 메모 한 장」)은 걷어냈다 (2026-09-15, 사용자 요청). 상자는 자기를
            // 드러내지 않는다 — 첫 줄부터 적는 자리다. 닫기 × 만 오른쪽 위에 겹쳐 둔다.
            // 되묻기 — 질문 하나만 남는다 (설계 D6). 초안 요약 · 질문 · 선택지, 그 아래 답을 적는 칸.
            if let question = model.pendingQuestion { pendingBlock(question) }
            // 가는 길 — 「어디서 출발하시나요?」·「무엇으로 갈까요?」. 시각의 되물음과 같은 자리, 같은 모양.
            if let planner = model.planner, planner.isActive { routeBlock(planner) }
            input

            if model.query.isEmpty, !model.isAsking, model.assistant?.phase ?? .idle == .idle { searchShortcuts }

            // 비서의 답·결과 — 목록 위에 선다. 목록은 그 답의 근거·후보로 갈려 있다 (`reflectAssistant`).
            if !model.isAsking, let assistant = model.assistant { assistantBlock(assistant) }
            // 길을 다 적었거나 못 찾았다 — 한 줄로. 다음 말에 지워진다.
            if let notice = model.planner?.notice {
                statusLine(notice, symbol: notice.hasPrefix("가는 길을 적었어요") ? "checkmark.circle" : "exclamationmark.circle")
            }

            if !model.listed.isEmpty, !model.isAsking {
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
        // 비서가 도는 동안 상자의 테두리가 숨 쉰다 — 곁눈으로도 「돌고 있다」 (`ThinkingInk`).
        .thinkingGlow(model.assistant?.phase == .thinking, accent: Theme.accentInk, radius: Theme.panelRadius)
        .overlay(alignment: .topTrailing) { closeButton }
    }

    /// 닫기 — 오른쪽 위에 겹친다. 적던 글은 상자가 기억하므로 누르는 데 망설일 것이 없다.
    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .hitTarget(28)
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.tight)
        .padding(.trailing, Theme.snug)
        .spoken(L("닫기 — 적던 글은 앱을 사용하는 동안 남습니다"))
    }

    private var searchShortcuts: some View {
        HStack(spacing: 8) {
            Text(L("찾기")).foregroundStyle(.secondary)
            searchShortcut(L("사진"), symbol: "photo", query: "#" + MemoShape.photo.label)
            searchShortcut(L("링크"), symbol: "link", query: "#" + MemoShape.link.label)
            searchShortcut(L("할 일"), symbol: "checklist", query: "#" + MemoShape.checklist.label)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, Theme.loose)
        .padding(.bottom, Theme.normal)
    }

    private func searchShortcut(_ title: String, symbol: String, query: String) -> some View {
        Button { model.query = query } label: {
            Label(title, systemImage: symbol)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .spoken(L("\(title) 메모 찾기"))
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
                font: .systemFont(ofSize: 19, weight: .regular),
                insets: NSSize(width: 0, height: 4),
                // 붙인 사진은 아래 조각으로 보인다. 경로 글자까지 19pt 로
                // 늘어놓으면 말풍선이 그것만으로 가득 찬다.
                hidesImageReferences: true,
                onPasteImage: { model.markdown(forPastedImage: $0, fileExtension: $1) },
                onPasteLink: { LinkLabel.markdown(for: $0) },
                // 열 때마다 바뀐다 (`CapturePrompt`). 답을 기다릴 때는 답의 예.
                placeholder: inputPlaceholder,
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

            if !model.filter.chips.isEmpty {
                filterChips(model.filter.chips)
            }

            // 앱이 읽은 것 — 날짜는 달력으로 가고, 자리는 종이에 남는다 (설계 D4). 둘 다 해석한 결과다.
            if model.scheduleLabel != nil || model.place != nil {
                HStack(spacing: Theme.snug) {
                    if let schedule = model.scheduleLabel { scheduleChip(schedule) }
                    if let place = model.place { placeChip(place) }
                }
            }

            if let target = model.target, let memo = targetMemo(target) {
                targetChip(memo)
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.top, Theme.loose)
        .padding(.bottom, Theme.normal)
        // × 가 첫 줄의 끝과 겹치지 않게 오른쪽을 비운다.
        .padding(.trailing, Theme.normal)
    }

    private func targetMemo(_ id: ULID) -> Memo? { model.listed.first { $0.id == id } ?? model.memo(id) }

    /// 「열린 메모 · 치과 예약 ×」— 종이 우클릭으로 열렸을 때 「이거」가 누구인지 (설계 D10).
    private func targetChip(_ memo: Memo) -> some View {
        HStack(spacing: 5) {
            Text(L("열린 메모 · \(memo.title)"))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Button { model.target = nil } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).hitTarget(20)
            }
            .buttonStyle(.plain)
            .spoken(L("열린 메모 놓기"))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.snug)
        .padding(.vertical, 5)
        .background(Capsule().fill(Paper.ink.opacity(0.08)))
        .transition(.opacity)
        .fixedSize()
    }

    /// 자리 칩 — 날짜 칩과 같은 꼴, 잉크만 다르다.
    private func placeChip(_ place: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin").font(.system(size: 9, weight: .semibold))
            Text(place).font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(Theme.accentInk)
        .padding(.horizontal, Theme.snug)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.softAccent))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .fixedSize()
    }

    /// 빈 상자의 안내 — 평소엔 열 때마다 바뀌는 문구, 되물음 중엔 답의 예.
    private var inputPlaceholder: String {
        switch model.planner?.step {
        case .askingOrigin: return L("석촌고분역 · 신천동29 · 지도 링크")
        case .choosing: return L("버스 · 지하철 · 택시")
        case .searching, .writing: return L("잠깐만요…")
        default: return model.pendingQuestion == nil ? model.placeholder : L("12시야")
        }
    }

    // MARK: 가는 길 되묻기 (`RoutePlanner`)

    /// 약속 한 줄 · 질문 · 선택지. 찾는 동안은 질문 자리에 「…찾는 중」과 바퀴.
    private func routeBlock(_ planner: RoutePlanner) -> some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            if let summary = planner.summary {
                Text(summary).font(Theme.micro).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(spacing: Theme.snug) {
                if planner.isBusy { ProgressView().controlSize(.small) }
                Text(planner.question ?? "").font(Theme.body)
            }
            if let trouble = planner.trouble {
                Text(trouble).font(Theme.micro).foregroundStyle(.orange)
            }
            if !planner.choices.isEmpty {
                HStack(spacing: 6) {
                    ForEach(planner.choices, id: \.self) { choice in
                        Button { planner.choose(choice) } label: {
                            Text(L(String.LocalizationValue(choice)))
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(Theme.softAccent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.top, Theme.normal)
        .transition(.opacity)
        .accessibilityIdentifier("route-question")
    }

    // MARK: 되묻기 (설계 D6)

    /// 초안 요약 한 줄 · 질문 한 줄 · 고를 수 있는 칩. 글자를 안 쳐도 되게.
    private func pendingBlock(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            if let summary = model.pendingSummary {
                Text(summary).font(Theme.micro).foregroundStyle(.secondary).lineLimit(2)
            }
            Text(question).font(Theme.body)
            HStack(spacing: 6) {
                ForEach(QuickCaptureModel.timeChoices, id: \.self) { choice in
                    Button {
                        // 선택지도 답과 같은 길로 간다 — 「시각 없이」는 「없어」와 같은 말.
                        model.query = choice == "시각 없이" ? "없어" : choice
                        onCommit()
                    } label: {
                        Text(L(String.LocalizationValue(choice)))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Theme.softAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.top, Theme.normal)
        .transition(.opacity)
    }

    // MARK: 비서 — 답·결과·되물음 (설계 D8·D9·D10·D11)

    @ViewBuilder
    private func assistantBlock(_ assistant: AssistantModel) -> some View {
        switch assistant.phase {
        case .idle, .thinking:
            EmptyView()
        case .failed(let message):
            if assistant.offersWeb != nil {
                // 메모에 없다 — 웹을 권한다. 누르기(또는 빈 상자의 ⌘↵) 전엔 아무것도 밖으로 나가지 않는다.
                webOfferLine(assistant)
            } else if !assistant.isReady, assistant.task != .webAnswer {
                modelLine(assistant)
            } else {
                statusLine(message, symbol: "exclamationmark.circle")
            }
        case .done:
            VStack(alignment: .leading, spacing: 0) {
                if let answer = assistant.answer { answerLines(answer) }
                if let proposal = assistant.proposal {
                    if proposal.kind == .ask { statusLine(ActionWords.describe(proposal, memoTitle: nil), symbol: "questionmark.circle") }
                    else if proposal.kind == .trash { trashLine(proposal, assistant) }
                }
                if let applied = assistant.applied { resultLine(applied, assistant) }
                if let error = assistant.applyError { statusLine(error, symbol: "exclamationmark.circle") }
            }
        }
    }

    @ViewBuilder
    private func answerLines(_ answer: AssistantAnswer) -> some View {
        if answer.isWeb, let assistant = model.assistant {
            webAnswer(answer, assistant)
        } else {
            VStack(alignment: .leading, spacing: Theme.tight) {
                Text(answer.found ? ActionWords.soft(answer.text) : L("메모에서 찾지 못했습니다"))
                    .font(Theme.body)
                    .textSelection(.enabled)
                ForEach(answer.quotes, id: \.self) { line in
                    Text(line)
                        .font(Theme.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.leading, Theme.snug)
                        .overlay(alignment: .leading) { Rectangle().frame(width: 2).foregroundStyle(.tertiary) }
                }
            }
            .padding(.horizontal, Theme.loose)
            .padding(.vertical, Theme.snug)
            .transition(.opacity)
        }
    }

    // MARK: 웹의 답 — 물음 · 답 · 결과 전부 · 다음 손짓

    /// 웹의 답은 카드다 — 무엇을 찾았는지 한 줄, 답 한 문장, 그 밑에 **결과 전부**가 한 칸씩.
    ///
    /// 앞선 판은 인용한 한두 줄을 작은 글자로 세웠다. 다섯 결과 중 모델이 하나를 골라 주면 나머지는
    /// 있었는지도 몰랐고, 발췌는 두 줄에서 잘렸다 — 「검색 결과가 제대로 안 보인다」(2026-09-17).
    /// 답이 인용한 것이 앞에 서고 표가 난다(`cited`). 끝에 **이걸 어떻게 할까요?** — 검색한 사람의
    /// 다음 손은 대개 남기기·정리·붙이기다 (`WebFollowUp`).
    private func webAnswer(_ answer: AssistantAnswer, _ assistant: AssistantModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            HStack(spacing: Theme.tight) {
                Image(systemName: "globe").font(.system(size: 10, weight: .semibold))
                Text(L("웹에서 찾음"))
                if let question = assistant.webQuestion {
                    Text("·")
                    Text(WebQuery.make(from: question)).lineLimit(1)
                }
            }
            .font(Theme.micro)
            .foregroundStyle(.tertiary)

            // 답 문장. 모델 없이 결과만 왔거나 앱이 대신 세운 머리글이면 작게.
            let headline = answer.text.isEmpty ? L("웹에서 찾은 것") : ActionWords.soft(answer.text)
            Text(headline)
                .font(answer.text.isEmpty || answer.text.hasPrefix("검색 결과에서") ? Theme.title : Theme.body)
                .foregroundStyle(answer.text.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            let results = assistant.webResults
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    webResultRow(result)
                    if index < results.count - 1 { Divider().opacity(0.35).padding(.horizontal, Theme.snug) }
                }
            }
            .background(Paper.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).strokeBorder(Paper.ink.opacity(0.08)))
            .accessibilityIdentifier("web-results")

            if !assistant.followUps.isEmpty { followUpRow(assistant) }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.snug)
        .transition(.opacity)
    }

    /// 결과 한 칸 — 제목 · 출처, 발췌 세 줄. 칸 전체가 단추이고 누르면 브라우저로.
    private func webResultRow(_ result: AssistantModel.WebResult) -> some View {
        Button { NSWorkspace.shared.open(result.url) } label: {
            HStack(alignment: .top, spacing: Theme.snug) {
                // 인용한 결과는 점이 찍힌다 — 답이 어디서 왔는지.
                Circle()
                    .fill(result.cited ? Theme.accentInk : Paper.ink.opacity(0.18))
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.tight) {
                        Text(result.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accentInk)
                            .lineLimit(1)
                        Text(result.host)
                            .font(Theme.micro)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                    if !result.snippet.isEmpty {
                        Text(result.snippet)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
            }
            .padding(.horizontal, Theme.snug)
            .padding(.vertical, Theme.tight + 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .spoken(L("\(result.title) — 브라우저에서 엽니다"))
    }

    /// 「이걸 어떻게 할까요?」— 남기기 · 정리해서 남기기 · 붙이기. 글자로 해도 같다 (「메모해」「치과 메모에 추가해줘」).
    private func followUpRow(_ assistant: AssistantModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            Text(L(String.LocalizationValue(WebFollowUp.question)))
                .font(Theme.micro)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(assistant.followUps, id: \.self) { choice in
                    Button { assistant.followUp(choice) } label: {
                        Label(Self.followUpLabel(choice), systemImage: Self.followUpSymbol(choice))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Theme.softAccent, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentInk)
                    .accessibilityIdentifier("follow-up-\(Self.followUpID(choice))")
                }
            }
        }
        .padding(.top, 2)
    }

    static func followUpLabel(_ choice: WebFollowUp) -> String {
        switch choice {
        case .keep: return L("메모로 남기기")
        case .tidy: return L("정리해서 남기기")
        case .append(let hint): return hint.map { L("「\($0)」에 붙이기") } ?? L("기존 메모에 붙이기")
        }
    }

    private static func followUpSymbol(_ choice: WebFollowUp) -> String {
        switch choice {
        case .keep: return "square.and.pencil"
        case .tidy: return "wand.and.stars"
        case .append: return "text.append"
        }
    }

    private static func followUpID(_ choice: WebFollowUp) -> String {
        switch choice {
        case .keep: return "keep"
        case .tidy: return "tidy"
        case .append: return "append"
        }
    }

    /// 「메모에서 찾지 못했습니다 · 웹에서 찾기 ⌘↵」— 같은 물음을 웹에. 이때만 질문 낱말이 밖으로 나간다.
    private func webOfferLine(_ assistant: AssistantModel) -> some View {
        HStack(spacing: Theme.tight) {
            Label(L("메모에서 찾지 못했습니다"), systemImage: "magnifyingglass").lineLimit(2)
            Spacer(minLength: Theme.snug)
            Button { assistant.searchWebForLastQuestion() } label: {
                Text(L("웹에서 찾기"))
                    .foregroundStyle(Theme.accentInk)
                    .padding(.horizontal, Theme.tight)
                    .frame(minHeight: Theme.touchRow)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .spoken(L("웹에서 찾기 — 이 물음을 DuckDuckGo 에 검색합니다"))
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
        .transition(.opacity)
    }

    /// 「「치과 예약」 9월 18일 (금) 10:00 에 다시 보여 줍니다 · 되돌리기」— 지운 줄과 같은 자리·같은 낱말 (D6).
    /// 줄 하나에 들어갈 만큼의 제목 — 긴 첫 줄은 앞만 남긴다.
    private func shortTitle(_ id: ULID) -> String? {
        guard let title = model.memo(id)?.title else { return nil }
        return title.count > 14 ? String(title.prefix(13)) + "…" : title
    }

    private func resultLine(_ applied: ProposedAction, _ assistant: AssistantModel) -> some View {
        HStack(alignment: .top, spacing: Theme.tight) {
            Text(ActionWords.describe(applied, memoTitle: applied.memoID.flatMap(shortTitle)))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.snug)
            Button { Task { await assistant.undo() } } label: {
                Text(L("되돌리기"))
                    .foregroundStyle(Theme.accentInk)
                    .padding(.horizontal, Theme.tight)
                    .frame(minHeight: Theme.touchRow)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .spoken(L("되돌리기 — 방금 바꾼 것을 되돌립니다"))
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
        .transition(.opacity)
    }

    /// 휴지통만 되묻는다 (설계 D8).
    private func trashLine(_ proposal: ProposedAction, _ assistant: AssistantModel) -> some View {
        HStack(spacing: Theme.tight) {
            Text(ActionWords.describe(proposal, memoTitle: proposal.memoID.flatMap(shortTitle))).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.snug)
            Button { Task { await assistant.apply(confirmedTrash: true) } } label: {
                Text(L("휴지통으로")).foregroundStyle(Theme.dangerInk).padding(.horizontal, Theme.tight)
                    .frame(minHeight: Theme.touchRow).contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button { assistant.dismissProposal() } label: {
                Text(L("아니요")).padding(.horizontal, Theme.tight).frame(minHeight: Theme.touchRow).contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
    }

    /// 「모델을 받으면 답합니다 · 받기 2.6GB」— 묻기만 막힌다. 받는 동안은 진행 막대 (설계 D11).
    private func modelLine(_ assistant: AssistantModel) -> some View {
        HStack(spacing: Theme.tight) {
            if let download = assistant.download {
                ProgressView(value: download.fraction).controlSize(.small)
                Text(download.verifying ? L("확인 중") : L("받는 중 \(Int(download.fraction * 100))%"))
                Button(L("취소")) { assistant.cancelDownload() }.buttonStyle(.plain).foregroundStyle(Theme.accentInk)
            } else {
                Text(L("모델을 받으면 답합니다")).lineLimit(1)
                if let error = assistant.downloadError { Text(error).foregroundStyle(Theme.dangerInk).lineLimit(1) }
                Spacer(minLength: Theme.snug)
                Button { assistant.startDownload() } label: {
                    Text(L("받기 \(ByteCountFormatter.string(fromByteCount: assistant.manifest.file.bytes, countStyle: .file))"))
                        .foregroundStyle(Theme.accentInk)
                        .padding(.horizontal, Theme.tight)
                        .frame(minHeight: Theme.touchRow)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .font(Theme.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
    }

    private func statusLine(_ text: String, symbol: String) -> some View {
        Label(ActionWords.soft(text), systemImage: symbol)
            .font(Theme.micro)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(.horizontal, Theme.loose)
            .padding(.vertical, Theme.tight)
            .transition(.opacity)
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
    /// 무엇으로 걸렀는지 (`MemoFilter`).
    ///
    /// **가려진 것은 가려진 줄도 모른다.** 목록이 짧아진 이유가 화면에 없으면
    /// 사람은 그것을 «메모가 사라졌다» 로 읽는다 — 「… 외 N장 더」를 세어
    /// 적는 것과 같은 이유로 여기서도 적는다.
    private func filterChips(_ chips: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, Theme.snug)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Paper.ink.opacity(0.08)))
            }
            Text(L("만 보입니다"))
                .font(.system(size: 10))
                .opacity(0.55)
        }
        .foregroundStyle(.secondary)
        .transition(.opacity)
        .fixedSize()
    }

    private func scheduleChip(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
            Text(L("달력으로"))
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

    /// 놓인 메모들. 누르면 열리고, 포인터가 얹히면 그 줄이 살짝 떠오른다.
    ///
    /// **손이 얹힌 것과 키보드로 고른 것을 갈라 놓는다.** 예전에는 스치기만
    /// 해도 그것이 곧 선택이어서, 세 줄 적다가 마우스가 목록을 한 번
    /// 지나가면 ⌘⏎ 가 「적기 끝」에서 「남의 메모 열기」로 바뀌었다 — 적던
    /// 글은 저장되지 않은 채. 손은 **무엇을 누를 수 있는지**만 비추고,
    /// 키가 무엇을 할지는 화살표와 클릭만 정한다.
    private var results: some View {
        Group {
            if model.isExpanded {
                ScrollViewReader { reader in
                    ScrollView { resultRows }
                        .frame(height: 300)
                        .onChange(of: model.selectedID) { _, id in
                            if let id { reader.scrollTo(id, anchor: .center) }
                        }
                        .onAppear {
                            if let id = model.selectedID { reader.scrollTo(id, anchor: .center) }
                        }
                }
            } else {
                resultRows
            }
        }
    }

    private var resultRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text(listingTitle)
                Spacer()
                if model.listing != .candidates { Text(L("\(model.pool.count)장")).monospacedDigit() }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.loose)
            .padding(.vertical, Theme.snug)

            ForEach(Array(model.listed.enumerated()), id: \.element.id) { index, memo in
                row(
                    memo, index: index,
                    isSelected: model.selectedID == memo.id,
                    isPointed: pointedID == memo.id
                )
                .id(memo.id)
                .onHover { inside in
                    if inside { model.pointed = memo.id }
                    else if model.pointed == memo.id { model.pointed = nil }
                }
            }

            if let overflow = model.overflow { overflowLine(overflow) }
        }
        .padding(.vertical, Theme.tight)
    }

    /// 목록의 마지막 줄 — **끊긴 자리에 끊겼다고 적는다.**
    ///
    /// 다섯 줄에서 그냥 잘려 있으면 사람은 그것을 "이게 전부" 로 읽는다.
    /// 그래서 아홉 번째 메모는 있는 줄도 모르는 채 다시 적히고, 스무 장이
    /// 넘어가면 이 앱은 조용히 반쯤만 있는 앱이 된다.
    ///
    /// 넓히는 손짓이 둘이다 — 이 줄을 누르거나, 마지막 줄에서 ↓ 를 한 번 더.
    /// 손이 어디에 있든 이미 하던 동작이 그대로 이어진다.
    @ViewBuilder
    private func overflowLine(_ overflow: QuickCaptureModel.Overflow) -> some View {
        switch overflow {
        case .more(let count):
            Button { model.expand() } label: {
                HStack(spacing: Theme.tight) {
                    Text(L("… 외 \(count)장 더"))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .font(Theme.micro)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.loose)
                .padding(.vertical, Theme.tight)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .spoken(L("외 \(count)장 더 — 눌러서 목록을 넓힙니다"))

        case .tooMany(let count):
            // 넓힐 만큼 넓혔다. 여기서 더 늘리는 것은 답이 아니라서
            // **길을 바꿔 말한다** — 스무 줄을 훑는 것보다 한 글자 더 치는 편이 짧다.
            Text(L("… \(count)장 더 있습니다 — 낱말을 더 적으면 좁혀집니다"))
                .font(Theme.micro)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.horizontal, Theme.loose)
                .padding(.vertical, Theme.tight)
        }
    }

    /// 목록의 이름 — 무엇이 놓여 있는지 (설계 D9·D10).
    private var listingTitle: String {
        switch model.listing {
        case .recent: return L("최근 메모")
        case .found: return L("검색 결과")
        case .evidence: return L("근거")
        case .related: return L("관련 메모")
        case .candidates: return L("어느 메모? ↓ 로 고르고 ⌘↵")
        }
    }

    /// 지금 포인터가 얹힌 줄. 화면 밖 렌더에서는 연출값이 대신한다 (§14.9).
    private var pointedID: ULID? {
        guard let stagedTrashRow else { return model.pointed }
        return model.listed[safe: stagedTrashRow]?.id
    }

    /// 한 줄에 셋 — 종이 색 점, 제목, 시간 한 조각.
    ///
    /// 메뉴 목록과 **같은 낱말을 쓴다** (§14.10). 두 곳에서 같은 메모를 다르게
    /// 그리면 사람은 그것을 두 개의 목록으로 배운다. 찬 점은 바탕화면에 나와
    /// 있는 종이, 빈 점은 치워 둔 것 — 누르기 전에 "새로 뜬다" 인지 "앞으로
    /// 나온다" 인지 알 수 있다.
    private func row(_ memo: Memo, index: Int, isSelected: Bool, isPointed: Bool) -> some View {
        HStack(spacing: Theme.snug) {
            // 여는 자리와 지우는 자리를 **한 뷰에 겹치지 않는다.** 겹치면
            // 누르기 하나를 놓고 둘이 다투고, 어느 쪽이 이기는지가 상황마다
            // 달라진다 (달력에서 「미루기」를 끌기 밖에 둔 것과 같은 이유).
            Button {
                model.selection = index
                onCommit()
            } label: {
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
              .frame(minHeight: 28)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(memo.title), \(MemoTimeLabel.text(for: memo))"))
            .accessibilityHint(Text(L("열기")))

            RowTrash(isLit: isSelected || isPointed, staged: stagedTrashRow == index) {
                Task { await model.delete(memo) }
            }
        }
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.tight)
        // 두 상태를 **다른 세기로** 그린다. 같은 자국으로 그리면 손이 스친 줄이
        // 골라진 줄처럼 보이고, 그러면 화면이 ⌘⏎ 에 대해 거짓말을 한다.
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(memo.color.tint.opacity(0.20))
                    .padding(.horizontal, Theme.snug)
            } else if isPointed {
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Paper.ink.opacity(0.05))
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
            Text(L("「\(memo.title)」 지웠습니다"))
                .lineLimit(1)
            Spacer(minLength: Theme.snug)
            Button {
                Task { await model.restoreLastDeleted() }
            } label: {
                // 급하게 찾는 손이 오는 자리다 — 지운 직후가 잘못 눌렀다는
                // 것을 아는 순간이므로. 낱말은 그대로 두고 둘레를 넓힌다.
                Text(L("되돌리기"))
                    .foregroundStyle(Theme.accentInk)
                    .padding(.horizontal, Theme.tight)
                    .frame(minHeight: Theme.touchRow)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .spoken(L("되돌리기 — 방금 지운 메모를 되살립니다"))
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
        HStack(spacing: Theme.snug) {
            Text(hintText)
                .font(.system(size: 11))
            Spacer(minLength: 0)
            if let assistant = model.assistant, assistant.phase == .thinking {
                // 읽는 동안 라벨은 없다 — 누를 것이 없다 (설계 E-1). 대신 획과 단계의 말 — 무엇을 기다리는지.
                ThinkingInk(
                    label: assistant.stageLabel, tokens: assistant.stage?.tokens ?? 0,
                    style: ThinkingInkStyle(ink: Paper.ink, faded: Paper.fadedInk, accent: Theme.accentInk), size: 11
                )
            } else if let commandLabel {
                Button(action: onCommit) {
                    HStack(spacing: 12) {
                        Text(commandLabel)
                        Text("⌘↵").opacity(0.75)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .spoken("\(commandLabel) — Command Return")
            } else {
                Text(L("적으면 메모, 찾으면 검색, 물으면 답"))
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.loose)
        .padding(.vertical, Theme.normal)
    }

    private var hintText: String {
        if model.assistant?.phase == .thinking { return L("esc 그만") }
        if model.planner?.isActive == true { return L("↵ 답하기 · esc 길은 그만") }
        if model.pendingQuestion != nil { return L("↵ 줄바꿈 · esc 시각 없이 남기기") }
        if model.listing == .candidates { return L("↑↓ 고르기 · esc 닫기") }
        return selectedMemo == nil ? L("↵ 줄바꿈 · esc 닫기") : L("↑↓ 선택 · ⌘⌫ 지우기")
    }

    /// 단추에 들어갈 만큼의 제목.
    private static func clip(_ title: String) -> String { title.count > 12 ? String(title.prefix(11)) + "…" : title }

    /// 지금 ⌘⏎ 가 할 일 — 라벨이 곧 동사다 (설계 D5). 없으면 `nil`.
    private var commandLabel: String? {
        switch model.intent {
        case .nothing: return nil
        case .open: return L("메모 열기")
        case .applyTo(let title): return L("「\(Self.clip(title))」에 적용")
        case .pick(let title):
            return model.assistant?.isChoosingWhereToAppend == true ? L("「\(Self.clip(title))」에 붙이기") : L("「\(Self.clip(title))」에게")
        case .followUp(let follow): return Self.followUpLabel(follow)
        case .command: return L("시키기")
        case .ask: return L("메모에게 묻기")
        case .web: return L("웹에서 찾기")
        case .answer: return L("답하기")
        case .memo: return L("메모 남기기")
        case .calendar: return L("달력에 남기기")
        }
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
            // 읽는 중이면 그만둔다 — 상자는 남는다 (설계 E-1 「esc 그만」).
            if model.assistant?.phase == .thinking { model.assistant?.cancel(); return true }
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
