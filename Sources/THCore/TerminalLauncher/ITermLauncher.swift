import Foundation
public final class ITermLauncher: TerminalLauncher {
    public let name = "iterm"
    public init() {}
    public func arguments(for script: String, escape: (String) -> String) -> [String] {
        let escaped = escape(script).replacingOccurrences(of: "\"", with: "\\\"")
        return ["-e", "tell application \"iTerm\" to create window with default profile command \"\(escaped)\""]
    }
}