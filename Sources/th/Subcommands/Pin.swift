import Foundation
import THCore

extension Subcommands {
    public enum Pin {
        public static func run(_ p: ArgumentParser, pinning: Bool) -> Int32 {
            guard let id = p.positional.first else {
                FileHandle.standardError.write(Data("pin: missing session id\n".utf8)); return 2
            }
            let store = List.openStore()
            do {
                try store.setPinned(id, pinned: pinning)
                store.close()
                print(pinning ? "pinned \(id)" : "unpinned \(id)")
                return 0
            } catch {
                FileHandle.standardError.write(Data("pin: \(error)\n".utf8)); return 1
            }
        }
    }
}