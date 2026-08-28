import Foundation
import LazyMemoCore

/// lazymemo 가 Claude 에게 내주는 도구들 (설계문서 §9.2).
///
/// **하드 삭제 도구가 없다.** `delete_memo` 는 휴지통 이동까지만 하고,
/// 되돌릴 수 없는 삭제는 앱이 보존 기간에 따라 수행한다 (D6). 이는 규약이
/// 아니라 배선이다 — `MemoService` 자체에 하드 삭제 공개 API 가 없다.
struct MemoTools {
    let service: MemoService

    // MARK: 도구 목록

    static var definitions: [[String: Any]] {
        [
            [
                "name": "list_memos",
                "description": """
                    메모를 검색하거나 나열한다. 날짜 범위를 주면 그 기간의 일정을 돌려준다. \
                    lazymemo 에서는 메모와 일정이 같은 것이라, due(날짜) 또는 at(시각) 필드가 \
                    채워진 메모가 곧 캘린더 항목이다.
                    """,
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "본문 검색어"],
                        "tag": ["type": "string", "description": "이 태그를 가진 메모만"],
                        "from": ["type": "string", "description": "일정 시작일 YYYY-MM-DD"],
                        "to": ["type": "string", "description": "일정 종료일 YYYY-MM-DD"],
                        "limit": ["type": "integer", "description": "최대 개수 (기본 30)"],
                    ],
                ],
            ],
            [
                "name": "create_memo",
                "description": """
                    새 메모를 만든다. 약속처럼 시각이 정해진 것은 at 에, 마감이나 목표처럼 \
                    날짜만 있는 것은 due 에 넣으면 캘린더에도 나타난다. 둘 다 비우면 그냥 메모다.
                    """,
                "inputSchema": [
                    "type": "object",
                    "required": ["text"],
                    "properties": [
                        "text": ["type": "string", "description": "메모 본문 (마크다운)"],
                        "due": ["type": "string", "description": "마감일 YYYY-MM-DD"],
                        "at": ["type": "string", "description": "약속 시각 ISO8601 (예: 2026-09-01T14:00:00+09:00)"],
                        "tags": ["type": "array", "items": ["type": "string"]],
                        "color": [
                            "type": "string",
                            "enum": MemoColor.allCases.map(\.rawValue),
                        ],
                    ],
                ],
            ],
            [
                "name": "update_memo",
                "description": "기존 메모를 고친다. 넘기지 않은 필드는 그대로 둔다. 날짜를 지우려면 빈 문자열을 넘긴다.",
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": [
                        "id": ["type": "string", "description": "메모 id (ULID)"],
                        "text": ["type": "string"],
                        "due": ["type": "string", "description": "YYYY-MM-DD, 빈 문자열이면 삭제"],
                        "at": ["type": "string", "description": "ISO8601, 빈 문자열이면 삭제"],
                        "tags": ["type": "array", "items": ["type": "string"]],
                        "color": ["type": "string", "enum": MemoColor.allCases.map(\.rawValue)],
                        "pinned": ["type": "boolean"],
                    ],
                ],
            ],
            [
                "name": "delete_memo",
                "description": """
                    메모를 휴지통으로 옮긴다. 파일은 지워지지 않으며 restore_memo 로 되돌릴 수 있다. \
                    영구 삭제하는 방법은 제공되지 않는다.
                    """,
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": ["id": ["type": "string"]],
                ],
            ],
            [
                "name": "restore_memo",
                "description": "휴지통에 있는 메모를 되돌린다.",
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": ["id": ["type": "string"]],
                ],
            ],
            [
                "name": "list_trash",
                "description": "휴지통에 있는 메모를 나열한다. restore_memo 에 넘길 id 를 여기서 얻는다.",
                "inputSchema": ["type": "object", "properties": [:]],
            ],
        ]
    }

    // MARK: 실행

    enum Failure: Error, CustomStringConvertible {
        case unknownTool(String)
        case missing(String)
        case malformed(String, String)

        var description: String {
            switch self {
            case .unknownTool(let name): "알 수 없는 도구입니다: \(name)"
            case .missing(let field): "\(field) 이(가) 필요합니다"
            case .malformed(let field, let value): "\(field) 형식이 잘못되었습니다: \(value)"
            }
        }
    }

    func call(_ name: String, arguments: [String: Any]) async throws -> String {
        switch name {
        case "list_memos": try await listMemos(arguments)
        case "create_memo": try await createMemo(arguments)
        case "update_memo": try await updateMemo(arguments)
        case "delete_memo": try await deleteMemo(arguments)
        case "restore_memo": try await restoreMemo(arguments)
        case "list_trash": try await listTrash()
        default: throw Failure.unknownTool(name)
        }
    }

    private func listMemos(_ arguments: [String: Any]) async throws -> String {
        let limit = arguments["limit"] as? Int ?? 30

        var memos: [Memo]
        if let from = arguments["from"] as? String, let to = arguments["to"] as? String {
            guard let start = CalendarDate(iso: from) else { throw Failure.malformed("from", from) }
            guard let end = CalendarDate(iso: to) else { throw Failure.malformed("to", to) }
            memos = try await service.scheduled(from: start, to: end)
        } else if let query = arguments["query"] as? String, !query.isEmpty {
            memos = try await service.search(query, limit: limit)
        } else {
            memos = try await service.all()
        }

        if let tag = arguments["tag"] as? String, !tag.isEmpty {
            memos = memos.filter { $0.tags.contains(tag) }
        }

        return encode(Array(memos.prefix(limit)))
    }

    private func createMemo(_ arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else { throw Failure.missing("text") }

        let memo = try await service.create(
            body: text,
            due: try calendarDate(arguments["due"], field: "due") ?? nil,
            at: try timestamp(arguments["at"], field: "at") ?? nil,
            tags: arguments["tags"] as? [String] ?? [],
            color: (arguments["color"] as? String).flatMap(MemoColor.init(rawValue:)) ?? .default
        )
        return encode([memo])
    }

    private func updateMemo(_ arguments: [String: Any]) async throws -> String {
        let id = try identifier(arguments)

        let memo = try await service.update(
            id,
            body: arguments["text"] as? String,
            due: try calendarDate(arguments["due"], field: "due"),
            at: try timestamp(arguments["at"], field: "at"),
            tags: arguments["tags"] as? [String],
            color: (arguments["color"] as? String).flatMap(MemoColor.init(rawValue:)),
            pinned: arguments["pinned"] as? Bool
        )
        return encode([memo])
    }

    private func deleteMemo(_ arguments: [String: Any]) async throws -> String {
        let memo = try await service.delete(try identifier(arguments))
        return "휴지통으로 옮겼습니다. restore_memo 로 되돌릴 수 있습니다.\n" + encode([memo])
    }

    private func restoreMemo(_ arguments: [String: Any]) async throws -> String {
        let memo = try await service.restore(try identifier(arguments))
        return encode([memo])
    }

    private func listTrash() async throws -> String {
        encode(try await service.trashed())
    }

    // MARK: 인자 해석

    private func identifier(_ arguments: [String: Any]) throws -> ULID {
        guard let raw = arguments["id"] as? String else { throw Failure.missing("id") }
        guard let id = ULID(raw) else { throw Failure.malformed("id", raw) }
        return id
    }

    /// 이중 옵셔널이 그대로 의미를 나른다.
    /// `nil` = 인자 없음(건드리지 않음) · `.some(nil)` = 빈 문자열(지움).
    private func calendarDate(_ value: Any?, field: String) throws -> CalendarDate?? {
        guard let raw = value as? String else { return nil }
        if raw.isEmpty { return .some(nil) }
        guard let date = CalendarDate(iso: raw) else { throw Failure.malformed(field, raw) }
        return .some(date)
    }

    private func timestamp(_ value: Any?, field: String) throws -> Date?? {
        guard let raw = value as? String else { return nil }
        if raw.isEmpty { return .some(nil) }
        guard let date = Timestamp.date(from: raw) else { throw Failure.malformed(field, raw) }
        return .some(date)
    }

    // MARK: 출력

    /// LLM 이 다시 도구를 부를 때 쓸 수 있도록 id 를 반드시 포함한다.
    private func encode(_ memos: [Memo]) -> String {
        let objects: [[String: Any]] = memos.map { memo in
            var object: [String: Any] = [
                "id": memo.id.stringValue,
                "text": memo.body,
                "created": Timestamp.string(from: memo.created),
                "updated": Timestamp.string(from: memo.updated),
                "color": memo.color.rawValue,
                "pinned": memo.pinned,
            ]
            if let due = memo.due { object["due"] = due.description }
            if let at = memo.at { object["at"] = Timestamp.string(from: at) }
            if !memo.tags.isEmpty { object["tags"] = memo.tags }
            if let deleted = memo.deleted { object["deleted"] = Timestamp.string(from: deleted) }
            return object
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: objects, options: [.prettyPrinted, .withoutEscapingSlashes]
        ), let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }
}
