import Foundation
import LazyMemoCore

// 명세 §3 — 앱 내부 계약. 엔진(LiteRT·MLX)은 이 모듈을 모르고, 이 모듈도 엔진을 모른다.
// 엔진 어댑터는 `LocalModelProvider` 를 구현하는 별도 타깃에 산다.

/// 무엇을 시키는가.
public enum AssistantTask: String, Sendable, Codable, CaseIterable {
    case answer, tidy, brief, command
}

public struct AssistantRequest: Sendable, Identifiable {
    public typealias ID = UUID
    public let id: ID
    public let task: AssistantTask
    public let userText: String
    /// 열린 메모 — 「이거」의 유일한 대상.
    public let selectedMemoID: ULID?
    public let now: Date
    public let timeZone: TimeZone
    public let locale: Locale
    public let inputBudget: Int
    public let outputBudget: Int

    public init(
        id: ID = UUID(), task: AssistantTask, userText: String, selectedMemoID: ULID? = nil,
        now: Date = Date(), timeZone: TimeZone = .current, locale: Locale = .current,
        inputBudget: Int = TokenBudget.context, outputBudget: Int? = nil
    ) {
        self.id = id
        self.task = task
        self.userText = userText
        self.selectedMemoID = selectedMemoID
        self.now = now
        self.timeZone = timeZone
        self.locale = locale
        self.inputBudget = inputBudget
        self.outputBudget = outputBudget ?? TokenBudget.output(for: task)
    }
}

/// 명세 §4 — 폰·M1·8GB 맥 공통 상한. 16GB 이상의 8192 는 실측 뒤.
public enum TokenBudget {
    public static let context = 4096
    public static func output(for task: AssistantTask) -> Int {
        switch task {
        case .tidy, .brief: return 192
        case .answer: return 384
        case .command: return 256
        }
    }
}

/// 모델에게 보여 준 메모 한 장. 답의 인용은 이 목록 안의 id 만 허용된다.
public struct Evidence: Sendable, Equatable, Identifiable {
    public var id: ULID { memoID }
    public let memoID: ULID
    /// 변경 직전 대조에 쓰는 본문 hash. `updated` 는 초 단위라 버전 토큰이 못 된다(명세 §5).
    public let contentHash: String
    public let excerpt: String
    public let schedule: Schedule
    public let surface: Date?
    public let folder: String?
    public let state: State

    public enum State: String, Sendable { case active, done, trashed, unreadable }

    public init(memo: Memo, excerptLimit: Int = 600) {
        memoID = memo.id
        contentHash = memo.contentHash
        excerpt = String(memo.body.prefix(excerptLimit))
        schedule = Schedule(due: memo.due, at: memo.at)
        surface = memo.surface
        folder = memo.folder
        if memo.deleted != nil { state = .trashed }
        else if memo.tidied != nil || Tidy.isFinishedChecklist(memo.body) { state = .done }
        else { state = .active }
    }

    public static func hash(of body: String) -> String { Memo.contentHash(of: body) }
}

/// 한 필드의 변경 — 「건드리지 않음」과 「비움」을 가른다 (MemoService 의 이중 옵셔널과 같은 뜻).
public enum FieldChange<Value: Sendable & Equatable>: Sendable, Equatable {
    case keep
    case clear
    case set(Value)

    /// MemoService.update 의 `Value??` 로 옮긴다.
    public var doubleOptional: Value?? {
        switch self {
        case .keep: return nil
        case .clear: return .some(nil)
        case .set(let v): return .some(v)
        }
    }
}

/// 사용자가 말한 필드만 담는다. 말하지 않은 필드는 `.keep`.
public struct FieldPatch: Sendable, Equatable {
    public var body: String?
    public var due: FieldChange<CalendarDate> = .keep
    public var at: FieldChange<Date> = .keep
    public var surface: FieldChange<Date> = .keep
    public var folder: FieldChange<String> = .keep

    public init(body: String? = nil, due: FieldChange<CalendarDate> = .keep, at: FieldChange<Date> = .keep,
                surface: FieldChange<Date> = .keep, folder: FieldChange<String> = .keep) {
        self.body = body; self.due = due; self.at = at; self.surface = surface; self.folder = folder
    }

    public var isEmpty: Bool { body == nil && due == .keep && at == .keep && surface == .keep && folder == .keep }
}

/// 명세 §5 allowlist. 여기 없는 동작은 제안조차 만들지 않는다.
public enum ActionKind: String, Sendable, Codable, CaseIterable {
    case setRecall, reschedule, moveToFolder, createMemo, trash
    /// 정보가 하나 부족하다 — 한 가지만 묻는다.
    case ask
    case none

    public var writes: Bool {
        switch self {
        case .setRecall, .reschedule, .moveToFolder, .createMemo, .trash: return true
        case .ask, .none: return false
        }
    }
}

/// 모델이 낸 것은 여기까지다. 저장은 정책을 거친 앱 코드가 한다.
public struct ProposedAction: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let requestID: AssistantRequest.ID
    public let kind: ActionKind
    public let memoID: ULID?
    /// 실행 직전 이 값과 본문 hash 가 다르면 실행하지 않는다.
    public let expectedContentHash: String?
    public let patch: FieldPatch
    public let question: String?
    /// ask 일 때 — 「어느 메모?」에 고를 수 있는 후보. 열린 메모가 없을 때 검색이 찾은 것들.
    public let candidates: [ULID]

    public init(id: UUID = UUID(), requestID: AssistantRequest.ID, kind: ActionKind, memoID: ULID? = nil,
                expectedContentHash: String? = nil, patch: FieldPatch = FieldPatch(), question: String? = nil,
                candidates: [ULID] = []) {
        self.id = id; self.requestID = requestID; self.kind = kind; self.memoID = memoID
        self.expectedContentHash = expectedContentHash; self.patch = patch; self.question = question
        self.candidates = candidates
    }
}

public struct AssistantAnswer: Sendable, Equatable {
    public let found: Bool
    public let text: String
    public let evidence: [ULID]
    /// 근거 메모에서 그대로 옮긴 줄 — 모델의 한 문장 밑에 원문이 선다. 답이 모자라도 사람이 여기서 본다.
    public let quotes: [String]
    public init(found: Bool, text: String, evidence: [ULID], quotes: [String] = []) {
        self.found = found; self.text = text; self.evidence = evidence; self.quotes = quotes
    }
}

public struct BriefItem: Sendable, Equatable {
    public let memoID: ULID
    public let reason: String
    public init(memoID: ULID, reason: String) { self.memoID = memoID; self.reason = reason }
}

public enum AssistantResult: Sendable, Equatable {
    case answer(AssistantAnswer)
    case tidied(String)
    case brief([BriefItem])
    case action(ProposedAction)
}

public enum AssistantFailure: Error, Sendable, Equatable {
    case modelUnavailable
    case cancelled
    case malformedOutput
    case noEvidence
    case budgetExceeded(String)
    case provider(String)

    public var message: String {
        switch self {
        case .modelUnavailable: return "이 기기에 모델이 없습니다 — 「금요일 10시에 다시 알려줘」처럼 시각·할 일을 분명히 말하면 모델 없이도 됩니다"
        case .cancelled: return "취소했습니다"
        case .malformedOutput: return "답의 모양이 맞지 않아 아무것도 바꾸지 않았습니다"
        case .noEvidence: return "메모에서 근거를 찾지 못했습니다"
        case .budgetExceeded(let what): return "한도를 넘었습니다: \(what)"
        case .provider(let detail): return detail
        }
    }
}

public enum AssistantEvent: Sendable, Equatable {
    case loading
    case textDelta(String)
    case evidence([Evidence])
    case proposedAction(ProposedAction)
    case completed(AssistantResult)
    case failed(AssistantFailure)
}
