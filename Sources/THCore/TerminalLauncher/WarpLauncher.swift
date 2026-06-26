import Foundation
public final class WarpLauncher: TerminalLauncher {
    public let name = "warp"
    public init() {}
    public func arguments(for script: String, escape: (String) -> String) -> [String] {
        return ["warp://run?command=\(escape(script))"]
    }
}