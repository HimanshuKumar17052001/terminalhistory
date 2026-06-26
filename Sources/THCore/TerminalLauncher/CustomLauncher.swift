import Foundation
public final class CustomLauncher: TerminalLauncher {
    public let command: String
    public var name: String { command }
    public init(command: String) { self.command = command }
    public func arguments(for script: String, escape: (String) -> String) -> [String] {
        return [command]
    }
}