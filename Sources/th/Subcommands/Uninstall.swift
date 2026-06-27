import Foundation
import THCore

extension Subcommands {
    public enum Uninstall {
        public static func run(_ p: ArgumentParser) -> Int32 {
            let cfg = Config(directory: AppSupport.configDirectory())
            let previous = cfg.previousShell ?? "/bin/zsh"
            let yes = p.flags["yes"] == "true" || p.flags["y"] == "true"
            if !yes {
                print("This will restore your previous login shell (\(previous)) and remove the menu bar app. Pass --yes to confirm.")
                return 1
            }
            print("Restoring login shell to \(previous) ...")
            restoreShell(to: previous)
            removeHook()
            try? FileManager.default.removeItem(atPath: NSString(string: "~/.local/bin/th").expandingTildeInPath)
            try? FileManager.default.removeItem(atPath: "/Applications/TerminalHistory.app")
            if p.flags["purge"] == "true" {
                try? FileManager.default.removeItem(at: AppSupport.url())
                try? FileManager.default.removeItem(at: AppSupport.configDirectory())
            }
            print("Done."); return 0
        }

        private static func restoreShell(to path: String) {
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/chsh")
            task.arguments = ["-s", path]
            task.standardError = Pipe(); task.standardOutput = Pipe()
            do { try task.run(); task.waitUntilExit() }
            catch {
                FileHandle.standardError.write(Data("chsh failed: \(error). Try: sudo chsh -s \(path) \(NSUserName())\n".utf8))
            }
        }

        private static func removeHook() {
            let files = [
                NSString(string: "~/.zshrc").expandingTildeInPath,
                NSString(string: "~/.bashrc").expandingTildeInPath,
                NSString(string: "~/.config/fish/config.fish").expandingTildeInPath,
            ]
            for f in files {
                guard var text = try? String(contentsOfFile: f) else { continue }
                while let r = text.range(of: "\n# terminalhistory: cwd sidecar[\\s\\S]*?esac\n", options: .regularExpression) {
                    text.replaceSubrange(r, with: "\n")
                }
                while let r = text.range(of: "\n# terminalhistory: cwd sidecar[\\s\\S]*?end\n", options: .regularExpression) {
                    text.replaceSubrange(r, with: "\n")
                }
                try? text.write(toFile: f, atomically: true, encoding: .utf8)
            }
        }
    }
}