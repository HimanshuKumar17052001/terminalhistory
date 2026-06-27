import Foundation
import THCore

extension Subcommands {
    public enum Replay {
        public static func run(_ p: ArgumentParser) -> Int32 {
            guard let id = p.positional.first else {
                FileHandle.standardError.write(Data("replay: missing session id\n".utf8)); return 2
            }
            let store = List.openStore()
            do {
                guard let session = try store.session(id: id) else {
                    FileHandle.standardError.write(Data("replay: no such session\n".utf8)); return 1
                }
                let cfg = Config(directory: AppSupport.configDirectory())
                let name = cfg.defaultTerminal ?? TerminalLauncherRegistry().detectInstalled()
                guard let launcher = TerminalLauncherRegistry().launcher(for: name) else {
                    FileHandle.standardError.write(Data("replay: unknown terminal '\(name)'\n".utf8)); return 1
                }
                let script = try SessionReplayer(store: store).replayScript(
                    for: id, shellPath: session.shell, cwdFinal: session.cwdFinal
                )
                let escape: (String) -> String = { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
                let task = Process()
                switch name {
                case "warp":
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = launcher.arguments(for: script, escape: escape)
                case let n where n.hasPrefix("/"):
                    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sh")
                    try script.write(to: tmp, atomically: true, encoding: .utf8)
                    task.executableURL = URL(fileURLWithPath: "/bin/sh")
                    task.arguments = ["-c", "\(n) <\(tmp.path)"]
                default:
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    task.arguments = launcher.arguments(for: script, escape: escape)
                }
                try task.run(); task.waitUntilExit()
                store.close(); return 0
            } catch {
                FileHandle.standardError.write(Data("replay: \(error)\n".utf8)); return 1
            }
        }
    }
}