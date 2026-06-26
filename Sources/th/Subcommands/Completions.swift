import Foundation
import THCore

extension Subcommands {
    public enum Completions {
        public static func run(_ p: ArgumentParser) -> Int32 {
            guard let shell = p.positional.first else { return 2 }
            let cmds = ["setup","uninstall","list","view","replay","pin","unpin","search","export","config","completions"]
            switch shell {
            case "zsh":
                print("#compdef th\n_th() { _arguments '1: :->cmd' '*:: :->args'; case $state in cmd) _describe 'command' '( \(cmds.joined(separator: " ")) )' ;; esac }\ncompdef _th th")
            case "bash":
                print("complete -W '\(cmds.joined(separator: " "))' th")
            case "fish":
                for c in cmds { print("complete -c th -a \(c)") }
            default:
                FileHandle.standardError.write(Data("completions: shell must be zsh|bash|fish\n".utf8)); return 2
            }
            return 0
        }
    }
}