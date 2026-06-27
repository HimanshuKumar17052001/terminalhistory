import Foundation

public final class SessionReplayer {
    private let store: SessionStore
    public init(store: SessionStore) { self.store = store }

    public func replayScript(for id: String, shellPath: String, cwdFinal: String?) throws -> String {
        guard let session = try store.session(id: id) else { throw ReplayerError.notFound(id) }
        let events = try store.events(sessionID: id)
        var script = "printf '\\033[?25l'\n"
        for e in events {
            switch e.direction {
            case .out, .meta:
                let txt = (String(data: e.data, encoding: .utf8) ?? "")
                script += "printf %b " + shellQuote(txt) + "\n"
            case .in:
                let txt = (String(data: e.data, encoding: .utf8) ?? "")
                script += "printf '\\033[2m" + txt.replacingOccurrences(of: "'", with: "'\\''") + "\\033[0m\\n'\n"
            }
        }
        script += "printf '\\033[?25h'\n"
        script += "printf '\\n\\033[2m--- end of session \(session.id) ---\\033[0m\\n'\n"
        if let cwd = cwdFinal, !cwd.isEmpty {
            script += "cd " + shellQuote(cwd) + "\n"
        }
        script += "exec " + shellQuote(shellPath) + " -l\n"
        return script
    }

    private func shellQuote(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}

public enum ReplayerError: Error { case notFound(String) }