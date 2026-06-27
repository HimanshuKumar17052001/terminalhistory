import Foundation
import SQLite3

public enum SessionStatus: String { case active, exited, crashed }
public enum EventDirection: String { case `in`, out, meta }

public struct Session: Equatable {
    public var id: String
    public var startedAt: UInt64
    public var endedAt: UInt64?
    public var shell: String
    public var cwdInitial: String
    public var cwdFinal: String?
    public var host: String
    public var status: SessionStatus
    public var exitCode: Int32?
    public var pinned: Bool
    public var title: String?
    public var bytesIn: Int64
    public var bytesOut: Int64
}

public struct Event: Equatable {
    public var seq: Int
    public var ts: UInt64
    public var direction: EventDirection
    public var data: Data
}

public struct SearchResult: Equatable {
    public let sessionID: String
    public let snippet: String
    public let startedAt: UInt64
    public let title: String?
}

public enum SessionStoreError: Error { case openFailed(Int32), prepareFailed(String), stepFailed(String) }

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SessionStore {
    private var db: OpaquePointer?
    public let url: URL

    public init(url: URL) throws {
        self.url = url
        let rc = sqlite3_open_v2(url.path, &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard rc == SQLITE_OK else { throw SessionStoreError.openFailed(rc) }
        exec("PRAGMA journal_mode = WAL;")
        exec("PRAGMA foreign_keys = ON;")
        try applySchema()
    }
    deinit { close() }
    public func close() {
        if db != nil { sqlite3_close(db); db = nil }
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        sqlite3_exec(db, sql, nil, nil, &err)
        if err != nil { sqlite3_free(err) }
    }

    private func applySchema() throws {
        guard let schemaURL = Bundle.module.url(forResource: "Schema", withExtension: "sql"),
              let schema = try? String(contentsOf: schemaURL, encoding: .utf8) else { return }
        exec(schema)
    }

    public func insertSession(_ s: Session) throws {
        let sql = """
        INSERT INTO sessions(id,started_at,ended_at,shell,cwd_initial,cwd_final,host,status,exit_code,pinned,title,bytes_in,bytes_out)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, s.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, Int64(s.startedAt))
        if let e = s.endedAt { sqlite3_bind_int64(stmt, 3, Int64(e)) } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_text(stmt, 4, s.shell, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, s.cwdInitial, -1, SQLITE_TRANSIENT)
        if let c = s.cwdFinal { sqlite3_bind_text(stmt, 6, c, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 6) }
        sqlite3_bind_text(stmt, 7, s.host, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, s.status.rawValue, -1, SQLITE_TRANSIENT)
        if let c = s.exitCode { sqlite3_bind_int(stmt, 9, c) } else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_int(stmt, 10, s.pinned ? 1 : 0)
        if let t = s.title { sqlite3_bind_text(stmt, 11, t, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 11) }
        sqlite3_bind_int64(stmt, 12, s.bytesIn)
        sqlite3_bind_int64(stmt, 13, s.bytesOut)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SessionStoreError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    public func session(id: String) throws -> Session? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT * FROM sessions WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sessionFromRow(stmt!)
    }

    private func sessionFromRow(_ stmt: OpaquePointer) -> Session {
        return Session(
            id: String(cString: sqlite3_column_text(stmt, 0)),
            startedAt: UInt64(sqlite3_column_int64(stmt, 1)),
            endedAt: sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : UInt64(sqlite3_column_int64(stmt, 2)),
            shell: String(cString: sqlite3_column_text(stmt, 3)),
            cwdInitial: String(cString: sqlite3_column_text(stmt, 4)),
            cwdFinal: sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5)),
            host: String(cString: sqlite3_column_text(stmt, 6)),
            status: SessionStatus(rawValue: String(cString: sqlite3_column_text(stmt, 7))) ?? .exited,
            exitCode: sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_int(stmt, 8),
            pinned: sqlite3_column_int(stmt, 9) != 0,
            title: sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 10)),
            bytesIn: sqlite3_column_int64(stmt, 11),
            bytesOut: sqlite3_column_int64(stmt, 12)
        )
    }

    public func appendEvents(sessionID: String, events: [Event]) throws {
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
        defer { sqlite3_exec(db, "COMMIT", nil, nil, nil) }
        for e in events {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT INTO events(session_id,seq,ts,direction,data) VALUES(?,?,?,?,?)", -1, &stmt, nil) == SQLITE_OK else {
                throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, sessionID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(e.seq))
            sqlite3_bind_int64(stmt, 3, Int64(e.ts))
            sqlite3_bind_text(stmt, 4, e.direction.rawValue, -1, SQLITE_TRANSIENT)
            // Store raw event bytes (UTF-8 text). The FTS trigger indexes
            // these directly via CAST(data AS TEXT); no compression in v1
            // because the FTS index needs searchable plaintext.
            e.data.withUnsafeBytes { raw in
                if let base = raw.baseAddress {
                    sqlite3_bind_blob(stmt, 5, base, Int32(e.data.count), SQLITE_TRANSIENT)
                }
            }
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw SessionStoreError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    public func events(sessionID: String) throws -> [Event] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT seq,ts,direction,data FROM events WHERE session_id=? ORDER BY seq", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, SQLITE_TRANSIENT)
        var out: [Event] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let bytes = sqlite3_column_bytes(stmt, 3)
            let buf = sqlite3_column_blob(stmt, 3)
            let data = Data(bytes: buf!, count: Int(bytes))
            out.append(Event(
                seq: Int(sqlite3_column_int(stmt, 0)),
                ts: UInt64(sqlite3_column_int64(stmt, 1)),
                direction: EventDirection(rawValue: String(cString: sqlite3_column_text(stmt, 2))) ?? .out,
                data: data
            ))
        }
        return out
    }

    public func recentSessions(limit: Int) throws -> [Session] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT * FROM sessions ORDER BY started_at DESC LIMIT ?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        var out: [Session] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(sessionFromRow(stmt!)) }
        return out
    }

    public func markStaleActiveSessionsCrashed(olderThanHours h: Int) throws {
        let cutoff = UInt64(Date().timeIntervalSince1970 * 1000) - UInt64(h * 3600 * 1000)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE sessions SET status='crashed', ended_at=? WHERE status='active' AND started_at<?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(cutoff))
        sqlite3_bind_int64(stmt, 2, Int64(cutoff))
        _ = sqlite3_step(stmt)
    }

    public func setPinned(_ id: String, pinned: Bool) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE sessions SET pinned=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
        sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    public func updateFinalCwd(_ id: String, cwd: String) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE sessions SET cwd_final=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, cwd, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    public func finalizeSession(_ id: String, status: SessionStatus, exitCode: Int32?) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE sessions SET status=?, ended_at=?, exit_code=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, Int64(Date().timeIntervalSince1970 * 1000))
        if let c = exitCode { sqlite3_bind_int(stmt, 3, c) } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_text(stmt, 4, id, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    public func incrementByteCounters(sessionID: String, inBytes: Int64, outBytes: Int64) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE sessions SET bytes_in=bytes_in+?, bytes_out=bytes_out+? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, inBytes)
        sqlite3_bind_int64(stmt, 2, outBytes)
        sqlite3_bind_text(stmt, 3, sessionID, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    public func setTitle(_ id: String, title: String) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE sessions SET title=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    public func totalSizeBytes() throws -> Int64 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT page_count*page_size FROM pragma_page_count(), pragma_page_size()", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(stmt, 0)
    }

    public func sessionIds(olderThan ms: UInt64, pinned: Bool) throws -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT id FROM sessions WHERE started_at < ? AND pinned = ?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(ms))
        sqlite3_bind_int(stmt, 2, pinned ? 1 : 0)
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(String(cString: sqlite3_column_text(stmt, 0))) }
        return out
    }

    public func oldestUnpinnedSessions(excluding: Set<String>, limit: Int) throws -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT id FROM sessions WHERE pinned = 0 ORDER BY started_at ASC LIMIT ?", -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            if !excluding.contains(id) { out.append(id) }
        }
        return out
    }

    public func deleteSessions(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
        defer { sqlite3_exec(db, "COMMIT", nil, nil, nil) }
        for id in ids {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM sessions WHERE id=?", -1, &stmt, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    public func searchRaw(ftsSQL: String, params: [String]) throws -> [SearchResult] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, ftsSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw SessionStoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT)
        }
        var out: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let snippetPtr = sqlite3_column_text(stmt, 1)
            let snippet = snippetPtr != nil ? String(cString: snippetPtr!) : ""
            let titlePtr = sqlite3_column_text(stmt, 3)
            let title: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : (titlePtr != nil ? String(cString: titlePtr!) : nil)
            out.append(SearchResult(
                sessionID: String(cString: sqlite3_column_text(stmt, 0)),
                snippet: snippet,
                startedAt: UInt64(sqlite3_column_int64(stmt, 2)),
                title: title
            ))
        }
        return out
    }
}
