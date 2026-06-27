import Foundation
import THCore
import Darwin

let args = CommandLine.arguments

// Explicit shell-wrapper mode: th --shell <user-shell> [-- <args-to-forward>]
if let shellIdx = args.firstIndex(of: "--shell"), shellIdx + 1 < args.count {
    let target = args[shellIdx + 1]
    // Anything after a literal `--` is forwarded as extra args to the shell.
    var extra: [String] = []
    if let dash = args.firstIndex(of: "--"), dash > shellIdx + 1 {
        extra = Array(args[(dash + 1)...])
    }
    ShellWrapper.run(targetShell: target, extraArgs: extra)
    exit(0)
}

// Implicit shell-wrapper mode: invoked as a login shell.
// We detect this by checking argv[0]: POSIX login shells are invoked with
// argv[0] set to "-<basename>". Some launchers (e.g. macOS Terminal.app via
// launchd) also do this. We also fall back to: no subcommand arg AND a TTY
// AND argv[0] ends with "/th" — i.e. we're the binary invoked without args.
let argv0 = args.first ?? ""
let looksLikeLoginShell = argv0.hasPrefix("-") ||
    (argv0.hasSuffix("/th") && args.count == 1 && isatty(STDIN_FILENO) != 0)

if looksLikeLoginShell {
    let cfg = Config(directory: AppSupport.configDirectory())
    let userShell = cfg.userShell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    FileHandle.standardError.write(Data("th: login shell detected (argv[0]=\(argv0)), wrapping \(userShell)\n".utf8))
    ShellWrapper.run(targetShell: userShell)
    exit(0)
}

// Debug fallback for when detection fails but we might still be a login shell.
// This will be removed once we know what argv[0] actually looks like.
let looksPossiblyLikeLoginShell = argv0.hasSuffix("/th") && isatty(STDIN_FILENO) != 0
if looksPossiblyLikeLoginShell && args.dropFirst().isEmpty {
    FileHandle.standardError.write(Data("th: fallback login-shell path (argv[0]=\(argv0), args=\(args.count))\n".utf8))
    let cfg = Config(directory: AppSupport.configDirectory())
    let userShell = cfg.userShell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    ShellWrapper.run(targetShell: userShell)
    exit(0)
}
FileHandle.standardError.write(Data("th: not login shell (argv[0]=\(argv0), args=\(args.count), first=\(args.dropFirst().first ?? \"nil\"))\n".utf8))

// CLI subcommand mode
let parser = ArgumentParser(args: Array(args.dropFirst()))
let exitCode: Int32
switch parser.subcommand {
case "list":        exitCode = Subcommands.List.run(parser)
case "view":        exitCode = Subcommands.View.run(parser)
case "replay":      exitCode = Subcommands.Replay.run(parser)
case "pin":         exitCode = Subcommands.Pin.run(parser, pinning: true)
case "unpin":       exitCode = Subcommands.Pin.run(parser, pinning: false)
case "search":      exitCode = Subcommands.SearchCmd.run(parser)
case "export":      exitCode = Subcommands.ExportCmd.run(parser)
case "config":      exitCode = Subcommands.ConfigCmd.run(parser)
case "completions": exitCode = Subcommands.Completions.run(parser)
case "setup":       exitCode = Subcommands.Setup.run(parser)
case "uninstall":   exitCode = Subcommands.Uninstall.run(parser)
case "version", "-v", "--version":
    print("th 0.1.0"); exitCode = 0
default:
    print("Usage: th <command> [args]\n  setup, uninstall, list, view, replay, pin, unpin, search, export, config, completions")
    exitCode = parser.subcommand == nil ? 0 : 2
}
exit(exitCode)