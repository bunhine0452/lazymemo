import Foundation
import LazyMemoCore

// 명세 §3 — 앱 내부 계약. 엔진(LiteRT·MLX)은 이 모듈을 모르고, 이 모듈도 엔진을 모른다.
// 엔진 어댑터는 `LocalModelProvider` 를 구현하는 별도 타깃에 산다.

/// 무엇을 시키는가. `webAnswer` 는 근거가 메모가 아니라 웹 검색 결과인 `answer` — 검색은 앱이 하고 모델은 읽기만 한다.
/// `digest` 는 그렇게 찾은 것을 **메모 한 장으로 정리**하는 일이다 (`Digest`) — 다듬기와 달리 자리(제목·핵심·세부)가 정해져 있다.
public enum AssistantTask: String, Sendable, Codable, CaseIterable {
    case answer, tidy, brief, command, webAnswer, digest
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
        // 384 는 한국어 두 문장 + 근거 둘을 겨우 담는다. 여러 쪽을 견줘 답하라고 시킨 뒤로는
        // 뒷부분이 잘려 JSON 이 안 닫히는 일이 생겼다 — 512 로 올린다 (구조는 `OutputValidator` 가 다시 본다).
        case .answer, .webAnswer: return 512
        // 정리 메모는 제목·답·핵심 목록·표까지 한 번에 나온다. 여기서 잘리면 표가 반 토막 난다.
        case .digest: return 640
        case .command: return 256
        }
    }
}

/// 모델에게 보여 준 근거 한 장 — 메모, 또는 웹 검색 결과 하나. 답의 인용은 이 목록 안의 id 만 허용된다.
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
    /// 웹 검색 결과면 그 주소와 제목. 메모면 nil — 검증·인용 규칙은 같고, 화면이 링크로 그린다.
    public let url: URL?
    public let title: String?
    /// 그 페이지에서 읽어 온 본문 발췌 (`PageReader`). 못 읽었으면 nil 이고 그때는 `excerpt` 가 근거다.
    ///
    /// **덧붙는 자리다** — 화면은 여전히 `excerpt`(검색 발췌 한 줄)를 보여 준다. 길고 지저분한
    /// 본문을 카드에 흘리지 않으려는 것이고, 모델과 검증만 `readable` 로 둘을 함께 읽는다.
    public internal(set) var passage: String?

    public enum State: String, Sendable { case active, done, trashed, unreadable }

    public init(memo: Memo, excerptLimit: Int = 600) {
        memoID = memo.id
        contentHash = memo.contentHash
        excerpt = String(memo.body.prefix(excerptLimit))
        schedule = Schedule(due: memo.due, at: memo.at)
        surface = memo.surface
        folder = memo.folder
        if memo.deleted != nil { state = .trashed }
        // 끝낸 것·보관한 것도 비서에게는 「끝난 것」이다 — 물러난 까닭은 달라도 지금 할 일이 아니다 (인계서 §4).
        else if memo.isPutAway || memo.done != nil || Tidy.isFinishedChecklist(memo.body) { state = .done }
        else { state = .active }
        url = nil
        title = nil
        passage = nil
    }

    /// 웹 검색 결과 하나. id 는 이 요청 안에서만 뜻이 있는 새 ULID — 모델이 인용할 26자가 필요할 뿐이다.
    public init(hit: WebHit) {
        memoID = ULID()
        contentHash = Memo.contentHash(of: hit.snippet)
        excerpt = hit.snippet
        schedule = Schedule(due: nil, at: nil)
        surface = nil
        folder = nil
        state = .active
        url = hit.url
        title = hit.title
        passage = nil
    }

    public var isWeb: Bool { url != nil }

    /// 모델과 검증이 실제로 읽는 글 — 본문을 읽어 왔으면 발췌 + 본문, 아니면 발췌뿐.
    public var readable: String {
        guard let passage, !passage.isEmpty else { return excerpt }
        return excerpt.isEmpty ? passage : excerpt + "\n" + passage
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
    /// createMemo 만 — 글에서 읽은 장소·좌표(`NoteReader`). 기존 메모의 장소는 비서가 바꾸지 않는다.
    public var place: String?
    public var geo: Coordinate?

    public init(body: String? = nil, due: FieldChange<CalendarDate> = .keep, at: FieldChange<Date> = .keep,
                surface: FieldChange<Date> = .keep, folder: FieldChange<String> = .keep,
                place: String? = nil, geo: Coordinate? = nil) {
        self.body = body; self.due = due; self.at = at; self.surface = surface; self.folder = folder
        self.place = place; self.geo = geo
    }

    public var isEmpty: Bool { body == nil && due == .keep && at == .keep && surface == .keep && folder == .keep }
}

/// 명세 §5 allowlist. 여기 없는 동작은 제안조차 만들지 않는다.
public enum ActionKind: String, Sendable, Codable, CaseIterable {
    case setRecall, reschedule, moveToFolder, createMemo, trash
    /// 있는 메모 끝에 글을 덧붙인다 — 웹의 답을 「치과 메모에 추가해줘」(`WebFollowUp`). **앱만 만든다** —
    /// 모델의 명령 스키마에는 없다(`AssistantPrompts.jsonSchema`): 모델이 남의 메모에 글을 얹는 길은 두지 않는다.
    case appendToMemo
    /// 정보가 하나 부족하다 — 한 가지만 묻는다.
    case ask
    case none

    public var writes: Bool {
        switch self {
        case .setRecall, .reschedule, .moveToFolder, .createMemo, .trash, .appendToMemo: return true
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
    /// ask 일 때 — 한 가지만 더 들으면 완성되는 새 메모. 「약속 시간이 언제인가요?」의 뒤에 이것이 있다.
    public let draft: FieldPatch?

    public init(id: UUID = UUID(), requestID: AssistantRequest.ID, kind: ActionKind, memoID: ULID? = nil,
                expectedContentHash: String? = nil, patch: FieldPatch = FieldPatch(), question: String? = nil,
                candidates: [ULID] = [], draft: FieldPatch? = nil) {
        self.id = id; self.requestID = requestID; self.kind = kind; self.memoID = memoID
        self.expectedContentHash = expectedContentHash; self.patch = patch; self.question = question
        self.candidates = candidates; self.draft = draft
    }
}

public struct AssistantAnswer: Sendable, Equatable {
    public let found: Bool
    public let text: String
    public let evidence: [ULID]
    /// 근거 메모에서 그대로 옮긴 줄 — 모델의 한 문장 밑에 원문이 선다. 답이 모자라도 사람이 여기서 본다.
    public let quotes: [String]
    /// 웹에서 찾은 답이면 인용한 페이지들 — `evidence` 와 같은 순서. 메모 답이면 빈 배열.
    public let sources: [WebSource]
    public init(found: Bool, text: String, evidence: [ULID], quotes: [String] = [], sources: [WebSource] = []) {
        self.found = found; self.text = text; self.evidence = evidence; self.quotes = quotes; self.sources = sources
    }
    public var isWeb: Bool { !sources.isEmpty }
}

/// 답이 인용한 웹 페이지 하나 — 화면이 제목·주소로 그리고, 누르면 브라우저로.
public struct WebSource: Sendable, Equatable, Identifiable {
    public let id: ULID
    public let title: String
    public let url: URL
    public init(id: ULID, title: String, url: URL) { self.id = id; self.title = title; self.url = url }
    /// 「weather.go.kr」— 제목 옆에 서는 출처.
    public var host: String { (url.host() ?? url.absoluteString).replacingOccurrences(of: "www.", with: "") }
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
    /// 웹 검색이 답하지 않았다 — 연결이 없거나, 검색 사이트가 브라우저 아닌 요청을 막았다.
    case webUnavailable
    /// 웹 검색은 됐는데 답이 될 결과가 없다.
    case webEmpty
    case budgetExceeded(String)
    case provider(String)

    public var message: String {
        switch self {
        case .modelUnavailable: return "이 기기에 모델이 없습니다 — 「금요일 10시에 다시 알려줘」처럼 시각·할 일을 분명히 말하면 모델 없이도 됩니다"
        case .cancelled: return "취소했습니다"
        case .malformedOutput: return "답의 모양이 맞지 않아 아무것도 바꾸지 않았습니다"
        case .noEvidence: return "메모에서 근거를 찾지 못했습니다"
        case .webUnavailable: return "웹에 닿지 못했습니다 — 연결을 확인하고 다시 해 보세요"
        case .webEmpty: return "웹에서 찾지 못했습니다"
        case .budgetExceeded(let what): return "한도를 넘었습니다: \(what)"
        case .provider(let detail): return detail
        }
    }
}

public enum AssistantEvent: Sendable, Equatable {
    case loading
    /// 모델을 올리는 중 — 근거를 고른 뒤, 첫 글자 전. 콜드 스타트는 몇 초라 화면이 그 까닭을 말해야 한다.
    case preparing
    /// 모델이 낸 글자 조각. 다듬기는 글이라 그대로 보이고, 나머지(JSON)는 **움직임의 근거**로만 — 화면이 조각을
    /// 세어 「답을 적는 중」의 획을 그만큼 밀어 준다 (2026-09-17 사용자: 「기다리는데 아무것도 안 뜨다 갑자기 팍」).
    case textDelta(String)
    case evidence([Evidence])
    case proposedAction(ProposedAction)
    case completed(AssistantResult)
    case failed(AssistantFailure)
}
