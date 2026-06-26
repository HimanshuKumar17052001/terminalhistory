import Foundation

public final class Search {
    private let store: SessionStore
    public init(store: SessionStore) { self.store = store }

    public func query(_ q: String, limit: Int) throws -> [SearchResult] {
        let escaped = q.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsSQL = """
        SELECT s.id, snippet(events_fts, 0, '«', '»', '…', 12), s.started_at, s.title
        FROM events_fts
        JOIN events e ON e.rowid = events_fts.rowid
        JOIN sessions s ON s.id = e.session_id
        WHERE events_fts MATCH ?
        ORDER BY s.started_at DESC
        LIMIT ?
        """
        return try store.searchRaw(ftsSQL: ftsSQL, params: [escaped, String(limit)])
    }
}