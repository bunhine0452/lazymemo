import Foundation
import SQLite3

/// libsqlite3 위의 얇은 껍데기.
///
/// 외부 의존성을 들이지 않는다 — 인덱스는 파생물이라(D4) 언제든 버리고
/// 다시 만들 수 있고, 그 정도 쓰임에 ORM 을 얹을 이유가 없다.
final class SQLiteDatabase {
    struct Failure: Error, CustomStringConvertible {
        let code: Int32
        let message: String
        var description: String { "SQLite(\(code)): \(message)" }
    }

    /// 바인딩한 문자열을 sqlite 가 복사하게 한다. 생략하면 Swift 쪽 버퍼가
    /// 먼저 해제돼 쓰레기 값이 저장된다.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var handle: OpaquePointer?

    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let code = sqlite3_open_v2(path, &handle, flags, nil)
        guard code == SQLITE_OK, handle != nil else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "열 수 없음"
            sqlite3_close_v2(handle)
            throw Failure(code: code, message: message)
        }
        // 앱이 죽어도 인덱스가 깨지지 않게. 파생물이라 잃어도 되지만,
        // 깨진 파일이 남아 기동을 막는 쪽이 더 나쁘다.
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
    }

    deinit { sqlite3_close_v2(handle) }

    var userVersion: Int {
        get {
            guard let statement = try? prepare("PRAGMA user_version;"),
                  (try? statement.step()) == true else { return 0 }
            return statement.int(0)
        }
        set { try? execute("PRAGMA user_version = \(newValue);") }
    }

    func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(handle, sql, nil, nil, &errorPointer)
        guard code == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "알 수 없는 오류"
            sqlite3_free(errorPointer)
            throw Failure(code: code, message: message)
        }
    }

    func prepare(_ sql: String) throws -> Statement {
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard code == SQLITE_OK, let statement else {
            throw Failure(code: code, message: String(cString: sqlite3_errmsg(handle)))
        }
        return Statement(handle: statement, database: handle)
    }

    /// 여러 쓰기를 한 트랜잭션으로 묶는다. 던지면 통째로 되돌린다.
    func transaction<T>(_ work: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE;")
        do {
            let result = try work()
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    final class Statement {
        private let handle: OpaquePointer
        private let database: OpaquePointer?

        fileprivate init(handle: OpaquePointer, database: OpaquePointer?) {
            self.handle = handle
            self.database = database
        }

        deinit { sqlite3_finalize(handle) }

        // MARK: 바인딩 — 인덱스는 1부터다

        func bind(_ index: Int32, _ value: String?) {
            if let value {
                sqlite3_bind_text(handle, index, value, -1, SQLiteDatabase.transient)
            } else {
                sqlite3_bind_null(handle, index)
            }
        }

        func bind(_ index: Int32, _ value: Double?) {
            if let value { sqlite3_bind_double(handle, index, value) }
            else { sqlite3_bind_null(handle, index) }
        }

        func bind(_ index: Int32, _ value: Int?) {
            if let value { sqlite3_bind_int64(handle, index, Int64(value)) }
            else { sqlite3_bind_null(handle, index) }
        }

        // MARK: 실행

        /// 행이 나왔으면 true, 다 읽었으면 false.
        @discardableResult
        func step() throws -> Bool {
            let code = sqlite3_step(handle)
            switch code {
            case SQLITE_ROW: return true
            case SQLITE_DONE: return false
            default: throw Failure(code: code, message: String(cString: sqlite3_errmsg(database)))
            }
        }

        func reset() {
            sqlite3_reset(handle)
            sqlite3_clear_bindings(handle)
        }

        // MARK: 읽기 — 인덱스는 0부터다

        func string(_ column: Int32) -> String? {
            guard let pointer = sqlite3_column_text(handle, column) else { return nil }
            return String(cString: pointer)
        }

        func double(_ column: Int32) -> Double? {
            sqlite3_column_type(handle, column) == SQLITE_NULL
                ? nil : sqlite3_column_double(handle, column)
        }

        func int(_ column: Int32) -> Int {
            Int(sqlite3_column_int64(handle, column))
        }
    }
}
