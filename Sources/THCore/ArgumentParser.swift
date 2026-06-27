import Foundation

public struct ArgumentParser {
    public let subcommand: String?
    public var positional: [String] = []
    public var flags: [String: String] = [:]

    public init(args: [String]) {
        guard let first = args.first else { self.subcommand = nil; return }
        if first.hasPrefix("-") { self.subcommand = nil; self.positional = args; return }
        self.subcommand = first
        var i = 1
        while i < args.count {
            let a = args[i]
            if a.hasPrefix("--") {
                let key = String(a.dropFirst(2))
                if i + 1 < args.count, !args[i + 1].hasPrefix("-") {
                    flags[key] = args[i + 1]; i += 2
                } else { flags[key] = "true"; i += 1 }
            } else if a.hasPrefix("-") {
                flags[String(a.dropFirst(1))] = "true"; i += 1
            } else { positional.append(a); i += 1 }
        }
    }
}