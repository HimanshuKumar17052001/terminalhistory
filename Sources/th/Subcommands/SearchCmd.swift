import Foundation
import THCore

extension Subcommands {
    public enum SearchCmd {
        public static func run(_ p: ArgumentParser) -> Int32 {
            guard let query = p.positional.first else {
                FileHandle.standardError.write(Data("search: missing query\n".utf8)); return 2
            }
            let limit = Int(p.flags["limit"] ?? "20") ?? 20
            let store = List.openStore()
            do {
                for r in try Search(store: store).query(query, limit: limit) {
                    print("\(r.sessionID)  \(r.title ?? "")  \(r.snippet)")
                }
                try store.close(); return 0
            } catch {
                FileHandle.standardError.write(Data("search: \(error)\n".utf8)); return 1
            }
        }
    }
}