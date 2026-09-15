import LazyMemoAssistant
import LazyMemoCore
import SwiftUI

/// 비서 — 묻기·시키기·오늘. 답에는 누를 수 있는 근거가 붙고, 변경은 말로 보여 준 뒤에만 한다.
public struct AssistantView: View {
    public enum Mode: String, CaseIterable, Identifiable {
        case ask, command
        public var id: String { rawValue }
    }

    let model: AssistantModel
    let selected: ULID?
    let memoTitle: (ULID) -> String?
    let openMemo: (ULID) -> Void

    @State private var mode: Mode
    @State private var text = ""
    @State private var confirmingTrash = false
    @FocusState private var focused: Bool

    public init(model: AssistantModel, selected: ULID? = nil,
                memoTitle: @escaping (ULID) -> String?, openMemo: @escaping (ULID) -> Void) {
        self.model = model
        self.selected = selected
        self.memoTitle = memoTitle
        self.openMemo = openMemo
        _mode = State(initialValue: selected == nil ? .ask : .command)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModelPanel(model: model)
            if model.isReady {
                if let selected, let title = memoTitle(selected) {
                    Label(L("열린 메모: \(title)"), systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                }
                inputRow
                results
                Spacer(minLength: 0)
            }
        }
        .padding()
        .task { await model.refresh() }
        .confirmationDialog(L("정말 휴지통으로 옮길까요?"), isPresented: $confirmingTrash, titleVisibility: .visible) {
            Button(L("휴지통으로"), role: .destructive) { Task { await model.apply(confirmedTrash: true) } }
        }
    }

    private var inputRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $mode) {
                Text(L("묻기")).tag(Mode.ask)
                Text(L("시키기")).tag(Mode.command)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack {
                TextField(mode == .ask ? L("메모에게 물어보세요 — 「치과 언제였지?」") : L("무엇을 할까요 — 「금요일 10시에 다시 알려줘」"), text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(send)
                    .disabled(model.isBusy)
                if model.isBusy {
                    Button(L("그만")) { model.cancel() }
                } else {
                    Button(L("보내기"), action: send).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button { model.brief() } label: { Label(L("오늘"), systemImage: "sun.max") }
                    .disabled(model.isBusy)
                    .help(L("오늘 챙길 것 세 개"))
            }
        }
    }

    private func send() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if mode == .ask { model.ask(query, selected: selected) } else { model.command(query, selected: selected) }
    }

    @ViewBuilder
    private var results: some View {
        switch model.phase {
        case .idle: EmptyView()
        case .thinking:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L("메모를 읽는 중")).foregroundStyle(.secondary) }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
        case .done:
            VStack(alignment: .leading, spacing: 10) {
                if let answer = model.answer { answerBlock(answer) }
                if let items = model.briefItems { briefBlock(items) }
                if let proposal = model.proposal { proposalBlock(proposal) }
                if let receipt = model.receipt { receiptBlock(receipt) }
                if let error = model.applyError { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
    }

    private func answerBlock(_ answer: AssistantAnswer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(answer.found ? answer.text : L("메모에서 찾지 못했습니다")).textSelection(.enabled)
            if !answer.evidence.isEmpty { evidenceChips(answer.evidence) }
        }
    }

    private func evidenceChips(_ ids: [ULID]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("근거")).font(.caption).foregroundStyle(.secondary)
            ForEach(ids, id: \.self) { id in
                Button { openMemo(id) } label: {
                    Label(memoTitle(id) ?? model.evidence.first { $0.memoID == id }.map(ActionWords.title) ?? id.stringValue,
                          systemImage: "doc.text")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private func briefBlock(_ items: [BriefItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(items.isEmpty ? L("오늘은 급한 것이 없습니다") : L("오늘 챙길 것")).font(.subheadline.weight(.semibold))
            ForEach(items, id: \.memoID) { item in
                Button { openMemo(item.memoID) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(memoTitle(item.memoID) ?? item.memoID.stringValue).lineLimit(1)
                        if !item.reason.isEmpty { Text(item.reason).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .buttonStyle(.plain)
            }
            Text(L("메모에서 골랐습니다. 「지금」 띠의 차례는 그대로입니다.")).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func proposalBlock(_ proposal: ProposedAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ActionWords.describe(proposal, memoTitle: proposal.memoID.flatMap(memoTitle)))
            if proposal.kind.writes {
                HStack {
                    Button(L("적용")) {
                        if proposal.kind == .trash { confirmingTrash = true } else { Task { await model.apply() } }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    Button(L("아니요")) { model.dismissProposal() }.controlSize(.small)
                }
            }
        }
    }

    private func receiptBlock(_ receipt: ActionReceipt) -> some View {
        HStack {
            Label(L("적용했습니다"), systemImage: "checkmark").foregroundStyle(.secondary)
            Button(L("되돌리기")) { Task { await model.undo() } }.controlSize(.small)
            Button { openMemo(receipt.after.id) } label: { Label(L("메모 열기"), systemImage: "doc.text") }.controlSize(.small)
        }
    }
}
