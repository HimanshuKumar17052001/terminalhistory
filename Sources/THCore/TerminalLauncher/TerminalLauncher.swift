import Foundation

public protocol TerminalLauncher {
    var name: String { get }
    func arguments(for script: String, escape: (String) -> String) -> [String]
}

public final class TerminalLauncherRegistry {
    public init() {}
    public func launcher(for name: String) -> TerminalLauncher? {
        switch name {
        case "terminal": return TerminalAppLauncher()
        case "iterm":    return ITermLauncher()
        case "warp":     return WarpLauncher()
        default:
            if name.hasPrefix("/") || name.contains("/") { return CustomLauncher(command: name) }
            return nil
        }
    }
    public func detectInstalled() -> String {
        let fm = FileManager.default
        let candidates = ["/Applications/iTerm.app", "/Applications/Terminal.app", "/Applications/Warp.app"]
        for c in candidates where fm.fileExists(atPath: c) {
            switch c {
            case "/Applications/iTerm.app":    return "iterm"
            case "/Applications/Terminal.app": return "terminal"
            case "/Applications/Warp.app":     return "warp"
            default: break
            }
        }
        return "terminal"
    }
}