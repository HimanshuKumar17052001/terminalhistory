# TerminalHistory

Native macOS menu bar app + CLI that captures every terminal session automatically and lets you replay any past session into your preferred terminal, with a fresh shell in the original working directory.

- **Capture**: shell wrapper installed as the user's login shell — works in Terminal.app, iTerm2, VS Code, Docker, JetBrains IDEs, Ghostty, Alacritty, Warp, and SSH sessions.
- **Replay**: native menu bar dropdown grouped by day, plus a search window.
- **Storage**: local SQLite at `~/Library/Application Support/TerminalHistory/`.
- **Dependencies**: zero third-party packages, zero system libraries beyond what macOS already ships.

## Install

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/HimanshuKumar17052001/terminalhistory.git
cd terminalhistory
./install.sh
```

The install script prompts for your password once (to register the shell wrapper in `/etc/shells` and switch your login shell).

## Uninstall

```sh
./uninstall.sh
# or
th uninstall --yes
```

## Build from source

### CLI only

```sh
swift build -c release
./.build/release/th --help
```

### Xcode app

The Xcode project at `App/TerminalHistory.xcodeproj/` is committed. Just open it in Xcode and press ⌘R. To regenerate the project file from scratch:

```sh
gem install --user-install xcodeproj -v 1.25.0
ruby scripts/generate-xcodeproj.rb
```

## Documentation

- [Design spec](docs/superpowers/specs/2026-06-26-terminalhistory-design.md)
- [Implementation plan](docs/superpowers/plans/2026-06-26-terminalhistory-impl.md)
- [App setup notes](App/TerminalHistory/SETUP.md)
- [Manual smoke checklist](App/TerminalHistory/CHECKLIST.md)
- [Changelog](CHANGELOG.md)

## License

MIT
