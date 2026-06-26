import Foundation
import THCore

extension Subcommands {
    public enum ConfigCmd {
        public static func run(_ p: ArgumentParser) -> Int32 {
            let cfg = Config(directory: AppSupport.configDirectory())
            switch p.positional.first {
            case "get":
                guard let key = p.positional.dropFirst().first else { return 2 }
                switch key {
                case "default_terminal":    print(cfg.defaultTerminal ?? "")
                case "user_shell":          print(cfg.userShell ?? "")
                case "previous_shell":      print(cfg.previousShell ?? "")
                case "retention_max_days":  print(cfg.retention.maxAgeDays)
                case "retention_max_bytes": print(cfg.retention.maxBytes)
                case "theme_icon":          print(cfg.theme.iconVariant.rawValue)
                case "theme_accent":        print(cfg.theme.accentHex)
                default: FileHandle.standardError.write(Data("config: unknown key\n".utf8)); return 2
                }
            case "set":
                guard let key = p.positional.dropFirst().first,
                      let val = p.positional.dropFirst().dropFirst().first else { return 2 }
                var c = cfg
                switch key {
                case "default_terminal":    c.defaultTerminal = val
                case "user_shell":          c.userShell = val
                case "previous_shell":      c.previousShell = val
                case "retention_max_days":  c.retention.maxAgeDays = Int(val) ?? c.retention.maxAgeDays
                case "retention_max_bytes": c.retention.maxBytes = Int64(val) ?? c.retention.maxBytes
                case "theme_icon":          c.theme.iconVariant = IconVariant(rawValue: val) ?? c.theme.iconVariant
                case "theme_accent":        c.theme.accentHex = val
                default: FileHandle.standardError.write(Data("config: unknown key\n".utf8)); return 2
                }
                do { try c.save() } catch { FileHandle.standardError.write(Data("config: \(error)\n".utf8)); return 1 }
            default:
                FileHandle.standardError.write(Data("config: usage: th config get|set <key> [value]\n".utf8)); return 2
            }
            return 0
        }
    }
}