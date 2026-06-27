import Foundation
import THCore

extension Subcommands {
    public enum List {
        public static func openStore() -> SessionStore {
            let url: URL
            if let o = ProcessInfo.processInfo.environment["TH_DB_PATH"] { url = URL(fileURLWithPath: o) }
            else { url = AppSupport.url().appendingPathComponent("store.sqlite") }
            return try! SessionStore(url: url)
        }
        public static func run(_ p: ArgumentParser) -> Int32 {
            let store = openStore()
            let limit = Int(p.flags["limit"] ?? "50") ?? 50
            let pinnedOnly = p.flags["pinned"] == "true"
            do {
                let sessions = try store.recentSessions(limit: limit * 4)
                let filtered = sessions.filter { pinnedOnly ? $0.pinned : true }.prefix(limit)
                for s in filtered {
                    let stamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(s.startedAt) / 1000))
                    let pin = s.pinned ? "* " : "  "
                    print("\(pin)\(s.id)  \(stamp)  \(s.title ?? s.shell)")
                }
                store.close(); return 0
            } catch {
                FileHandle.standardError.write(Data("list: \(error)\n".utf8)); return 1
            }
        }
    }
}