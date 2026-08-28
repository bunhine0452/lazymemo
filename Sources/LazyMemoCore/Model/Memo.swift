import Foundation

public enum MemoColor: String, Sendable, CaseIterable, Codable {
    case yellow, green, blue, purple, pink, gray

    public static let `default` = MemoColor.yellow
}

/// 메모 한 장 (설계문서 §5.2).
///
/// **메모와 일정을 타입으로 나누지 않는다.** `due` 나 `at` 이 채워져 있으면
/// 캘린더에도 나타나고, 둘 다 비어 있으면 그냥 메모다. LLM 이 "약속"과 "목표"를
/// 구분해 저장할 필요 없이 날짜 칸만 채우면 되므로 MCP 도구 표면이 단순해진다.
public struct Memo: Sendable, Equatable, Identifiable {
    public var id: ULID
    public var created: Date
    public var updated: Date
    /// 날짜만 — 마감·목표.
    public var due: CalendarDate?
    /// 시각까지 — 약속.
    public var at: Date?
    public var tags: [String]
    public var color: MemoColor
    public var pinned: Bool
    public var body: String

    /// trash 에 있는 동안에만 채워진다 (D6). 보존 기간 계산의 근거이며,
    /// 인덱스가 아니라 파일에 두는 이유는 인덱스를 지워도 살아남아야 하기 때문이다.
    public var deleted: Date?

    /// 앱이 모르는 frontmatter 필드. 읽은 그대로 되쓴다.
    public var preserved: [Frontmatter.Entry]

    /// 앱이 해석하는 키 — 나머지는 전부 `preserved` 로 간다.
    public static let knownKeys: Set<String> = [
        "id", "created", "updated", "due", "at", "tags", "color", "pinned", "deleted",
    ]

    public init(
        id: ULID = ULID(),
        created: Date = Date(),
        updated: Date = Date(),
        due: CalendarDate? = nil,
        at: Date? = nil,
        tags: [String] = [],
        color: MemoColor = .default,
        pinned: Bool = false,
        body: String = "",
        deleted: Date? = nil,
        preserved: [Frontmatter.Entry] = []
    ) {
        self.id = id
        // 파일이 담을 수 있는 정밀도로 맞춘다 — 안 그러면 저장 직후의
        // 메모리 값과 디스크 값이 초 미만에서 어긋난다.
        self.created = created.truncatingSubsecond
        self.updated = updated.truncatingSubsecond
        self.due = due
        self.at = at?.truncatingSubsecond
        self.tags = tags
        self.color = color
        self.pinned = pinned
        self.body = body
        self.deleted = deleted
        self.preserved = preserved
    }

    /// 캘린더에 나타나는가 (설계문서 §10).
    public var isScheduled: Bool { due != nil || at != nil }

    /// 캘린더가 이 메모를 놓을 날짜. `at` 이 있으면 그 날, 없으면 `due`.
    public func scheduledDate(calendar: Calendar = .current) -> CalendarDate? {
        if let at { return CalendarDate(at, calendar: calendar) }
        return due
    }

    /// 목록·창 제목에 쓸 한 줄. 본문 첫 비어 있지 않은 줄에서 마크다운 장식을 걷어낸다.
    public var title: String {
        let line = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init) ?? ""
        let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: "# \t-*>"))
        return stripped.isEmpty ? "빈 메모" : stripped
    }
}
