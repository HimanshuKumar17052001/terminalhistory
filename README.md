# TerminalHistory

A native macOS menu bar app that captures every terminal session automatically and lets you replay any past session into your preferred terminal, with a fresh shell in the original working directory.

- Capture: shell wrapper installed as the user's login shell — works in Terminal.app, iTerm2, VS Code, Docker, JetBrains IDEs, Ghostty, Alacritty, Warp, and SSH sessions.
- Replay: native menu bar dropdown grouped by day, plus a search window.
- Storage: local SQLite at `~/Library/Application Support/TerminalHistory/`.
- Dependencies: zero third-party packages, zero system libraries beyond what macOS already ships.

See `docs/superpowers/specs/2026-06-26-terminalhistory-design.md` for the full design spec.

## Status

Pre-implementation. Spec approved; implementation plan pending.
