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

    /// 되풀이하는 일인가 (`Recurrence`).
    ///
    /// **주기만 적는다.** 언제인지는 `due`·`at` 이 들고 있고, 그 회차가 지나면
    /// 다음 회차로 걸어간다 (`Tidy.rolled`). 그래서 달력은 늘 **다음 한 번**만
    /// 보여 주고, 「지난 일정은 물러난다」(철학 3)가 이 메모에는 적용되지 않는다 —
    /// 되풀이하는 일은 지나가지 않는다.
    public var every: Recurrence?

    /// **이 종이가 나올 시각.** 일이 언제인가(`due`·`at`)와 다른 것을 말한다 —
    /// 회의는 3시, 종이는 2시 30분.
    ///
    /// 장소와 같은 성질이다: **자리를 바꾸지 않는다.** 달력에 따로 나타나지
    /// 않고(`isScheduled` 는 이 필드를 보지 않는다), 그 시각에 하는 일은
    /// 바탕화면의 종이가 앞으로 나오는 것뿐이다 (`DueClock`). 시스템 알림
    /// 권한은 여전히 쓰지 않는다.
    ///
    /// Claude 가 정할 수 있는 유일한 «시간» 이기도 하다 — 「회의 30분 전에
    /// 이거 띄워줘」가 여기로 들어온다 (MCP `surface_at`).
    public var surface: Date?

    /// 어디 — 사람이 읽는 이름 그대로 (`강남역 3번 출구`).
    ///
    /// **장소는 자리를 정하지 않는다.** 날짜가 붙으면 종이가 물러나고 달력이
    /// 맡지만 (§7.2), 장소가 붙어도 종이는 그 자리에 그대로 있다. 구조는 여전히
    /// 시간 하나이고 (§14.2), 장소는 날짜와 같은 **부사**다 — 담는 그릇이 아니다.
    /// 그래서 `isScheduled` 는 이 필드를 보지 않는다.
    public var place: String?

    /// 좌표가 있으면 길찾기가 정확해진다. **없어도 된다** — 이름만으로 지도에
    /// 검색어로 넘길 수 있다.
    public var geo: Coordinate?

    public var tags: [String]
    public var color: MemoColor
    public var pinned: Bool
    public var body: String

    /// 어느 폴더에 넣어 두었는가 (`MemoFolders`). 없으면 폴더 밖이다.
    ///
    /// **폴더는 서랍의 칸이다.** 날짜가 자리를 정하는 것(§7.2)과 달리 폴더는
    /// 종이가 서랍에 들어갔을 때 어느 칸에 놓이는지만 말한다 — 바탕화면에
    /// 나와 있는 종이도 이 이름표를 달고 있을 수 있고, 다시 넣으면 그 칸으로
    /// 돌아간다. 이름표는 파일에 적는다: 폴더를 옮겨도, Claude 가 MCP 로
    /// 읽어도 같은 것을 본다.
    public var folder: String?

    /// trash 에 있는 동안에만 채워진다 (D6). 보존 기간 계산의 근거이며,
    /// 인덱스가 아니라 파일에 두는 이유는 인덱스를 지워도 살아남아야 하기 때문이다.
    public var deleted: Date?

    /// 스스로 물러난 때 (`Tidy`). 채워져 있으면 바탕화면과 목록에서 빠진다 —
    /// **지운 것이 아니다.** 파일에도, 검색에도, 달력에도 그대로 있다.
    ///
    /// `layout.json` 이 아니라 파일에 두는 이유는 `deleted` 와 같다. 파생물에
    /// 두면 Application Support 를 지우는 것만으로 몇 달치 끝난 메모가 한꺼번에
    /// 바탕화면으로 되살아난다 — 복원이 아니라 사고다.
    public var tidied: Date?

    /// 앱이 모르는 frontmatter 필드. 읽은 그대로 되쓴다.
    public var preserved: [Frontmatter.Entry]

    /// 앱이 해석하는 키 — 나머지는 전부 `preserved` 로 간다.
    public static let knownKeys: Set<String> = [
        "id", "created", "updated", "due", "at", "every", "surface", "place", "geo",
        "tags", "color", "pinned", "folder", "deleted", "tidied",
    ]

    public init(
        id: ULID = ULID(),
        created: Date = Date(),
        updated: Date = Date(),
        due: CalendarDate? = nil,
        at: Date? = nil,
        every: Recurrence? = nil,
        surface: Date? = nil,
        place: String? = nil,
        geo: Coordinate? = nil,
        tags: [String] = [],
        color: MemoColor = .default,
        pinned: Bool = false,
        body: String = "",
        folder: String? = nil,
        deleted: Date? = nil,
        tidied: Date? = nil,
        preserved: [Frontmatter.Entry] = []
    ) {
        self.id = id
        // 파일이 담을 수 있는 정밀도로 맞춘다 — 안 그러면 저장 직후의
        // 메모리 값과 디스크 값이 초 미만에서 어긋난다.
        self.created = created.truncatingSubsecond
        self.updated = updated.truncatingSubsecond
        self.due = due
        self.at = at?.truncatingSubsecond
        self.every = every
        self.surface = surface?.truncatingSubsecond
        self.place = place
        self.geo = geo
        self.tags = tags
        self.color = color
        self.pinned = pinned
        self.body = body
        self.folder = MemoFolders.normalized(folder)
        self.deleted = deleted
        self.tidied = tidied
        self.preserved = preserved
    }

    /// 캘린더에 나타나는가 (설계문서 §10). **장소는 여기에 끼지 않는다.**
    public var isScheduled: Bool { due != nil || at != nil }

    /// 종이에 장소 잉크가 찍히는가. 이름이든 좌표든 하나만 있으면 된다.
    public var hasPlace: Bool { place != nil || geo != nil }

    /// 이 종이가 앞으로 나올 시각. **적혀 있으면 그것, 없으면 일정 시각이다.**
    ///
    /// 시계(`DueClock`)가 보는 값이 이것 하나여야, 「일정 시각에 나온다」와
    /// 「따로 정한 시각에 나온다」가 두 갈래로 갈라지지 않는다.
    public var surfacesAt: Date? { surface ?? at }

    /// 일정 옆에 적을 「나올 때」. 일정이 없거나 같은 시각이면 `nil`.
    public var surfaceLead: String? {
        guard let surface else { return nil }
        guard let event = at ?? due?.startOfDay() else { return nil }
        return SurfaceWords.lead(surface: surface, event: event)
    }

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
