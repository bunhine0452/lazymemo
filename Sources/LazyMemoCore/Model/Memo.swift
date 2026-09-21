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

    /// 달·해마다 되풀이하는 일이 **처음 적힌 날** (`Recurrence.walk`).
    ///
    /// 달 걸음은 짧은 달에서 잘린다 — 1월 31일의 다음 달은 2월 28일. 거기서 또 한 걸음을
    /// 재면 3월 28일이 되어 「매월 31일 월세」가 영영 사흘 앞당겨진다. 그래서 걸어간
    /// 메모는 처음 날을 여기 적어 두고 늘 거기서부터 잰다: 2월 28일 → 3월 31일.
    /// 사람이 날짜를 옮기면 지운다 — 옮긴 그 날이 새 처음이다 (`MemoService.update`).
    /// 매일·매주는 잘릴 일이 없어 적지 않는다.
    public var anchor: CalendarDate?

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
    public var deleted: Date? {
        get { marks.deleted }
        set { marks = marks.with { $0.deleted = newValue } }
    }

    /// 스스로 물러난 때 (`Tidy`). 채워져 있으면 바탕화면과 목록에서 빠진다 —
    /// **지운 것이 아니다.** 파일에도, 검색에도, 달력에도 그대로 있다.
    ///
    /// `layout.json` 이 아니라 파일에 두는 이유는 `deleted` 와 같다. 파생물에
    /// 두면 Application Support 를 지우는 것만으로 몇 달치 끝난 메모가 한꺼번에
    /// 바탕화면으로 되살아난다 — 복원이 아니라 사고다.
    public var tidied: Date? {
        get { marks.tidied }
        set { marks = marks.with { $0.tidied = newValue } }
    }

    /// 사람이 치워 둔 것을 **도로 꺼낸 때** (`MemoService.untidy`). 채워져 있으면 규칙이
    /// 다시 치우지 않는다 — 사람의 뜻이 규칙을 이긴다 (인계서 §4 「복원」).
    ///
    /// 없던 시절에는 꺼낸 다음 정리가 도로 치웠다: 지난 일정은 `updated` 를 보지 않으므로
    /// 꺼낸 그 날 저녁에 없어졌고, 사람 눈에 그것은 고장이었다. 이것도 `tidied` 처럼
    /// 파일에 적는다 — 다른 기기의 정리도 같은 답을 내야 한다. 때(`due`·`at`·`surface`)를
    /// 옮기면 지운다: 그것은 새 회차이고, 그 날이 지나면 규칙이 다시 센다.
    public var kept: Date? {
        get { marks.kept }
        set { marks = marks.with { $0.kept = newValue } }
    }

    /// 두 기기가 따로 고쳐 만난 충돌에서 **진 판본**이면, 자리를 지킨 메모의 id (`ConflictSettlement`).
    ///
    /// 진 판본은 새 id 로 휴지통에 앉는데, 이 표시가 없으면 「지운 메모」와 구별되지 않는다 —
    /// 사람은 자기가 지운 적 없는 글이 휴지통에 왜 있는지 모르고, 그 문장이 어느 메모에서
    /// 떨어져 나왔는지도 모른다. 휴지통에서 되돌리면(둘 다 남기기) 지운다 — 그때부터 제 메모다.
    public var conflictOf: ULID? {
        get { marks.conflictOf }
        set { marks = marks.with { $0.conflictOf = newValue } }
    }

    /// **사람이 끝냈다고 한 때** (인계서 §4 「완료」). 파일에 적혀 동기화되고, 되돌릴 수 있다.
    ///
    /// 날짜가 지난 것도, 다 체크한 목록도 완료가 아니다 — 완료는 사람의 뜻뿐이다. 끝난 일은 알림·「지금」에서
    /// 빠지고(`Recall.eligible`), 사흘 뒤 스스로 물러난다(`Tidy` — 방금 끝낸 것이 눈앞에서 없어지면 사고로 보인다).
    /// 되풀이하는 일은 **이 회차**만 끝난 것이다 — 다음 회차로 걸어가면 지워진다 (`Tidy.rolled`).
    /// 때(`due`·`at`·`surface`)를 옮기면 지운다 — 새 회차다.
    public var done: Date? {
        get { marks.done }
        set { marks = marks.with { $0.done = newValue } }
    }

    /// **당장 안 볼 기록으로 넣어 둔 때** (인계서 §4 「보관」). 완료도 삭제도 아니다.
    ///
    /// 목록·바탕화면·알림·「지금」에서 빠지고, 검색과 원문은 그대로다 — 「읽을 자료를 저장하고 다시 볼 때를 정한다.
    /// 읽은 뒤 보관하거나 다시 미룬다」의 그 보관. `tidied` 와 달리 규칙이 아니라 사람이 넣는다.
    public var archived: Date? {
        get { marks.archived }
        set { marks = marks.with { $0.archived = newValue } }
    }

    /// 드물게 찍히는 표시 여섯 — 지움·치움·꺼냄·다른 판·완료·보관 — 을 **한 상자에** 둔다.
    ///
    /// 값이 여섯 개 늘자 `Memo` 가 256바이트를 넘었고, 그 순간 Swift 6.3.3(CI 의 Xcode 26.6)이 이 구조체를
    /// 비동기 프레임에서 잘못 풀어 「freed pointer was not the last allocation」으로 죽었다 — 0.9.4 소스에
    /// 이 필드들만 얹어 재현했다 (2026-09-22). 6.4 는 멀쩡하다. 상자는 불변 참조라 복사는 포인터 하나이고,
    /// 바꿀 때 새 상자를 만든다 — 값 의미는 그대로다 (`==` 도 내용으로 잰다).
    private var marks: Marks

    /// `deleted`·`tidied`·`kept`·`conflictOf`·`done`·`archived` 의 상자. 바깥에서는 그 이름들로만 보인다.
    final class Marks: Sendable, Equatable {
        let deleted: Date?
        let tidied: Date?
        let kept: Date?
        let conflictOf: ULID?
        let done: Date?
        let archived: Date?

        /// 아무것도 안 찍힌 상자 — 새 메모 대부분이 이것을 나눠 든다.
        static let none = Marks(deleted: nil, tidied: nil, kept: nil, conflictOf: nil, done: nil, archived: nil)

        init(deleted: Date?, tidied: Date?, kept: Date?, conflictOf: ULID?, done: Date?, archived: Date?) {
            self.deleted = deleted
            self.tidied = tidied
            self.kept = kept
            self.conflictOf = conflictOf
            self.done = done
            self.archived = archived
        }

        /// 한 칸 바꾼 새 상자.
        struct Draft {
            var deleted: Date?, tidied: Date?, kept: Date?, conflictOf: ULID?, done: Date?, archived: Date?
        }

        func with(_ change: (inout Draft) -> Void) -> Marks {
            var draft = Draft(deleted: deleted, tidied: tidied, kept: kept, conflictOf: conflictOf, done: done, archived: archived)
            change(&draft)
            let made = Marks(
                deleted: draft.deleted, tidied: draft.tidied, kept: draft.kept,
                conflictOf: draft.conflictOf, done: draft.done, archived: draft.archived
            )
            return made == Marks.none ? Marks.none : made
        }

        static func == (lhs: Marks, rhs: Marks) -> Bool {
            lhs === rhs || (lhs.deleted == rhs.deleted && lhs.tidied == rhs.tidied && lhs.kept == rhs.kept
                && lhs.conflictOf == rhs.conflictOf && lhs.done == rhs.done && lhs.archived == rhs.archived)
        }
    }

    /// 앱이 모르는 frontmatter 필드. 읽은 그대로 되쓴다.
    public var preserved: [Frontmatter.Entry]

    /// 앱이 해석하는 키 — 나머지는 전부 `preserved` 로 간다.
    public static let knownKeys: Set<String> = [
        "id", "created", "updated", "due", "at", "every", "anchor", "surface", "place", "geo",
        "tags", "color", "pinned", "folder", "deleted", "tidied", "kept", "conflict", "done", "archived",
    ]

    public init(
        id: ULID = ULID(),
        created: Date = Date(),
        updated: Date = Date(),
        due: CalendarDate? = nil,
        at: Date? = nil,
        every: Recurrence? = nil,
        anchor: CalendarDate? = nil,
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
        kept: Date? = nil,
        conflictOf: ULID? = nil,
        done: Date? = nil,
        archived: Date? = nil,
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
        self.anchor = anchor
        self.surface = surface?.truncatingSubsecond
        self.place = place
        self.geo = geo
        self.tags = tags
        self.color = color
        self.pinned = pinned
        self.body = body
        self.folder = MemoFolders.normalized(folder)
        self.preserved = preserved
        let marks = Marks(deleted: deleted, tidied: tidied, kept: kept, conflictOf: conflictOf, done: done, archived: archived)
        self.marks = marks == Marks.none ? Marks.none : marks
    }

    /// 화면에서 물러나 있는가 — 규칙이 치웠거나(`tidied`) 사람이 넣어 두었거나(`archived`). 둘 다 지운 것이 아니다.
    public var isPutAway: Bool { tidied != nil || archived != nil }

    /// 아직 할 일이 남았는가 — 칸이 남은 목록이거나, 다시 보기로 한 것이거나, 시각이 적힌 것. 끝냈으면 아니다.
    /// 「완료」 단추를 어디에 둘지는 이것이 정한다 — 그냥 글에 끝낼 것은 없다 (인계서 묶음 4).
    public var isActionable: Bool {
        guard done == nil else { return false }
        let boxes = MarkdownScanner.checkboxes(in: body)
        if !boxes.isEmpty { return boxes.contains(false) }
        return surface != nil || at != nil || due != nil
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

    /// 목록·창 제목에 쓸 한 줄. 본문에서 **글이 있는** 첫 줄의 마크다운 장식을 걷어낸다.
    ///
    /// 사진 참조(`![](attachments/…)`)는 글이 아니다 — 사진만 붙인 메모의 제목이
    /// 파일 경로여서는 안 된다. 그런 메모는 「사진 1장」이다. 링크는 이름만 남는다
    /// (`[이름](주소)` → 이름) — 맥에서 붙여 넣은 긴 지도 주소가 제목을 통째로
    /// 차지하던 것 (2026-09-17).
    public var title: String {
        let first = Self.textLines(of: body).first
        if let first { return first }
        let photos = photoCount
        return photos > 0 ? L("사진 \(photos)장") : L("빈 메모")
    }

    /// 제목에서 링크까지 뺀 것 — 「https://naver.me/… 밥약속」이면 「밥약속」. 링크뿐이면 빈 문자열.
    /// 자리 이름을 짐작해야 할 때 쓴다 (`RoutePlanner`) — 주소는 자리 이름이 아니다.
    public var titleWithoutLinks: String {
        guard let first = Self.textLines(of: body, keepingLinks: false).first else { return "" }
        return first
    }

    /// 목록의 둘째 줄 — 제목 다음에 오는 글. 사진 참조는 건너뛴다.
    public var previewLine: String? {
        Self.textLines(of: body).dropFirst().first
    }

    /// 본문이 물고 있는 사진 수.
    public var photoCount: Int { MarkdownScanner.imagePaths(in: body).count }

    /// 글이 있는 줄만, 사진 참조와 줄머리 장식을 걷어낸 채로. 링크는 이름만 남기거나(`keepingLinks`) 통째로 뺀다.
    /// 「## 가는 길」 절도 글이 아니다 — 비서가 적은 것이고 카드가 읽는다 (`RouteNote`).
    static func textLines(of body: String, keepingLinks: Bool = true) -> [String] {
        RouteNote.remove(from: body).split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let stripped = String(line)
                .replacing(/!\[[^\]]*\]\([^)]*\)/, with: "")
                .replacing(/\[([^\]]*)\]\([^)]*\)/, with: { keepingLinks ? String($0.1) : "" })
                .replacing(/https?:\/\/\S+/, with: { keepingLinks ? String($0.0) : "" })
                .trimmingCharacters(in: CharacterSet(charactersIn: "# \t-*>"))
                // 체크상자의 괄호는 글이 아니다 — 「- [ ] 우유」의 제목은 「우유」다.
                .replacing(/^\[[ xX]\][ \t]*/, with: "")
            return stripped.isEmpty ? nil : stripped
        }
    }
}
