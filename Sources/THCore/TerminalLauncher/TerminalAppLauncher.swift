import Foundation
public final class TerminalAppLauncher: TerminalLauncher {
    public let name = "terminal"
    public init() {}
    public func arguments(for script: String, escape: (String) -> String) -> [String] {
        let escaped = escape(script).replacingOccurrences(of: "\"", with: "\\\"")
        return ["-e", "tell application \"Terminal\" to do script \"\(escaped)\""]
    }
}