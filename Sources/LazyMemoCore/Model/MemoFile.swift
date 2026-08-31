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
            case .missingFrontmatter: "frontmatter 가 없습니다 (`---` 로 시작해야 합니다)"
            case .unterminatedFrontmatter: "frontmatter 가 닫히지 않았습니다"
            case .invalidIdentifier(let value): "id 가 ULID 가 아닙니다: \(value ?? "없음")"
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

        let created = frontmatter.string("created").flatMap(Timestamp.date(from:)) ?? Date()

        return Memo(
            id: id,
            created: created,
            // updated 가 없으면 created 로 떨어뜨린다. 지금 시각으로 채우면
            // 파일을 읽기만 해도 수정된 것처럼 보인다.
            updated: frontmatter.string("updated").flatMap(Timestamp.date(from:)) ?? created,
            due: frontmatter.string("due").flatMap(CalendarDate.init(iso:)),
            at: frontmatter.string("at").flatMap(Timestamp.date(from:)),
            tags: frontmatter.list("tags") ?? [],
            color: frontmatter.string("color").flatMap(MemoColor.init(rawValue:)) ?? .default,
            pinned: frontmatter.bool("pinned") ?? false,
            body: body,
            deleted: frontmatter.string("deleted").flatMap(Timestamp.date(from:)),
            tidied: frontmatter.string("tidied").flatMap(Timestamp.date(from:)),
            preserved: frontmatter.excluding(Memo.knownKeys)
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
        if !memo.tags.isEmpty {
            lines.append(Frontmatter.line(key: "tags", list: memo.tags))
        }
        lines.append(Frontmatter.line(key: "color", scalar: memo.color.rawValue))
        lines.append(Frontmatter.line(key: "pinned", scalar: memo.pinned ? "true" : "false"))
        if let deleted = memo.deleted {
            lines.append(Frontmatter.line(key: "deleted", scalar: Timestamp.string(from: deleted, timeZone: timeZone)))
        }
        if let tidied = memo.tidied {
            lines.append(Frontmatter.line(key: "tidied", scalar: Timestamp.string(from: tidied, timeZone: timeZone)))
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
