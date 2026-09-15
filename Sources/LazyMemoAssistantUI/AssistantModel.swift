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

    public private(set) var phase: Phase = .idle
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

    public init(service: MemoService, support: URL, manifest: ModelManifest = .gemma4E2B, profile: ModelProfile? = nil) {
        self.service = service
        self.manifest = manifest
        self.profile = profile ?? ModelProfile(profileID: manifest.profileID, contextTokens: manifest.contextTokens)
        store = ModelStore(support: support)
        provider = LiteRTProvider(store: store, manifest: manifest)
        coordinator = AssistantCoordinator(provider: provider, evidence: MemoServiceEvidenceSource(service: service), profile: self.profile)
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

    public func ask(_ text: String, selected: ULID? = nil) {
        run(AssistantRequest(task: .answer, userText: text, selectedMemoID: selected))
    }

    public func command(_ text: String, selected: ULID? = nil) {
        lastCommand = text
        run(AssistantRequest(task: .command, userText: text, selectedMemoID: selected))
    }

    /// 되물음의 후보 하나를 골랐다 — 그 메모를 열린 메모 삼아 같은 말을 다시 한다.
    public func pick(_ candidate: ULID) {
        guard let lastCommand else { return }
        command(lastCommand, selected: candidate)
    }

    /// 답을 못 찾았을 때 대신 보여 줄 관련 메모 — 검색이 찾은 것 중 앞의 셋.
    public var relatedMemos: [Evidence] { Array(evidence.prefix(3)) }

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
        let request = AssistantRequest(task: .tidy, userText: "", selectedMemoID: memoID)
        var result: String?
        var failure: AssistantFailure?
        for await event in await coordinator.run(request) {
            switch event {
            case .completed(.tidied(let text)): result = text
            case .failed(let f): failure = f
            default: break
            }
        }
        if let failure { throw failure }
        guard let result else { throw AssistantFailure.cancelled }
        return result
    }

    public func cancel() {
        guard let current else { return }
        current.task.cancel()
        Task { await coordinator.cancel(current.id) }
        self.current = nil
        if phase == .thinking { phase = .idle }
    }

    /// 뒤로 물러날 때 — 진행 중인 것을 끊고 모델을 내린다 (명세 §6 iPhone).
    public func suspend() async {
        cancel()
        cancelDownload()
        await provider.unload()
    }

    private func run(_ request: AssistantRequest) {
        cancel()
        phase = .thinking
        answer = nil; evidence = []; proposal = nil; receipt = nil; applyError = nil
        if request.task == .brief { briefItems = nil }
        let task = Task { [weak self] in
            guard let self else { return }
            for await event in await coordinator.run(request) {
                guard !Task.isCancelled else { return }
                switch event {
                case .loading, .textDelta: break
                case .evidence(let list): evidence = list
                case .proposedAction(let action): proposal = action
                case .completed(let result):
                    switch result {
                    case .answer(let a): answer = a
                    case .brief(let items):
                        briefItems = items
                        BriefCache.save(items, fingerprint: briefFingerprint(now: request.now))
                    case .action, .tidied: break
                    }
                    phase = .done
                case .failed(let failure):
                    phase = .failed(failure.message)
                }
            }
            if phase == .thinking { phase = .idle }
            current = nil
        }
        current = (request.id, task)
    }

    // MARK: 제안 실행·되돌리기

    public var needsTrashConfirmation: Bool { proposal?.kind == .trash }

    public func apply(confirmedTrash: Bool = false) async {
        guard let proposal else { return }
        applyError = nil
        do {
            receipt = try await executor.execute(proposal, confirmedTrash: confirmedTrash)
            self.proposal = nil
        } catch let error as ActionError {
            applyError = error.message
        } catch {
            applyError = String(describing: error)
        }
    }

    public func dismissProposal() { proposal = nil }

    public func undo() async {
        guard let receipt else { return }
        do {
            _ = try await executor.undo(receipt)
            self.receipt = nil
        } catch let error as ActionError {
            applyError = error.message
        } catch {
            applyError = String(describing: error)
        }
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
