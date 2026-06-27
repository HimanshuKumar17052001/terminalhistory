import Foundation
import THCore

extension Subcommands {
    public enum Setup {
        public static func run(_ p: ArgumentParser) -> Int32 {
            let shellPath = NSString(string: "~/.local/bin/th").expandingTildeInPath
            var cfg = Config(directory: AppSupport.configDirectory())
            if cfg.userShell == nil {
                let prev = (detectLoginShell() ?? "/bin/zsh").trimmingCharacters(in: .whitespacesAndNewlines)
                cfg.previousShell = prev
                cfg.userShell = prev
                try? cfg.save()
            }
            installHook(into: cfg.userShell ?? "/bin/zsh")
            print("TerminalHistory is configured.")
            print("  Login shell path: \(shellPath)")
            print("  User shell:       \(cfg.userShell ?? "")")
            print("  Previous shell:   \(cfg.previousShell ?? "")")
            print("\nNext steps:")
            print("  1. Run ./install.sh (registers shell, opens app)")
            print("  2. Open a new terminal window to test")
            return 0
        }

        private static func detectLoginShell() -> String? {
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/stat")
            task.arguments = ["-f%Su", "/dev/console"]
            let pipe = Pipe(); task.standardOutput = pipe
            guard (try? task.run()) != nil else { return nil }
            task.waitUntilExit()
            let user = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let user else { return nil }
            let p2 = Process(); p2.executableURL = URL(fileURLWithPath: "/usr/bin/dscl")
            p2.arguments = [".", "-read", "/Users/\(user)", "UserShell"]
            let pipe2 = Pipe(); p2.standardOutput = pipe2
            guard (try? p2.run()) != nil else { return nil }
            p2.waitUntilExit()
            let out = String(data: pipe2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return out.split(separator: " ").last.map(String.init)
        }

        private static func installHook(into shell: String) {
            let hook = """

            # terminalhistory: cwd sidecar (do not edit, removed by th uninstall)
            [ -n "$TH_SESSION_DIR" ] && __th_pwd() { pwd > "$TH_SESSION_DIR/cwd" 2>/dev/null; }
            case "$SHELL" in
              */zsh)  precmd_functions+=(__th_pwd) ;;
              */bash) PROMPT_COMMAND="__th_pwd${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
              */fish) function __th_pwd; pwd > "$TH_SESSION_DIR/cwd" 2>/dev/null; end; function fish_prompt; __th_pwd; end ;;
            esac

            """
            var target: URL?
            let lastComp = (shell.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).lastPathComponent
            switch lastComp {
            case "zsh":   target = URL(fileURLWithPath: NSString(string: "~/.zshrc").expandingTildeInPath)
            case "bash":  target = URL(fileURLWithPath: NSString(string: "~/.bashrc").expandingTildeInPath)
            case "fish":  target = URL(fileURLWithPath: NSString(string: "~/.config/fish/config.fish").expandingTildeInPath)
            default:      target = nil
            }
            guard let target else { return }
            let existing = (try? String(contentsOf: target)) ?? ""
            if existing.contains("terminalhistory: cwd sidecar") { return }
            try? (existing + hook).write(to: target, atomically: true, encoding: .utf8)
        }
    }
}