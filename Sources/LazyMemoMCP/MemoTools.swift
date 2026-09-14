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
                "description": L("""
                    메모를 검색하거나 나열한다. 날짜 범위를 주면 그 기간의 일정을 돌려준다. \
                    lazymemo 에서는 메모와 일정이 같은 것이라, due(날짜) 또는 at(시각) 필드가 \
                    채워진 메모가 곧 캘린더 항목이다.
                    """),
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": L("본문 검색어")],
                        "tag": ["type": "string", "description": L("이 태그를 가진 메모만")],
                        "place": ["type": "string", "description": L("장소 이름에 이 말이 들어간 메모만 (예: 강남)")],
                        "folder": ["type": "string", "description": L("이 폴더에 넣어 둔 메모만. 폴더 이름은 list_folders 로 얻는다")],
                        "from": ["type": "string", "description": L("일정 시작일 YYYY-MM-DD")],
                        "to": ["type": "string", "description": L("일정 종료일 YYYY-MM-DD")],
                        "limit": ["type": "integer", "description": L("최대 개수 (기본 30)")],
                    ],
                ],
            ],
            [
                "name": "create_memo",
                "description": L("""
                    새 메모를 만든다. 약속처럼 시각이 정해진 것은 at 에, 마감이나 목표처럼 \
                    날짜만 있는 것은 due 에 넣으면 캘린더에도 나타난다. 둘 다 비우면 그냥 메모다. \
                    place 는 어디인지를 적는 칸이며, 날짜와 달리 메모가 놓이는 자리를 바꾸지 않는다 \
                    — 바탕화면의 종이에 장소가 함께 적힐 뿐이다.
                    """),
                "inputSchema": [
                    "type": "object",
                    "required": ["text"],
                    "properties": [
                        "text": ["type": "string", "description": L("메모 본문 (마크다운)")],
                        "due": ["type": "string", "description": L("마감일 YYYY-MM-DD")],
                        "at": ["type": "string", "description": L("약속 시각 ISO8601 (예: 2026-09-01T14:00:00+09:00)")],
                        "every": [
                            "type": "string",
                            "enum": Recurrence.allCases.map(\.label),
                            "description": L("되풀이하는 일이면 주기. 언제인지는 due/at 이 들고 있고, 그 회차가 지나면 앱이 다음 회차로 옮긴다"),
                        ],
                        "surface_at": [
                            "type": "string",
                            "description": L("이 메모가 바탕화면에 나올 시각 ISO8601. 일정(at)과 다른 것을 말한다 — 회의는 3시, 종이는 2시 30분"),
                        ],
                        "place": ["type": "string", "description": L("장소 이름 (예: 강남역 3번 출구). 사람이 읽는 말 그대로")],
                        "geo": ["type": "string", "description": L("좌표 위도,경도 (예: 37.4979,127.0276). 선택 — 없으면 이름으로 지도를 찾는다")],
                        "tags": ["type": "array", "items": ["type": "string"]],
                        "color": [
                            "type": "string",
                            "enum": MemoColor.allCases.map(\.rawValue),
                        ],
                        "folder": [
                            "type": "string",
                            "description": L("서랍의 폴더 이름. 넣으면 메모가 바탕화면 대신 서랍의 그 칸으로 간다. 없는 이름이면 폴더가 새로 생긴다"),
                        ],
                    ],
                ],
            ],
            [
                "name": "update_memo",
                "description": L("기존 메모를 고친다. 넘기지 않은 필드는 그대로 둔다. 날짜를 지우려면 빈 문자열을 넘긴다."),
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": [
                        "id": ["type": "string", "description": L("메모 id (ULID)")],
                        "text": ["type": "string"],
                        "due": ["type": "string", "description": L("YYYY-MM-DD, 빈 문자열이면 삭제")],
                        "at": ["type": "string", "description": L("ISO8601, 빈 문자열이면 삭제")],
                        "every": [
                            "type": "string",
                            "description": L("되풀이 주기(매일·매주·매월·매년), 빈 문자열이면 삭제"),
                        ],
                        "surface_at": ["type": "string", "description": L("나올 시각 ISO8601, 빈 문자열이면 삭제")],
                        "place": ["type": "string", "description": L("장소 이름, 빈 문자열이면 삭제")],
                        "geo": ["type": "string", "description": L("위도,경도. 빈 문자열이면 삭제")],
                        "tags": ["type": "array", "items": ["type": "string"]],
                        "color": ["type": "string", "enum": MemoColor.allCases.map(\.rawValue)],
                        "pinned": ["type": "boolean"],
                        "folder": ["type": "string", "description": L("서랍의 폴더 이름. 빈 문자열이면 폴더에서 뺀다")],
                    ],
                ],
            ],
            [
                "name": "list_folders",
                "description": L("서랍의 폴더 이름과 각 폴더에 든 메모 수를 나열한다. create_memo·update_memo 의 folder 에 넘길 이름을 여기서 얻는다."),
                "inputSchema": ["type": "object", "properties": [:]],
            ],
            [
                "name": "surface_memo",
                "description": L("""
                    이 메모가 바탕화면에 **나올 시각**을 정한다. 일정을 바꾸지 않는다 — \
                    회의는 3시 그대로 두고 종이만 2시 30분에 앞으로 꺼낼 때 쓴다. \
                    일정이 없는 메모에도 쓸 수 있다("금요일 아침에 이거 다시 보여줘"). \
                    시스템 알림이 아니라 바탕화면의 종이가 앞으로 나오는 것이다.
                    """),
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": [
                        "id": ["type": "string", "description": L("메모 id (ULID)")],
                        "at": [
                            "type": "string",
                            "description": L("나올 시각 ISO8601. 빈 문자열이면 다시 일정 시각에 나온다"),
                        ],
                    ],
                ],
            ],
            [
                "name": "delete_memo",
                "description": L("""
                    메모를 휴지통으로 옮긴다. 파일은 지워지지 않으며 restore_memo 로 되돌릴 수 있다. \
                    영구 삭제하는 방법은 제공되지 않는다.
                    """),
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": ["id": ["type": "string"]],
                ],
            ],
            [
                "name": "restore_memo",
                "description": L("휴지통에 있는 메모를 되돌린다."),
                "inputSchema": [
                    "type": "object",
                    "required": ["id"],
                    "properties": ["id": ["type": "string"]],
                ],
            ],
            [
                "name": "list_trash",
                "description": L("휴지통에 있는 메모를 나열한다. restore_memo 에 넘길 id 를 여기서 얻는다."),
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
            case .unknownTool(let name): L("알 수 없는 도구입니다: \(name)")
            case .missing(let field): L("\(field) 이(가) 필요합니다")
            case .malformed(let field, let value): L("\(field) 형식이 잘못되었습니다: \(value)")
            }
        }
    }

    func call(_ name: String, arguments: [String: Any]) async throws -> String {
        switch name {
        case "list_memos": try await listMemos(arguments)
        case "create_memo": try await createMemo(arguments)
        case "update_memo": try await updateMemo(arguments)
        case "surface_memo": try await surfaceMemo(arguments)
        case "delete_memo": try await deleteMemo(arguments)
        case "restore_memo": try await restoreMemo(arguments)
        case "list_trash": try await listTrash()
        case "list_folders": try await listFolders()
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
        // "강남에서 할 일 뭐 있어?" — 부분일치면 충분하다. 사람은 «강남역 3번 출구» 를
        // 통째로 기억해서 묻지 않는다.
        if let place = arguments["place"] as? String, !place.isEmpty {
            memos = memos.filter { $0.place?.localizedCaseInsensitiveContains(place) ?? false }
        }
        if let folder = MemoFolders.normalized(arguments["folder"] as? String) {
            memos = MemoFolders.filter(memos, folder: folder)
        }

        return encode(Array(memos.prefix(limit)))
    }

    private func createMemo(_ arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else { throw Failure.missing("text") }

        let memo = try await service.create(
            body: text,
            due: try calendarDate(arguments["due"], field: "due") ?? nil,
            at: try timestamp(arguments["at"], field: "at") ?? nil,
            every: try recurrence(arguments["every"]) ?? nil,
            surface: try timestamp(arguments["surface_at"], field: "surface_at") ?? nil,
            place: (arguments["place"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            geo: try coordinate(arguments["geo"], field: "geo") ?? nil,
            tags: arguments["tags"] as? [String] ?? [],
            color: (arguments["color"] as? String).flatMap(MemoColor.init(rawValue:)) ?? .default,
            folder: MemoFolders.normalized(arguments["folder"] as? String)
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
            every: try recurrence(arguments["every"]),
            surface: try timestamp(arguments["surface_at"], field: "surface_at"),
            place: optionalText(arguments["place"]),
            geo: try coordinate(arguments["geo"], field: "geo"),
            tags: arguments["tags"] as? [String],
            color: (arguments["color"] as? String).flatMap(MemoColor.init(rawValue:)),
            pinned: arguments["pinned"] as? Bool,
            folder: optionalText(arguments["folder"])
        )
        return encode([memo])
    }

    /// 나올 시각만 고친다. **일정은 건드리지 않는다** — 그 둘이 한 도구에 섞이면
    /// 모델이 「30분 전에 띄워줘」를 「30분 앞당겨줘」로 실행하는 날이 온다.
    private func surfaceMemo(_ arguments: [String: Any]) async throws -> String {
        let memo = try await service.update(
            try identifier(arguments),
            surface: try timestamp(arguments["at"], field: "at") ?? .some(nil)
        )
        return encode([memo])
    }

    private func deleteMemo(_ arguments: [String: Any]) async throws -> String {
        let memo = try await service.delete(try identifier(arguments))
        return L("휴지통으로 옮겼습니다. restore_memo 로 되돌릴 수 있습니다.") + "\n" + encode([memo])
    }

    private func restoreMemo(_ arguments: [String: Any]) async throws -> String {
        let memo = try await service.restore(try identifier(arguments))
        return encode([memo])
    }

    private func listTrash() async throws -> String {
        encode(try await service.trashed())
    }

    /// 폴더는 메모의 이름표에서 읽는다 (`MemoFolders`). 차례와 빈 폴더는
    /// 앱의 설정이 알지만 여기서는 파일이 아는 것만 말한다 — 이 프로세스는
    /// 설정 파일을 열지 않는다.
    private func listFolders() async throws -> String {
        let memos = try await service.all()
        let counts = MemoFolders.counts(in: memos)
        let objects: [[String: Any]] = MemoFolders.names(listed: nil, memos: memos).map {
            ["name": $0, "count": counts[$0] ?? 0]
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: objects, options: [.prettyPrinted, .withoutEscapingSlashes]
        ), let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
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

    private func optionalText(_ value: Any?) -> String?? {
        guard let raw = value as? String else { return nil }
        return raw.isEmpty ? .some(nil) : .some(raw)
    }

    private func recurrence(_ value: Any?) throws -> Recurrence?? {
        guard let raw = value as? String else { return nil }
        if raw.isEmpty { return .some(nil) }
        guard let every = Recurrence(raw) else { throw Failure.malformed("every", raw) }
        return .some(every)
    }

    private func coordinate(_ value: Any?, field: String) throws -> Coordinate?? {
        guard let raw = value as? String else { return nil }
        if raw.isEmpty { return .some(nil) }
        guard let point = Coordinate(raw) else { throw Failure.malformed(field, raw) }
        return .some(point)
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
            if let every = memo.every { object["every"] = every.label }
            if let surface = memo.surface { object["surface_at"] = Timestamp.string(from: surface) }
            if let place = memo.place { object["place"] = place }
            if let geo = memo.geo { object["geo"] = geo.description }
            if !memo.tags.isEmpty { object["tags"] = memo.tags }
            if let folder = memo.folder { object["folder"] = folder }
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
