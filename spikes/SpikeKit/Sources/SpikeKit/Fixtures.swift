import Foundation

/// `Tests/Fixtures/Assistant/memos.json` — 가상 한국어 메모. 사용자 실제 메모가 아니다.
public struct FixtureVault: Codable, Sendable {
    public var version: Int
    /// 평가 기준 시각. 질문의 「금요일」「내일」은 이 시각 기준.
    public var now: String
    public var timeZone: String
    public var memos: [FixtureMemo]

    public var nowDate: Date { ISO8601DateFormatter().date(from: now) ?? Date() }
    public func memo(_ id: String) -> FixtureMemo? { memos.first { $0.id == id } }
}

public struct FixtureMemo: Codable, Sendable {
    public var id: String
    public var created: String
    public var due: String?
    public var at: String?
    public var surface: String?
    public var place: String?
    public var tags: [String]
    public var folder: String?
    public var body: String
    public var deleted: String?
    public var done: Bool

    /// 모델에게 보여 주는 근거 한 장 — 앱의 Evidence(명세 §3)와 같은 필드만.
    public func rendered() -> String {
        var lines = ["[id: \(id)]"]
        if let due { lines.append("due: \(due)") }
        if let at { lines.append("at: \(at)") }
        if let surface { lines.append("surface: \(surface)") }
        if let place { lines.append("place: \(place)") }
        if let folder { lines.append("folder: \(folder)") }
        if !tags.isEmpty { lines.append("tags: \(tags.joined(separator: ", "))") }
        if deleted != nil { lines.append("state: 휴지통") }
        if done { lines.append("state: 완료") }
        lines.append("created: \(created)")
        lines.append(body)
        return lines.joined(separator: "\n")
    }
}

/// `questions.json` — 80문항. 종류별 기대값은 `Expect` 의 해당 필드만 채운다.
public struct FixtureQuestions: Codable, Sendable {
    public var version: Int
    public var items: [FixtureQuestion]
}

public enum QuestionKind: String, Codable, Sendable, CaseIterable {
    case answer, command, tidy, brief, ambiguous, safety
}

public struct FixtureQuestion: Codable, Sendable {
    public var id: String
    public var kind: QuestionKind
    public var text: String
    /// 열린 메모 — 「이거」의 대상. 없으면 nil.
    public var selectedMemo: String?
    /// 모델에게 근거로 넘길 메모 id (정답+오답 섞음). 검색 자체는 여기서 평가하지 않는다.
    public var candidates: [String]
    public var expect: Expect
    public var note: String?

    public struct Expect: Codable, Sendable {
        /// answer: 답이 반드시 인용해야 하는 id 전부.
        public var evidence: [String]?
        /// answer: 각 묶음에서 하나 이상은 답에 있어야 한다.
        public var mustContainAny: [[String]]?
        /// answer: 근거가 없다고 답해야 한다.
        public var abstain: Bool?
        /// command: 기대 행동. `ask` 면 되묻기.
        public var action: ExpectedAction?
        /// tidy: 글자 그대로 남아야 하는 토큰.
        public var mustPreserve: [String]?
        public var mustNotContain: [String]?
        /// brief: 허용 id, 금지 id, 반드시 포함 id, 최대 개수.
        public var allowed: [String]?
        public var excluded: [String]?
        public var mustInclude: [String]?
        public var max: Int?
        /// ambiguous·safety: 실행이 없어야 한다 (ask 또는 none).
        public var noAction: Bool?
    }

    public struct ExpectedAction: Codable, Sendable {
        public var kind: String
        public var memoID: String?
        /// 필드 → 기대값. 값이 "" 이면 지우기(clear).
        public var patch: [String: String]?
        /// 바뀌면 안 되는 필드.
        public var preserve: [String]?
    }
}

/// `speed.json` — 고정 프롬프트. 입력 크기 목표는 글자 수 추정이고, 실제 토큰은 runner 가 센다.
public struct FixtureSpeed: Codable, Sendable {
    public var version: Int
    public var items: [SpeedPrompt]
}

public struct SpeedPrompt: Codable, Sendable {
    public var id: String
    public var targetTokens: Int
    public var system: String
    public var user: String
    public var maxOutputTokens: Int
}

public enum FixtureLoader {
    public static func load<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public static func loadAll(directory: URL) throws -> (FixtureVault, FixtureQuestions, FixtureSpeed) {
        (
            try load(FixtureVault.self, at: directory.appendingPathComponent("memos.json")),
            try load(FixtureQuestions.self, at: directory.appendingPathComponent("questions.json")),
            try load(FixtureSpeed.self, at: directory.appendingPathComponent("speed.json"))
        )
    }
}
