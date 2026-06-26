import Foundation
import THCore

extension Subcommands {
    public enum View {
        public static func run(_ p: ArgumentParser) -> Int32 {
            guard let id = p.positional.first else {
                FileHandle.standardError.write(Data("view: missing session id\n".utf8)); return 2
            }
            let store = List.openStore()
            do {
                let s = try store.session(id: id)
                let script = try SessionReplayer(store: store).replayScript(
                    for: id, shellPath: s?.shell ?? "/bin/zsh", cwdFinal: s?.cwdFinal
                )
                FileHandle.standardOutput.write(Data(script.utf8))
                try store.close(); return 0
            } catch {
                FileHandle.standardError.write(Data("view: \(error)\n".utf8)); return 1
            }
        }
    }
}