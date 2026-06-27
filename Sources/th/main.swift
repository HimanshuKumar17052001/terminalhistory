import Foundation
import THCore
import Darwin

let args = CommandLine.arguments

// Explicit shell-wrapper mode: th --shell <user-shell>
if let shellIdx = args.firstIndex(of: "--shell"), shellIdx + 1 < args.count {
    ShellWrapper.run(targetShell: args[shellIdx + 1])
    exit(0)
}

// Implicit shell-wrapper mode: invoked as a login shell (arg[0] starts with '-')
// In this mode th is the login shell (set via chsh) and must transparently wrap
// the user's actual shell so that commands run in the terminal are captured.
let isLoginShell = (args.first?.hasPrefix("-") ?? false)
if isLoginShell {
    let cfg = Config(directory: AppSupport.configDirectory())
    let userShell = cfg.userShell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    ShellWrapper.run(targetShell: userShell)
    exit(0)
}

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