import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct DatabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class Database {
    static let shared = Database()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.debatepractice.db")

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("debate.sqlite")
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            fatalError("Could not open database at \(url.path): \(lastError)")
        }
        migrate()
    }

    private func migrate() {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                topic TEXT NOT NULL,
                language TEXT NOT NULL,
                difficulty TEXT NOT NULL,
                mode TEXT NOT NULL,
                transcript TEXT NOT NULL,
                feedback TEXT,
                created_at TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS briefings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                committee TEXT NOT NULL UNIQUE,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS streaks (
                user_id INTEGER PRIMARY KEY REFERENCES users(id),
                current_streak INTEGER NOT NULL DEFAULT 0,
                longest_streak INTEGER NOT NULL DEFAULT 0,
                last_active_date TEXT
            )
            """,
        ]
        for sql in statements {
            do { try exec(sql) } catch { fatalError("Migration failed: \(error)") }
        }

        let columns = (try? query("PRAGMA table_info(sessions)")) ?? []
        if !columns.contains(where: { ($0["name"] as? String) == "kind" }) {
            try? exec("ALTER TABLE sessions ADD COLUMN kind TEXT NOT NULL DEFAULT 'debate'")
        }
    }

    func exec(_ sql: String, _ binds: [Any?] = []) throws {
        try queue.sync { _ = try run(sql, binds, collectRows: false) }
    }

    func query(_ sql: String, _ binds: [Any?] = []) throws -> [[String: Any]] {
        try queue.sync { try run(sql, binds, collectRows: true) }
    }

    func insert(_ sql: String, _ binds: [Any?] = []) throws -> Int64 {
        try queue.sync {
            _ = try run(sql, binds, collectRows: false)
            return sqlite3_last_insert_rowid(db)
        }
    }

    private var lastError: String {
        String(cString: sqlite3_errmsg(db))
    }

    private func run(_ sql: String, _ binds: [Any?], collectRows: Bool) throws -> [[String: Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError(message: lastError)
        }
        defer { sqlite3_finalize(stmt) }

        for (offset, value) in binds.enumerated() {
            let index = Int32(offset + 1)
            guard let value = value else {
                sqlite3_bind_null(stmt, index)
                continue
            }
            switch value {
            case let s as String:
                sqlite3_bind_text(stmt, index, s, -1, SQLITE_TRANSIENT)
            case let n as Int64:
                sqlite3_bind_int64(stmt, index, n)
            case let n as Int:
                sqlite3_bind_int64(stmt, index, Int64(n))
            case let d as Double:
                sqlite3_bind_double(stmt, index, d)
            default:
                throw DatabaseError(message: "Unsupported bind type: \(type(of: value))")
            }
        }

        var rows: [[String: Any]] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw DatabaseError(message: lastError) }
            guard collectRows else { continue }

            var row: [String: Any] = [:]
            for column in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, column))
                switch sqlite3_column_type(stmt, column) {
                case SQLITE_INTEGER:
                    row[name] = sqlite3_column_int64(stmt, column)
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, column)
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(stmt, column) {
                        row[name] = String(cString: text)
                    }
                default:
                    break
                }
            }
            rows.append(row)
        }
        return rows
    }
}
