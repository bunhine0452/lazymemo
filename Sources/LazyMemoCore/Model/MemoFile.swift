import Foundation

/// 마크다운 파일 ↔ `Memo` 변환 (설계문서 §5.2).
///
/// 파일이 정본이므로(D4) 이 변환은 손실이 없어야 한다. 앱이 모르는 frontmatter
/// 키도, 본문의 어떤 마크다운도 왕복 후 그대로 남는다.
public enum MemoFile {
    public static let fenceMarker = "---"
    public static let fileExtension = "md"

    public enum DecodingError: Error, Equatable, CustomStringConvertible {
        case missingFrontmatter
        case unterminatedFrontmatter
        case invalidIdentifier(String?)

        public var description: String {
            switch self {
            case .missingFrontmatter: L("frontmatter 가 없습니다 (`---` 로 시작해야 합니다)")
            case .unterminatedFrontmatter: L("frontmatter 가 닫히지 않았습니다")
            case .invalidIdentifier(let value): L("id 가 ULID 가 아닙니다: \(value ?? L("없음"))")
            }
        }
    }

    // MARK: 읽기

    public static func decode(_ text: String, fallbackID: ULID? = nil) throws -> Memo {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == fenceMarker else {
            throw DecodingError.missingFrontmatter
        }
        guard let closing = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == fenceMarker
        }) else {
            throw DecodingError.unterminatedFrontmatter
        }

        let frontmatter = Frontmatter.parse(lines[1..<closing].joined(separator: "\n"))
        let body = lines[(closing + 1)...]
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)

        // 파일명에서 온 id 를 폴백으로 받는다 — 사용자가 frontmatter 를 날려도
        // 메모의 정체성이 살아남는다.
        guard let id = frontmatter.string("id").flatMap(ULID.init) ?? fallbackID else {
            throw DecodingError.invalidIdentifier(frontmatter.string("id"))
        }

        let geo = frontmatter.string("geo").flatMap(Coordinate.init)
        // 읽지 못한 `geo` 는 우리가 이해하지 못한 필드다 — 아는 척 지우지 않고
        // `preserved` 로 보내 원문 그대로 되쓴다. 파일이 정본이기 때문이다 (D4).
        let known = (geo == nil && frontmatter["geo"] != nil)
            ? Memo.knownKeys.subtracting(["geo"])
            : Memo.knownKeys

        let created = frontmatter.string("created").flatMap(Timestamp.date(from:)) ?? Date()

        return Memo(
            id: id,
            created: created,
            // updated 가 없으면 created 로 떨어뜨린다. 지금 시각으로 채우면
            // 파일을 읽기만 해도 수정된 것처럼 보인다.
            updated: frontmatter.string("updated").flatMap(Timestamp.date(from:)) ?? created,
            due: frontmatter.string("due").flatMap(CalendarDate.init(iso:)),
            at: frontmatter.string("at").flatMap(Timestamp.date(from:)),
            every: frontmatter.string("every").flatMap(Recurrence.init),
            anchor: frontmatter.string("anchor").flatMap(CalendarDate.init(iso:)),
            surface: frontmatter.string("surface").flatMap(Timestamp.date(from:)),
            place: frontmatter.string("place"),
            geo: geo,
            tags: frontmatter.list("tags") ?? [],
            color: frontmatter.string("color").flatMap(MemoColor.init(rawValue:)) ?? .default,
            pinned: frontmatter.bool("pinned") ?? false,
            body: body,
            folder: frontmatter.string("folder"),
            deleted: frontmatter.string("deleted").flatMap(Timestamp.date(from:)),
            tidied: frontmatter.string("tidied").flatMap(Timestamp.date(from:)),
            kept: frontmatter.string("kept").flatMap(Timestamp.date(from:)),
            conflictOf: frontmatter.string("conflict").flatMap(ULID.init),
            done: frontmatter.string("done").flatMap(Timestamp.date(from:)),
            archived: frontmatter.string("archived").flatMap(Timestamp.date(from:)),
            preserved: frontmatter.excluding(known)
        )
    }

    // MARK: 쓰기

    public static func encode(_ memo: Memo, timeZone: TimeZone = .current) -> String {
        var lines: [String] = [fenceMarker]

        lines.append(Frontmatter.line(key: "id", scalar: memo.id.stringValue))
        lines.append(Frontmatter.line(key: "created", scalar: Timestamp.string(from: memo.created, timeZone: timeZone)))
        lines.append(Frontmatter.line(key: "updated", scalar: Timestamp.string(from: memo.updated, timeZone: timeZone)))

        if let due = memo.due {
            lines.append(Frontmatter.line(key: "due", scalar: due.description))
        }
        if let at = memo.at {
            lines.append(Frontmatter.line(key: "at", scalar: Timestamp.string(from: at, timeZone: timeZone)))
        }
        if let every = memo.every {
            lines.append(Frontmatter.line(key: "every", scalar: every.label))
        }
        if let anchor = memo.anchor {
            lines.append(Frontmatter.line(key: "anchor", scalar: anchor.description))
        }
        // 나올 때는 일이 언제인가 바로 다음이다 — 같은 종류의 값이라 붙여 둔다.
        if let surface = memo.surface {
            lines.append(Frontmatter.line(key: "surface", scalar: Timestamp.string(from: surface, timeZone: timeZone)))
        }
        // 시간을 먼저 적고 장소를 뒤에 적는다 — 줄 순서가 곧 이 앱의 우선순위다 (§14.2).
        if let place = memo.place {
            lines.append(Frontmatter.line(key: "place", scalar: place))
        }
        if let geo = memo.geo {
            lines.append(Frontmatter.line(key: "geo", scalar: geo.description))
        }
        if !memo.tags.isEmpty {
            lines.append(Frontmatter.line(key: "tags", list: memo.tags))
        }
        lines.append(Frontmatter.line(key: "color", scalar: memo.color.rawValue))
        lines.append(Frontmatter.line(key: "pinned", scalar: memo.pinned ? "true" : "false"))
        if let folder = memo.folder {
            lines.append(Frontmatter.line(key: "folder", scalar: folder))
        }
        if let deleted = memo.deleted {
            lines.append(Frontmatter.line(key: "deleted", scalar: Timestamp.string(from: deleted, timeZone: timeZone)))
        }
        if let tidied = memo.tidied {
            lines.append(Frontmatter.line(key: "tidied", scalar: Timestamp.string(from: tidied, timeZone: timeZone)))
        }
        if let kept = memo.kept {
            lines.append(Frontmatter.line(key: "kept", scalar: Timestamp.string(from: kept, timeZone: timeZone)))
        }
        if let conflictOf = memo.conflictOf {
            lines.append(Frontmatter.line(key: "conflict", scalar: conflictOf.stringValue))
        }
        if let done = memo.done {
            lines.append(Frontmatter.line(key: "done", scalar: Timestamp.string(from: done, timeZone: timeZone)))
        }
        if let archived = memo.archived {
            lines.append(Frontmatter.line(key: "archived", scalar: Timestamp.string(from: archived, timeZone: timeZone)))
        }

        // 모르는 필드는 원문 그대로. 이해하지 못한 것을 다시 쓰려 하지 않는다.
        for entry in memo.preserved {
            lines.append(contentsOf: entry.rawLines)
        }

        lines.append(fenceMarker)
        lines.append(memo.body)

        return lines.joined(separator: "\n") + "\n"
    }

    /// `<ulid>.md`
    public static func fileName(for id: ULID) -> String {
        "\(id.stringValue).\(fileExtension)"
    }

    /// 파일명에서 id 를 되읽는다. 인덱스 없이 파일만 보고 복구할 때 쓴다.
    public static func identifier(fromFileName name: String) -> ULID? {
        guard name.hasSuffix("." + fileExtension) else { return nil }
        return ULID(String(name.dropLast(fileExtension.count + 1)))
    }
}
