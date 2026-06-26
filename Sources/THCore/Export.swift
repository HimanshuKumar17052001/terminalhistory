import Foundation

public enum ExportFormat: String { case cast, txt }

public final class Export {
    private let store: SessionStore
    public init(store: SessionStore) { self.store = store }

    public func cast(sessionID: String, to url: URL) throws {
        guard let s = try store.session(id: sessionID) else { throw ExportError.sessionNotFound(sessionID) }
        var lines: [String] = []
        lines.append("{\"version\":2,\"width\":80,\"height\":24,\"timestamp\":\(s.startedAt / 1000),\"env\":{\"SHELL\":\"\(s.shell)\"},\"title\":\"\(s.title ?? "terminalhistory")\"}")
        for e in try store.events(sessionID: sessionID) {
            switch e.direction {
            case .in: continue
            case .out, .meta:
                let dt = Double(e.ts - s.startedAt) / 1000.0
                let payload = e.data.base64EncodedString()
                lines.append("[\(String(format: "%.3f", dt)),\"o\",\"\(payload)\"]")
            }
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    public func text(sessionID: String, to url: URL) throws {
        guard let s = try store.session(id: sessionID) else { throw ExportError.sessionNotFound(sessionID) }
        var out = "Session \(s.id)\nStarted: \(s.startedAt)  Shell: \(s.shell)\n"
        out += String(repeating: "-", count: 60) + "\n"
        for e in try store.events(sessionID: sessionID) {
            switch e.direction {
            case .in:  out += "> " + (String(data: e.data, encoding: .utf8) ?? "") + "\n"
            case .out, .meta: out += (String(data: e.data, encoding: .utf8) ?? "")
            }
        }
        try out.write(to: url, atomically: true, encoding: .utf8)
    }
}

public enum ExportError: Error { case sessionNotFound(String) }