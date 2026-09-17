import Foundation
import LazyMemoAssistant
import LazyMemoCore
import LazyMemoLocalLiteRT
import Observation

/// 비서 화면이 손에 쥐는 상태 전부. **MainActor 는 화면 상태만** — 모델 로딩·추론은 provider actor 안에서 돈다.
@MainActor
@Observable
public final class AssistantModel {
    public enum Phase: Equatable {
        case idle
        case thinking
        case done
        case failed(String)
    }

    public struct DownloadState: Equatable {
        public var received: Int64
        public var total: Int64
        public var verifying = false
        public var fraction: Double { total > 0 ? Double(received) / Double(total) : 0 }
    }

    public let manifest: ModelManifest
    public private(set) var availability: ModelAvailability = .notDownloaded
    public private(set) var download: DownloadState?
    public private(set) var downloadError: String?

    /// 생각하는 동안의 단계 — 화면이 「무엇을 기다리는지」를 말하고, 획이 실제 진행에 맞춰 움직이게 하는 근거.
    ///
    /// 2026-09-17 사용자: 「찾아줘 하고 기다리는데 아무것도 안 뜨다가 갑자기 팍 하고 뜬다」. 바퀴 하나로는 기다림이
    /// 비어 있다. 단계는 전부 **실제 사건**이다 — 뒤지기(검색)·고르기(근거 도착)·깨우기(모델 로딩)·적기(글자 조각) —
    /// 지어낸 진행률은 없다 (HIG Feedback: 「status 를 분명히, 진행을 보이게」).
    public enum Stage: Equatable {
        /// 메모(또는 웹)를 뒤지는 중.
        case searching
        /// 근거 N 을 골랐다 — 모델 없이 끝나는 길이면 여기서 답이 선다.
        case found(Int)
        /// 모델을 올리는 중 — 콜드 스타트는 몇 초.
        case waking(found: Int)
        /// 글자가 오고 있다. `tokens` 는 조각 수 — 획이 그만큼 나아간다.
        case writing(found: Int, tokens: Int)

        /// 지금까지 온 글자 조각 수. 화면의 획이 이것으로 움직인다.
        public var tokens: Int {
            if case .writing(_, let tokens) = self { return tokens }
            return 0
        }
    }

    public private(set) var phase: Phase = .idle
    /// 생각하는 동안의 단계. `thinking` 이 아니면 nil.
    public private(set) var stage: Stage?
    /// 지금 도는(또는 방금 끝난) 일 — 「메모를 읽는 중」과 「웹에서 찾는 중」을 가른다.
    public private(set) var task: AssistantTask?
    public private(set) var answer: AssistantAnswer?
    public private(set) var evidence: [Evidence] = []
    public private(set) var proposal: ProposedAction?
    public private(set) var receipt: ActionReceipt?
    public private(set) var briefItems: [BriefItem]?
    public private(set) var applyError: String?

    private let service: MemoService
    private let store: ModelStore
    private let provider: LiteRTProvider
    private let coordinator: AssistantCoordinator
    private let executor: ActionExecutor
    private let profile: ModelProfile
    private var current: (id: AssistantRequest.ID, task: Task<Void, Never>)?
    private var downloadTask: Task<Void, Never>?
    /// 마지막 시키기 — 「어느 메모?」에 후보를 고르면 같은 말을 그 메모에게 다시 한다.
    private var lastCommand: String?
    /// 되물음 뒤에 기다리는 새 메모 — 「약속 시간이 언제인가요?」의 답을 이것에 잇는다.
    private var pendingDraft: FieldPatch?
    /// 방금 적용한 것 — 되돌리기 줄이 무엇을 했는지 말한다.
    public private(set) var applied: ProposedAction?
    /// 메모에서 못 찾은 물음 — 화면이 「웹에서 찾기」를 권하고, 누르면 같은 말을 웹에 한다. 새 말을 하면 잊는다.
    public private(set) var offersWeb: String?
    /// 웹의 답이 답한 물음 — 답 카드의 머리글과, 남길 메모의 제목·꼬리가 이것을 든다.
    public private(set) var webQuestion: String?
    /// 붙일 메모를 고르는 중인 글 — 「어느 메모에 붙일까요?」의 답(`pick`)이 이것을 그 메모 끝에 단다.
    private var pendingAppend: String?
    /// 답·제안·적용·실패가 정해질 때마다 부른다 — 빠른 입력 상자가 목록을 근거·후보로 갈아 끼우는 고리.
    public var onSettled: (() -> Void)?

    public init(service: MemoService, support: URL, manifest: ModelManifest = .gemma4E2B, profile: ModelProfile? = nil) {
        self.service = service
        self.manifest = manifest
        self.profile = profile ?? ModelProfile(profileID: manifest.profileID, contextTokens: manifest.contextTokens)
        store = ModelStore(support: support)
        provider = LiteRTProvider(store: store, manifest: manifest)
        coordinator = AssistantCoordinator(provider: provider, evidence: MemoServiceEvidenceSource(service: service),
                                           web: DuckDuckGoSearcher(), profile: self.profile)
        executor = ActionExecutor(service: service)
    }

    public var isReady: Bool { availability == .ready }
    public var isBusy: Bool { phase == .thinking }

    public func refresh() async {
        availability = await store.availability(manifest)
    }

    // MARK: 모델 받기·지우기

    public func startDownload() {
        guard downloadTask == nil else { return }
        downloadError = nil
        download = DownloadState(received: 0, total: manifest.file.bytes)
        let downloader = ModelDownloader(store: store)
        downloadTask = Task { [weak self] in
            guard let self else { return }
            download = DownloadState(received: await store.stagedBytes(manifest), total: manifest.file.bytes)
            for await event in downloader.download(manifest) {
                switch event {
                case .progress(let received, let total): download = DownloadState(received: received, total: total)
                case .verifying: download?.verifying = true
                case .ready: break
                case .failed(let message): downloadError = message
                }
            }
            download = nil
            downloadTask = nil
            await refresh()
        }
    }

    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        download = nil
    }

    public func deleteModel() async {
        cancel()
        await provider.unload()
        try? await store.delete(manifest)
        await refresh()
    }

    // MARK: 묻기·시키기·브리핑

    /// 한 줄을 받아 묻는 말이면 답하고 시키는 말이면 제안한다 — 사람이 모드를 고르지 않는다.
    public func send(_ text: String, selected: ULID? = nil) {
        // 되물음의 답이면 초안을 완성해 바로 적는다 — 「12시야」.
        if let draft = pendingDraft, let action = AssistantIntent.complete(draft: draft, reply: text) {
            pendingDraft = nil
            accept(action)
            return
        }
        pendingDraft = nil
        // 웹의 답이 서 있으면 「메모해」「정리해줘」「치과 메모에 추가해줘」는 그 답에 대한 말이다 (`WebFollowUp`).
        if answer?.isWeb == true, let follow = WebFollowUp.read(text) {
            followUp(follow)
            return
        }
        switch AssistantIntent.classify(text) {
        case .command: command(text, selected: selected)
        case .webAnswer: askWeb(text)
        default: ask(text, selected: selected)
        }
    }

    // MARK: 웹의 답 뒤 — 남기기·정리해서 남기기·붙이기 (`WebFollowUp`)

    /// 웹 검색 결과 한 줄 — 화면이 목록으로 그린다. 답이 인용한 것이 앞이고 `cited` 로 표가 난다.
    public struct WebResult: Identifiable, Equatable, Sendable {
        public let id: ULID
        public let title: String
        public let url: URL
        public let snippet: String
        public let cited: Bool
        /// 「weather.go.kr」— 제목 옆에 서는 출처.
        public var host: String { (url.host() ?? url.absoluteString).replacingOccurrences(of: "www.", with: "") }
    }

    /// 웹 검색이 가져온 결과 전부 — 답이 인용한 것이 앞, 나머지가 뒤. 답이 웹의 것이 아니면 빈 배열.
    ///
    /// 앞선 판은 인용한 한두 줄만 그렸다. 모델이 다섯 줄 중 하나를 골라 주면 나머지 넷은 있었는지도
    /// 몰랐다 — 「검색 결과가 제대로 안 보인다」(2026-09-17, 사용자). 검색한 사람은 결과를 봐야 한다.
    public var webResults: [WebResult] {
        guard let answer, answer.isWeb else { return [] }
        let cited = answer.evidence
        let hits = evidence.filter(\.isWeb)
        guard !hits.isEmpty else {
            // 근거 목록이 없는 자리(렌더·시험)는 답이 든 출처로 — 전부 인용한 것이다.
            return zip(answer.sources, answer.quotes).map { WebResult(id: $0.id, title: $0.title, url: $0.url, snippet: $1, cited: true) }
        }
        let first = hits.filter { cited.contains($0.memoID) }
            .sorted { (cited.firstIndex(of: $0.memoID) ?? 0) < (cited.firstIndex(of: $1.memoID) ?? 0) }
        let rest = hits.filter { !cited.contains($0.memoID) }
        return (first + rest).compactMap { e in
            guard let url = e.url else { return nil }
            return WebResult(id: e.memoID, title: e.title ?? url.host() ?? url.absoluteString, url: url, snippet: e.excerpt, cited: cited.contains(e.memoID))
        }
    }

    /// 답 밑에 되물을 다음 손짓 — 웹의 답이 서 있고 아직 아무것도 안 했을 때만. 정리는 모델이 있어야 한다.
    public var followUps: [WebFollowUp] {
        guard let answer, answer.isWeb, phase == .done, applied == nil, proposal == nil, pendingAppend == nil else { return [] }
        return [.keep] + (isReady ? [.tidy] : []) + [.append(hint: nil)]
    }

    /// 붙일 메모를 고르는 중인가 — 「어느 메모?」의 줄을 누르면 시키는 말 대신 답을 붙인다.
    public var isChoosingWhereToAppend: Bool { pendingAppend != nil }

    /// 웹의 답을 어떻게 할지 — 칩을 누르거나 말로 하거나 같은 곳.
    public func followUp(_ choice: WebFollowUp) {
        guard let answer, answer.isWeb else { return }
        let question = webQuestion ?? ""
        let results = evidence.filter(\.isWeb)
        let footer = L("「\(WebQuery.make(from: question))」 웹에서 찾음 · \(Date().formatted(.dateTime.month().day()))")
        switch choice {
        case .keep:
            let body = WebFollowUp.body(question: question, answer: answer, results: results, footer: footer)
            settle(ProposedAction(requestID: UUID(), kind: .createMemo, patch: FieldPatch(body: body)))
        case .tidy:
            guard isReady else { followUp(.keep); return }
            tidyAndKeep(question: question, answer: answer, results: results, footer: footer)
        case .append(let hint):
            let block = WebFollowUp.body(question: question, answer: answer, results: results, footer: footer)
            pendingAppend = block
            Task { await chooseWhereToAppend(hint: hint) }
        }
    }

    /// 「어느 메모에 붙일까요?」의 답 — 그 메모 끝에 단다. 되돌리기는 다른 변경과 같다.
    public func appendWebAnswer(to id: ULID) {
        guard let block = pendingAppend else { return }
        pendingAppend = nil
        Task {
            let memo = try? await service.get(id)
            settle(ProposedAction(requestID: UUID(), kind: .appendToMemo, memoID: id, expectedContentHash: memo?.contentHash,
                                  patch: FieldPatch(body: block)))
        }
    }

    /// 이름을 말했으면 그 메모를 찾는다 — 하나면 바로, 여럿이면 고르게, 없으면 요즘 메모 중에서.
    private func chooseWhereToAppend(hint: String?) async {
        let source = MemoServiceEvidenceSource(service: service)
        var found: [Memo] = []
        if let hint, !hint.isEmpty { found = (try? await source.search(hint, limit: 8)) ?? [] }
        guard pendingAppend != nil else { return }
        if found.count == 1, let only = found.first {
            appendWebAnswer(to: only.id)
            return
        }
        if found.isEmpty {
            let all = (try? await service.all()) ?? []
            found = Array(all.filter(Recall.eligible).sorted { $0.updated > $1.updated }.prefix(20))
        }
        cancel()
        answer = nil; evidence = []; receipt = nil; applyError = nil; applied = nil
        proposal = ProposedAction(requestID: UUID(), kind: .ask, question: WebFollowUp.whichMemo, candidates: found.map(\.id))
        phase = .done
        onSettled?()
    }

    /// 모델이 답과 발췌를 다듬고, 앱이 출처와 꼬리를 도로 단다. 다듬는 동안은 「읽는 중」이다.
    private func tidyAndKeep(question: String, answer: AssistantAnswer, results: [Evidence], footer: String) {
        cancel()
        let request = AssistantRequest(task: .tidy, userText: WebFollowUp.draftForTidy(question: question, answer: answer, results: results))
        task = .tidy
        phase = .thinking
        stage = .searching
        proposal = nil; receipt = nil; applyError = nil; applied = nil
        let job = Task { [weak self] in
            guard let self else { return }
            let tidied = try? await runTidy(request)
            guard !Task.isCancelled else { return }
            current = nil
            let body = tidied.map { WebFollowUp.attachSources(to: $0, answer: answer, results: results, footer: footer) }
                ?? WebFollowUp.body(question: question, answer: answer, results: results, footer: footer)
            settle(ProposedAction(requestID: UUID(), kind: .createMemo, patch: FieldPatch(body: body)))
        }
        current = (request.id, job)
    }

    /// 정해진 것을 바로 적용한다 — 답은 그대로 두고 밑에 결과 줄이 선다.
    private func settle(_ action: ProposedAction) {
        proposal = action
        receipt = nil; applyError = nil; applied = nil
        phase = .done
        Task { await apply() }
    }

    /// 모델·검색 없이 정해진 것을 바로 적용한다.
    private func accept(_ action: ProposedAction) {
        cancel()
        answer = nil; evidence = []; receipt = nil; applyError = nil; applied = nil
        proposal = action
        phase = .done
        Task { await apply() }
    }

    /// 휴지통만 확인을 거친다. 나머지는 적고 되돌리기를 든다 — 이 앱에 저장 버튼이 없는 것과 같은 이유(명세 §5).
    static func appliesImmediately(_ action: ProposedAction) -> Bool {
        action.kind.writes && action.kind != .trash
    }

    public func ask(_ text: String, selected: ULID? = nil) {
        run(AssistantRequest(task: .answer, userText: text, selectedMemoID: selected))
    }

    public func command(_ text: String, selected: ULID? = nil) {
        lastCommand = text
        run(AssistantRequest(task: .command, userText: text, selectedMemoID: selected))
    }

    /// 웹에서 찾는다 — 검색은 앱이 하고 모델은 결과 다섯 줄을 읽는다. 질문 낱말이 밖으로 나가는 유일한 길.
    public func askWeb(_ text: String) {
        run(AssistantRequest(task: .webAnswer, userText: text))
    }

    /// 메모에서 못 찾은 그 물음을 웹에 — 「웹에서 찾기」 단추·빈 상자의 ⌘↵.
    public func searchWebForLastQuestion() {
        guard let question = offersWeb else { return }
        askWeb(question)
    }

    /// 되물음의 후보 하나를 골랐다 — 그 메모를 열린 메모 삼아 같은 말을 다시 한다.
    public func pick(_ candidate: ULID) {
        if pendingAppend != nil {
            appendWebAnswer(to: candidate)
            return
        }
        guard let lastCommand else { return }
        command(lastCommand, selected: candidate)
    }

    /// 답을 못 찾았을 때 대신 보여 줄 관련 메모 — 검색이 찾은 것 중 앞의 셋. 웹 결과는 메모가 아니다.
    public var relatedMemos: [Evidence] { Array(evidence.filter { !$0.isWeb }.prefix(3)) }

    public func brief(now: Date = Date()) {
        if let cached = BriefCache.load(fingerprint: briefFingerprint(now: now)) {
            briefItems = cached
            phase = .done
            return
        }
        run(AssistantRequest(task: .brief, userText: "", now: now))
    }

    /// 다듬기 — 화면 상태를 건드리지 않고 답만 돌려준다. 종이의 다듬기 조작이 부른다.
    public func tidy(_ memoID: ULID) async throws -> String {
        try await runTidy(AssistantRequest(task: .tidy, userText: "", selectedMemoID: memoID))
    }

    private func runTidy(_ request: AssistantRequest) async throws -> String {
        var result: String?
        var failure: AssistantFailure?
        for await event in await coordinator.run(request) {
            switch event {
            case .completed(.tidied(let text)): result = text
            case .failed(let f): failure = f
            case .evidence(let list): stage = .found(list.count)
            case .preparing: stage = .waking(found: 0)
            case .textDelta: stage = .writing(found: 0, tokens: (stage?.tokens ?? 0) + 1)
            default: break
            }
        }
        stage = nil
        if let failure { throw failure }
        guard let result else { throw AssistantFailure.cancelled }
        return result
    }

    /// 렌더·시험용 — 생각하는 중의 한 단계를 세운다 (`PreviewRenderer`). 제품 코드는 부르지 않는다.
    public func stageThinkingForPreview(_ stage: Stage, task: AssistantTask) {
        cancel()
        self.task = task
        phase = .thinking
        self.stage = stage
    }

    /// 렌더·시험용 — 모델 없이 화면 상태를 세운다 (`PreviewRenderer`). 제품 코드는 부르지 않는다.
    public func stageForPreview(answer: AssistantAnswer? = nil, applied: ProposedAction? = nil, proposal: ProposedAction? = nil,
                                failed: String? = nil, offersWeb: String? = nil, results: [Evidence] = [], question: String? = nil) {
        cancel()
        self.answer = answer
        self.applied = applied
        self.proposal = proposal
        self.offersWeb = offersWeb
        evidence = results
        webQuestion = question
        pendingAppend = nil
        phase = failed.map { .failed($0) } ?? .done
    }

    /// 답·제안·결과를 물린다 — 글을 고치면 답은 물러나고 검색으로 돌아간다. 받기 진행은 그대로.
    public func reset() {
        cancel()
        phase = .idle
        answer = nil; evidence = []; proposal = nil; receipt = nil; applied = nil; applyError = nil; briefItems = nil
        pendingDraft = nil; offersWeb = nil; webQuestion = nil; pendingAppend = nil
    }

    public func cancel() {
        guard let current else { return }
        current.task.cancel()
        Task { await coordinator.cancel(current.id) }
        self.current = nil
        if phase == .thinking { phase = .idle }
        stage = nil
    }

    /// 뒤로 물러날 때 — 진행 중인 것을 끊고 모델을 내린다 (명세 §6 iPhone).
    public func suspend() async {
        cancel()
        cancelDownload()
        await provider.unload()
    }

    private func run(_ request: AssistantRequest) {
        cancel()
        task = request.task
        phase = .thinking
        stage = .searching
        answer = nil; evidence = []; proposal = nil; receipt = nil; applyError = nil; applied = nil; offersWeb = nil
        webQuestion = request.task == .webAnswer ? request.userText : nil
        pendingAppend = nil
        if request.task == .brief { briefItems = nil }
        let task = Task { [weak self] in
            guard let self else { return }
            for await event in await coordinator.run(request) {
                guard !Task.isCancelled else { return }
                switch event {
                case .loading: break
                case .preparing: stage = .waking(found: evidence.count)
                case .textDelta:
                    // 조각의 글은 보이지 않는다(JSON) — 세기만. 획이 실제 생성에 맞춰 나아간다.
                    stage = .writing(found: evidence.count, tokens: stage.map(\.tokens).map { $0 + 1 } ?? 1)
                case .evidence(let list):
                    evidence = list
                    stage = .found(list.count)
                case .proposedAction(let action):
                    proposal = action
                    pendingDraft = action.kind == .ask ? action.draft : nil
                case .completed(let result):
                    switch result {
                    case .answer(let a): answer = a
                    case .brief(let items):
                        briefItems = items
                        BriefCache.save(items, fingerprint: briefFingerprint(now: request.now))
                    case .action(let action):
                        phase = .done
                        if Self.appliesImmediately(action) { await apply() }
                    case .tidied: break
                    }
                    phase = .done
                case .failed(let failure):
                    phase = .failed(failure.message)
                    // 메모에 없다 — 웹을 권한다. 누르기 전엔 아무것도 밖으로 나가지 않는다.
                    if failure == .noEvidence, request.task == .answer { offersWeb = request.userText }
                }
            }
            if phase == .thinking { phase = .idle }
            stage = nil
            current = nil
            onSettled?()
        }
        current = (request.id, task)
    }

    /// 단계의 말 — 「메모를 뒤지는 중」「6장 골라 읽는 중」「답을 적는 중」. 웹·다듬기·시키기는 제 말로.
    public var stageLabel: String {
        guard let stage else { return "" }
        let unit = task == .webAnswer ? L("줄") : L("장")
        switch stage {
        case .searching:
            switch task {
            case .webAnswer: return L("웹에서 찾는 중")
            case .tidy: return L("글을 읽는 중")
            case .brief: return L("오늘의 메모를 모으는 중")
            default: return L("메모를 뒤지는 중")
            }
        case .found(let count):
            return count == 0 ? L("읽는 중") : L("\(count)\(unit) 골라 읽는 중")
        case .waking(let count):
            return count == 0 ? L("비서를 깨우는 중") : L("\(count)\(unit) 골랐어요 · 비서를 깨우는 중")
        case .writing:
            switch task {
            case .tidy: return L("정리하는 중")
            case .command: return L("무엇을 할지 정하는 중")
            case .brief: return L("브리핑을 적는 중")
            default: return L("답을 적는 중")
            }
        }
    }

    // MARK: 제안 실행·되돌리기

    public var needsTrashConfirmation: Bool { proposal?.kind == .trash }

    public func apply(confirmedTrash: Bool = false) async {
        guard let proposal else { return }
        applyError = nil
        do {
            receipt = try await executor.execute(proposal, confirmedTrash: confirmedTrash)
            applied = proposal
            self.proposal = nil
        } catch let error as ActionError {
            applyError = error.message
        } catch {
            applyError = String(describing: error)
        }
        onSettled?()
    }

    public func dismissProposal() { proposal = nil }

    public func undo() async {
        guard let receipt else { return }
        do {
            _ = try await executor.undo(receipt)
            self.receipt = nil
            applied = nil
        } catch let error as ActionError {
            applyError = error.message
        } catch {
            applyError = String(describing: error)
        }
        onSettled?()
    }

    // MARK: 브리핑 캐시 — 로컬 날짜 + 입력 지문 + 템플릿 판 (명세 §6)

    private func briefFingerprint(now: Date) -> String {
        let day = CalendarDate(now).description
        let ids = evidence.map { "\($0.memoID):\($0.contentHash.prefix(8))" }.joined(separator: ",")
        return "\(day)|\(TimeZone.current.identifier)|\(manifest.profileID)|t\(manifest.templateVersion)|\(ids)"
    }
}

/// 기기별 캐시. 원본 메모가 바뀌면 지문이 달라져 저절로 무효다. 동기화하지 않는다.
enum BriefCache {
    private static let key = "assistant.brief"
    struct Entry: Codable { var fingerprint: String; var items: [Item] }
    struct Item: Codable { var memoID: String; var reason: String }

    static func load(fingerprint: String) -> [BriefItem]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.fingerprint == fingerprint else { return nil }
        return entry.items.compactMap { item in ULID(item.memoID).map { BriefItem(memoID: $0, reason: item.reason) } }
    }

    static func save(_ items: [BriefItem], fingerprint: String) {
        let entry = Entry(fingerprint: fingerprint, items: items.map { Item(memoID: $0.memoID.stringValue, reason: $0.reason) })
        if let data = try? JSONEncoder().encode(entry) { UserDefaults.standard.set(data, forKey: key) }
    }
}
