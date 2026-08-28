import Foundation

/// 인덱스에 담긴 메모 한 줄 — 본문을 뺀 메타데이터.
public struct MemoIndexEntry: Sendable, Equatable {
    public let id: ULID
    /// Vault 기준 상대 경로. 절대 경로를 넣으면 Vault 를 옮기는 순간 전부 무효가 된다.
    public let relativePath: String
    public let created: Date
    public let updated: Date
    public let due: CalendarDate?
    public let at: Date?
    public let color: MemoColor
    public let pinned: Bool
    public let modifiedAt: Date
}

/// 마크다운 정본에서 파생된 조회용 인덱스 (설계문서 §5.3).
///
/// **불변식: 여기에만 존재하는 정보를 만들지 않는다.** 파일 전체를 다시 훑으면
/// 언제든 똑같이 재생성되어야 한다. 그래서 이 타입에는 "쓰기" API 가 없고
/// `MemoVault` 가 파일에 먼저 쓴 결과를 통지받기만 한다.
public actor MemoIndex {
    /// 스키마가 바뀌면 올린다. 다르면 통째로 버리고 다시 만든다 — 파생물이라
    /// 마이그레이션을 쓸 이유가 없다.
    private static let schemaVersion = 1

    /// FTS5 trigram 토크나이저는 3글자 미만을 색인하지 않는다.
    /// "병원" 같은 두 글자 한국어 검색이 흔하므로 그 아래는 LIKE 로 떨어뜨린다.
    private static let minimumTrigramLength = 3

    private let database: SQLiteDatabase
    private let location: URL

    public init(path: URL) throws {
        self.location = path
        do {
            self.database = try Self.open(path)
        } catch {
            // 인덱스는 파생물이다 (§5.3) — 고치려 들지 않고 버리고 새로 만든다.
            // 실제로 걸리는 경우: 사용자가 index.sqlite 만 지우고 WAL 사이드카
            // (-wal / -shm)를 남겨 두면 sqlite 가 열리지 않는다.
            Self.discard(at: path)
            self.database = try Self.open(path)
        }
    }

    private static func open(_ path: URL) throws -> SQLiteDatabase {
        let database = try SQLiteDatabase(path: path.path(percentEncoded: false))
        try migrate(database)
        return database
    }

    /// 인덱스 파일과 그 사이드카를 통째로 지운다.
    private static func discard(at path: URL) {
        let base = path.path(percentEncoded: false)
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: base + suffix)
        }
    }

    /// actor 초기화 중에는 격리 메서드를 부를 수 없어 static 으로 둔다.
    private static func migrate(_ database: SQLiteDatabase) throws {
        if database.userVersion != Self.schemaVersion {
            try database.execute("DROP TABLE IF EXISTS memos; DROP TABLE IF EXISTS memos_fts;")
        }
        try database.execute("""
            CREATE TABLE IF NOT EXISTS memos (
                id          TEXT PRIMARY KEY,
                path        TEXT NOT NULL,
                created     REAL NOT NULL,
                updated     REAL NOT NULL,
                due         TEXT,
                at          REAL,
                color       TEXT NOT NULL,
                pinned      INTEGER NOT NULL,
                mtime       REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS memos_due_idx ON memos(due);
            CREATE INDEX IF NOT EXISTS memos_at_idx  ON memos(at);
            CREATE INDEX IF NOT EXISTS memos_upd_idx ON memos(updated DESC);
            CREATE VIRTUAL TABLE IF NOT EXISTS memos_fts
                USING fts5(body, id UNINDEXED, tokenize='trigram');
            """)
        database.userVersion = Self.schemaVersion
    }

    // MARK: 갱신

    public func upsert(_ memo: Memo, relativePath: String, modifiedAt: Date) throws {
        try database.transaction {
            let statement = try database.prepare("""
                INSERT INTO memos (id, path, created, updated, due, at, color, pinned, mtime)
                VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
                ON CONFLICT(id) DO UPDATE SET
                    path = ?2, created = ?3, updated = ?4, due = ?5,
                    at = ?6, color = ?7, pinned = ?8, mtime = ?9
                """)
            statement.bind(1, memo.id.stringValue)
            statement.bind(2, relativePath)
            statement.bind(3, memo.created.timeIntervalSince1970)
            statement.bind(4, memo.updated.timeIntervalSince1970)
            statement.bind(5, memo.due?.description)
            statement.bind(6, memo.at?.timeIntervalSince1970)
            statement.bind(7, memo.color.rawValue)
            statement.bind(8, memo.pinned ? 1 : 0)
            statement.bind(9, modifiedAt.timeIntervalSince1970)
            try statement.step()

            try replaceFullText(id: memo.id, body: memo.body)
        }
    }

    public func remove(_ id: ULID) throws {
        try database.transaction {
            for sql in ["DELETE FROM memos WHERE id = ?1", "DELETE FROM memos_fts WHERE id = ?1"] {
                let statement = try database.prepare(sql)
                statement.bind(1, id.stringValue)
                try statement.step()
            }
        }
    }

    public func removeAll() throws {
        try database.execute("DELETE FROM memos; DELETE FROM memos_fts;")
    }

    private func replaceFullText(id: ULID, body: String) throws {
        let delete = try database.prepare("DELETE FROM memos_fts WHERE id = ?1")
        delete.bind(1, id.stringValue)
        try delete.step()

        let insert = try database.prepare("INSERT INTO memos_fts (body, id) VALUES (?1, ?2)")
        insert.bind(1, body)
        insert.bind(2, id.stringValue)
        try insert.step()
    }

    // MARK: 조회

    /// id → 파일 수정 시각. 기동 시 파일 mtime 과 대조해 변경분만 갱신한다 (§5.3).
    public func fingerprints() throws -> [ULID: Date] {
        let statement = try database.prepare("SELECT id, mtime FROM memos")
        var result: [ULID: Date] = [:]
        while try statement.step() {
            guard let raw = statement.string(0), let id = ULID(raw),
                  let mtime = statement.double(1) else { continue }
            result[id] = Date(timeIntervalSince1970: mtime)
        }
        return result
    }

    public func all(limit: Int = 1000) throws -> [MemoIndexEntry] {
        let statement = try database.prepare("""
            SELECT id, path, created, updated, due, at, color, pinned, mtime
            FROM memos ORDER BY pinned DESC, updated DESC LIMIT ?1
            """)
        statement.bind(1, limit)
        return try collect(statement)
    }

    /// 날짜 범위 안의 일정. 캘린더의 "이번 달" 쿼리가 이 경로를 탄다 (§10).
    public func scheduled(from: CalendarDate, to: CalendarDate, calendar: Calendar = .current) throws -> [MemoIndexEntry] {
        // `at` 은 시각까지 있는 값이라 날짜 문자열로 비교할 수 없다.
        // 범위 끝날의 다음 자정을 상한으로 잡는다.
        let lower = from.startOfDay(calendar: calendar)?.timeIntervalSince1970
        let upper = to.startOfDay(calendar: calendar)
            .flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }?
            .timeIntervalSince1970

        let statement = try database.prepare("""
            SELECT id, path, created, updated, due, at, color, pinned, mtime
            FROM memos
            WHERE (due IS NOT NULL AND due >= ?1 AND due <= ?2)
               OR (at  IS NOT NULL AND at  >= ?3 AND at  <  ?4)
            ORDER BY COALESCE(at, 0) ASC, due ASC
            """)
        statement.bind(1, from.description)
        statement.bind(2, to.description)
        statement.bind(3, lower)
        statement.bind(4, upper)
        return try collect(statement)
    }

    /// 전문 검색. 짧은 질의는 trigram 이 색인하지 못하므로 LIKE 로 훑는다.
    public func search(_ query: String, limit: Int = 50) throws -> [MemoIndexEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try all(limit: limit) }

        let statement: SQLiteDatabase.Statement
        if trimmed.count >= Self.minimumTrigramLength {
            statement = try database.prepare("""
                SELECT m.id, m.path, m.created, m.updated, m.due, m.at, m.color, m.pinned, m.mtime
                FROM memos_fts f JOIN memos m ON m.id = f.id
                WHERE memos_fts MATCH ?1
                ORDER BY m.pinned DESC, m.updated DESC LIMIT ?2
                """)
            // 구문 문자를 해석시키지 않도록 통째로 구(phrase)로 감싼다.
            statement.bind(1, "\"" + trimmed.replacingOccurrences(of: "\"", with: "\"\"") + "\"")
        } else {
            statement = try database.prepare("""
                SELECT m.id, m.path, m.created, m.updated, m.due, m.at, m.color, m.pinned, m.mtime
                FROM memos_fts f JOIN memos m ON m.id = f.id
                WHERE f.body LIKE ?1 ESCAPE '\\'
                ORDER BY m.pinned DESC, m.updated DESC LIMIT ?2
                """)
            statement.bind(1, "%" + escapeLike(trimmed) + "%")
        }
        statement.bind(2, limit)
        return try collect(statement)
    }

    private func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private func collect(_ statement: SQLiteDatabase.Statement) throws -> [MemoIndexEntry] {
        var result: [MemoIndexEntry] = []
        while try statement.step() {
            guard let rawID = statement.string(0), let id = ULID(rawID),
                  let path = statement.string(1),
                  let created = statement.double(2),
                  let updated = statement.double(3),
                  let color = statement.string(6).flatMap(MemoColor.init(rawValue:)),
                  let mtime = statement.double(8)
            else { continue }

            result.append(MemoIndexEntry(
                id: id,
                relativePath: path,
                created: Date(timeIntervalSince1970: created),
                updated: Date(timeIntervalSince1970: updated),
                due: statement.string(4).flatMap(CalendarDate.init(iso:)),
                at: statement.double(5).map(Date.init(timeIntervalSince1970:)),
                color: color,
                pinned: statement.int(7) != 0,
                modifiedAt: Date(timeIntervalSince1970: mtime)
            ))
        }
        return result
    }
}
