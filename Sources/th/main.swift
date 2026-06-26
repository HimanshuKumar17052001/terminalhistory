import Foundation
import THCore
import Darwin

let args = CommandLine.arguments

if let shellIdx = args.firstIndex(of: "--shell"), shellIdx + 1 < args.count {
    ShellWrapper.run(targetShell: args[shellIdx + 1])
    exit(0)
}

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