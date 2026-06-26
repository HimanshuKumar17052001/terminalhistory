# TerminalHistory — Design Spec

**Date:** 2026-06-26
**Status:** Approved for planning
**Target repo:** `github.com/HimanshuKumar17052001/terminalhistory` (new, public, MIT)
**Target audience:** macOS 13+ (Ventura) and later

---

## 1. Problem

When a macOS terminal closes — by quitting the app, by closing the tab, or by restarting the laptop — the visible scrollback is gone. Shell history (commands typed) survives in `~/.zsh_history`, but full session output (stdout, stderr, colors, prompts) does not.

TerminalHistory captures full PTY sessions automatically and lets the user replay any past session into their preferred terminal, then drop into a fresh shell in the same working directory.

## 2. Goals

1. **Universal capture.** Every PTY session on the Mac — Terminal.app, iTerm2, VS Code integrated terminal, Docker Desktop terminal, JetBrains IDE terminals, Ghostty, Alacritty, Warp, SSH sessions — is captured without per-app configuration.
2. **One-click replay.** A native macOS menu bar item lists past sessions, grouped by day, with pinned sessions surfaced at the top. Clicking a session opens the user's default terminal, prints the captured session as a read-only replay, and starts a fresh shell in the original cwd.
3. **Search.** A search window reachable from the menu bar searches across all captured session text.
4. **Zero runtime dependencies.** No Homebrew packages, no third-party SwiftPM packages, no system libraries beyond what macOS already ships. Build-from-source install via a single `install.sh` script.
5. **Reversible.** A single `th uninstall` command fully removes the tool and restores the user's previous shell.

## 3. Non-goals (v1)

- Cloud sync, multi-machine, sharing, public links
- Encryption at rest (relies on macOS FileVault)
- Auto-update
- Telemetry / analytics
- iOS, iPadOS, Windows, Linux
- Mac App Store / sandboxing
- XCUITest for the menu bar app (manual smoke checklist instead)
- Per-command grouping (events are a flat stream; grouping can be derived later)

## 4. Architecture

Three targets in one repo, one toolchain (Xcode Command Line Tools, `swift` 5.9+, `xcodebuild`):

```
terminalhistory/
├── Package.swift                 # SwiftPM: THCore (lib) + th (exe)
├── Sources/
│   ├── THCore/                   # capture, storage, replay, launchers
│   └── th/                       # CLI executable / login shell wrapper
├── App/
│   └── TerminalHistory/          # Xcode project → TerminalHistory.app
├── docs/
├── install.sh
└── uninstall.sh
```

### 4.1 `THCore` (SwiftPM library)

Pure-Swift logic with no UI dependencies. Targets macOS 13+.

| Component | Responsibility |
|---|---|
| `SessionStore` | SQLite read/write of `sessions`, `events`, `events_fts`. Uses `import SQLite3` directly (no wrapper lib). |
| `GzipCodec` | Wraps `Compression.framework` (`compression_encode_buffer` / `compression_decode_buffer`) for event payloads. |
| `PTYCapturer` | Opens a PTY pair, forks/execs the user shell, streams master ↔ child bidirectionally, captures window size. |
| `SessionRecorder` | Buffers PTY bytes, writes `events` rows through `SessionStore`, updates `sessions.cwd_final` from the sidecar cwd file. |
| `SessionReplayer` | Reads events for a session id, returns a single shell script that prints the replay (preserving ANSI escapes) and then `cd && exec`s the user shell. |
| `TerminalLauncher` | Given a shell script and the configured terminal, returns a `Process` to launch it. Supports Terminal.app (AppleScript), iTerm2 (AppleScript), Warp (URL scheme), and a configurable generic command. |
| `RetentionPolicy` | Computes sessions to delete given a policy and current store size; idempotent. |
| `Export` | Writes a session as asciinema `.cast` (JSON-lines) or plain `.txt`. |
| `Search` | FTS5 query helpers, paginated, with highlight snippets. |

### 4.2 `th` (SwiftPM executable)

Single binary, three modes of use:

1. **As login shell** (`th --shell <path> [--] [args…]`): invoked once per PTY by the user's terminal. Wraps the real shell in a PTY pair and records.
2. **CLI subcommands** (when stdout is not a PTY or when `--shell` is absent):
   - `th setup` — first-time install (registers in `/etc/shells`, installs `precmd` hook, writes config, enables login item).
   - `th uninstall` — reverses everything `setup` did.
   - `th list [--day YYYY-MM-DD] [--pinned] [--limit N]` — human-readable session list (also used by the menu bar app's data layer via direct `THCore` call — kept for CLI parity and debugging).
   - `th view <id>` — prints the replay to the current terminal without launching anything.
   - `th replay <id>` — generates and launches the replay into the configured terminal.
   - `th pin <id>` / `th unpin <id>`.
   - `th search <query> [--limit N]` — prints matching session ids with snippets.
   - `th export <id> --format cast|txt --out <path>`.
   - `th config` — read/write config keys (default terminal, retention, theme).
   - `th completions zsh|bash|fish` — emit a shell completion script to stdout.

### 4.3 `TerminalHistory.app` (Xcode project)

SwiftUI menu bar app, `LSUIElement = true` (no dock icon). Owns:

- The `NSStatusItem` with `MenuBarExtra` (macOS 13+) showing grouped-by-day session list, pin section, search item, preferences item, quit item.
- A separate `NSWindow` for search (`NSWindowController` + SwiftUI view) reachable from the menu.
- A preferences window with tabs: General (default terminal, retention, export defaults), Theme (icon variant, accent color), Storage (open data folder, run retention now).
- Login-item registration via `SMAppService` (macOS 13+).
- Reuses `THCore` directly via SwiftPM local package reference; does not shell out to the `th` binary.

## 5. Capture

### 5.1 Login-shell flow

When `chsh` has set the user's shell to `$HOME/.local/bin/th`, every new PTY (any terminal app) invokes:

```
th --shell "$TH_USER_SHELL"
```

`th` then resolves the target shell in this priority order:

1. `$TH_USER_SHELL` environment variable (exported by the `precmd` hook from the previous prompt of the *current* shell, if any)
2. `user_shell` from `~/.config/terminalhistory/config.json` (set by `th setup`)
3. Hard-coded fallback: `/bin/zsh`

If the resolved path does not exist on disk, prints a one-line stderr warning and `exec`s `/bin/zsh` (so the user is never blocked). `th` always passes `-l` to the inner shell so it sources the user's login profiles (`.zprofile`, `.bash_profile`, etc.) as it would have without the wrapper.

`th` then:

1. Allocates a PTY pair with `openpty(3)` (from `<util.h>`).
2. Forks. Child: setsid, attaches slave as controlling TTY, `execvp` the user shell.
3. Parent: spawns two `DispatchSourceRead` tasks (one on stdin → PTY master, one on PTY master → stdout + `SessionRecorder`). Window size is forwarded via `ioctl(TIOCSWINSZ)` whenever the parent's controlling terminal reports a change.
4. On child exit (`waitpid`), finalizes the session row, flushes the recorder, exits.

### 5.2 Event model

Each PTY read produces zero or more events. Events are written transactionally in batches of ~32 KB or 500 ms, whichever first:

```swift
struct Event {
    let seq: Int
    let ts: Int       // ms since epoch
    let direction: Direction   // .in | .out | .meta
    let data: Data    // raw bytes, gzipped at rest
}
```

`.in` is bytes typed by the user (including echoed control sequences). `.out` is everything the child writes. `.meta` carries lifecycle markers (session start, cwd change snapshots, exit).

### 5.3 Cwd tracking

The shell cannot report its own cwd to a wrapper without a hook. `th setup` appends a single small block to `~/.zshrc`, `~/.bashrc`, or the fish equivalent (detected per-user-shell). The block defines `precmd` / `PROMPT_COMMAND`:

```sh
# terminalhistory: cwd sidecar (do not edit, removed by th uninstall)
[ -n "$TH_SESSION_DIR" ] && __th_pwd() { pwd > "$TH_SESSION_DIR/cwd" 2>/dev/null; }
case "$SHELL" in
  */zsh)  precmd_functions+=(__th_pwd) ;;
  */bash) PROMPT_COMMAND="__th_pwd${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
  */fish) function __th_pwd; pwd > "$TH_SESSION_DIR/cwd" 2>/dev/null; end; function fish_prompt; __th_pwd; end ;;
esac
```

`$TH_SESSION_DIR` is exported by `th` before `exec`ing the user shell. On uninstall, the block is removed by matching the `# terminalhistory: cwd sidecar` marker line and deleting through the closing `esac` / `end` line.

`SessionRecorder` polls the sidecar every 1 s and writes `.meta` events when the path changes; the last value at session end is written to `sessions.cwd_final`.

### 5.4 Failure modes

- **PTY allocation failure:** fall back to plain `exec`, stderr warning, no session recorded.
- **DB write failure:** append-only WAL file at `~/Library/Application Support/TerminalHistory/wal/` plus a menu bar badge in the app ("⚠︎ 3 sessions pending").
- **Shell init hook missing or failing:** `cwd_final` stays null; replay still works; only the post-replay `cd` is skipped (and a warning is printed).
- **Wrapper killed (SIGKILL of the terminal app):** final `waitpid` doesn't run. A startup sweep in `SessionStore` marks any `sessions.status = 'active'` rows older than 24 h as `crashed`.

## 6. Storage

### 6.1 Location

`~/Library/Application Support/TerminalHistory/store.sqlite` (+ `-wal`, `-shm` siblings).

### 6.2 Schema

```sql
CREATE TABLE sessions (
  id              TEXT PRIMARY KEY,                  -- ULID
  started_at      INTEGER NOT NULL,                  -- ms since epoch
  ended_at        INTEGER,
  shell           TEXT NOT NULL,
  cwd_initial     TEXT NOT NULL,
  cwd_final       TEXT,
  host            TEXT NOT NULL,
  status          TEXT NOT NULL,                     -- active|exited|crashed
  exit_code       INTEGER,
  pinned          INTEGER NOT NULL DEFAULT 0,
  title           TEXT,                              -- first non-empty .in line, truncated
  bytes_in        INTEGER NOT NULL DEFAULT 0,
  bytes_out       INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_sessions_started ON sessions(started_at DESC);

CREATE TABLE events (
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  seq             INTEGER NOT NULL,
  ts              INTEGER NOT NULL,
  direction       TEXT NOT NULL,
  data            BLOB NOT NULL,                     -- gzipped raw bytes
  PRIMARY KEY (session_id, seq)
);

CREATE VIRTUAL TABLE events_fts USING fts5(
  data, content='', tokenize='unicode61 remove_diacritics'
);

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);                                                  -- schema_version, last_retention_run, etc.
```

FTS population: on insert, decode the gzip blob and insert the text into `events_fts` (deleting from the virtual table uses an external-content pattern with triggers on `events`).

Schema version is stored in `meta`; migrations are forward-only `.sql` files applied at app launch.

### 6.3 Retention

Policy (defaults, both configurable):

- Max age: 90 days
- Max total DB size: 5 GB

Pruning rule: every session older than max age is deleted; if total DB size still exceeds max size, delete oldest unpinned sessions until under the limit. Pinned sessions are never auto-deleted. The user can also prune manually from the Storage preferences tab.

Pruning runs (a) on app launch, (b) once per 24 h while the app is running (timer), (c) on demand from preferences.

### 6.4 Replay

`SessionReplayer.replayScript(for: id, shellPath: String, cwdFinal: String?) -> String` returns a single shell script string with the placeholders `$SESSION_ID`, `$SHELL_PATH`, and `$CWD_FINAL` already substituted by the caller (string interpolation, no shell evaluation):

```sh
printf '\033[?25l'                              # hide cursor during replay
# for each event in order, appended to this script by the replayer:
#   if .out or .meta:  raw bytes (preserves ANSI)
#   if .in:            printf '\033[2m%s\033[0m' "$decoded_text"
printf '\033[?25h'                              # restore cursor
printf '\n\033[2m--- end of session SESSION_ID ---\033[0m\n'
if [ -n "CWD_FINAL" ] && [ -d "CWD_FINAL" ]; then
  cd "CWD_FINAL"
fi
exec "SHELL_PATH" -l
```

The `exec` ensures the wrapper does not leave an extra process layer between the user and their shell. ANSI handling is best-effort: if the user's terminal is 8-color but the replay has 256-color escapes, the user's terminal renders its closest match — acceptable degradation. The returned script is what `TerminalLauncher` ultimately feeds to the chosen terminal app.

## 7. Search

Reachable from the menu bar via a "Search…" item. Opens a small native window (`NSWindow` with SwiftUI `NSViewController`) with a single text field and a results list. Backed by `events_fts MATCH` queries against the FTS5 virtual table, joined back to `events` and `sessions`. Results show session id, day, snippet with `snippet(events_fts, 1, '«', '»', '…', 12)`, and a click action that calls `TerminalLauncher.launchReplay(for: id)`.

The search is local-only; no telemetry, no remote calls.

## 8. Menu bar UI

`MenuBarExtra` (macOS 13+) populated from `THCore`:

```
[pinned section, if any]
─────────────────────────
Today
  ▶ 14:02  make test         (12m, 4.2k lines)
  ▶ 09:15  k9s               (47m, 11k lines)
Yesterday
  ▶ 18:44  deploy.sh …
  ▶ 16:02  ./scripts/seed.sh …
…
─────────────────────────
Search…
Open data folder
Preferences…
Quit TerminalHistory
```

(▶ is a play-icon affordance; click to replay.) Each row has a small star button on the right for pin/unpin.

### 8.1 Theme

In preferences → Theme:
- Icon variant: Auto (follows system appearance) / Light / Dark / Monochrome
- Accent color: a fixed set (System, Blue, Purple, Pink, Orange, Green) stored in `meta` as RGB hex

The accent color tints the pin star and the active-session indicator. No custom color picker in v1 (YAGNI).

## 9. Terminal launchers

| Terminal | Mechanism |
|---|---|
| Terminal.app | `osascript -e 'tell application "Terminal" to do script "<escaped>"'` |
| iTerm2 | `osascript -e 'tell application "iTerm" to create window with default profile command "<escaped>"'` |
| Warp | `open "warp://run?command=<urlencoded>"` — fallback to `open -a Warp <tmpfile>` if the scheme is unsupported on the installed version |
| Custom | `Process.run` with the configured command, script piped to stdin |

The default terminal is configurable. Auto-detect on first run: prefer iTerm2 if installed, else Terminal.app, else prompt.

## 10. Install

### 10.1 `install.sh`

```sh
#!/usr/bin/env bash
set -euo pipefail
xcode-select -p >/dev/null || { echo "Run: xcode-select --install"; exit 1; }
swift build -c release --product th
mkdir -p "$HOME/.local/bin"
install -m 0755 .build/release/th "$HOME/.local/bin/th"
xcodebuild -project App/TerminalHistory.xcodeproj -scheme TerminalHistory -configuration Release
cp -R App/build/Release/TerminalHistory.app /Applications/
SHELL_PATH="$HOME/.local/bin/th"
grep -qxF "$SHELL_PATH" /etc/shells || echo "$SHELL_PATH" | sudo tee -a /etc/shells >/dev/null
PREV_SHELL=$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')
mkdir -p "$HOME/.config/terminalhistory"
echo "{\"user_shell\":\"$PREV_SHELL\",\"previous_shell\":\"$PREV_SHELL\"}" \
  > "$HOME/.config/terminalhistory/config.json"
chsh -s "$SHELL_PATH"
open /Applications/TerminalHistory.app
echo "Done. Open a new terminal window to test."
```

One sudo prompt (for `/etc/shells` + `chsh`). Undo path documented in README.

### 10.2 Distribution

- GitHub: `github.com/HimanshuKumar17052001/terminalhistory`, public, MIT license.
- README documents: prerequisites, install, usage, FAQ, troubleshooting, uninstall, contributing.
- No CI in v1; tests run locally via `swift test` and `xcodebuild test`.
- No Homebrew formula (avoids a tap repo and a second source of truth).

## 11. Uninstall

```sh
th uninstall
# 1. chsh -s "$previous_shell"        (read from config.json; sudo if needed)
# 2. Remove $HOME/.local/bin/th
# 3. Remove /Applications/TerminalHistory.app
# 4. Remove login item via SMAppService
# 5. Remove /etc/shells line           (sudo; with confirmation)
# 6. Remove precmd hook from rc files  (matched block, idempotent)
# 7. Optional: delete data dir + WAL after prompt
```

Each step logs a one-line status. Failures are non-fatal; the user is shown what was and wasn't removed.

## 12. Testing strategy

| Layer | Type | Tooling |
|---|---|---|
| `THCore` SQLite, gzip, retention, FTS | Unit tests against in-memory `:memory:` DB | XCTest via `swift test` |
| `PTYCapturer` | Real child process (`/bin/echo`, `/bin/sh -c 'sleep 1; exit 0'`) under a real PTY pair; assert recorded bytes match | XCTest |
| `SessionRecorder` end-to-end | Invoke built `th --shell /bin/sh -c 'echo hi; exit'` binary; assert a session row + at least one event was written | XCTest, integration |
| `th` CLI | Argument parsing, subcommand routing, exit codes, stdout/stderr separation | XCTest + `Process` |
| `TerminalLauncher` | Construct launcher for each terminal type; assert the produced `Process.arguments` matches an expected fixture; mock AppleScript execution | XCTest |
| `SessionReplayer` | Round-trip a recorded session through the replayer into a captured pipe; assert ANSI bytes are preserved | XCTest |
| `Export` | Export a known session, assert file contents match a fixture (golden files) | XCTest |
| `TerminalHistory.app` | Manual smoke checklist in `App/TerminalHistory/CHECKLIST.md`; no XCUITest in v1 | Human |

CI: none in v1.

## 13. Error handling principles

- **Never lose data silently.** Any DB write failure falls through to a WAL file in the same directory and surfaces a non-blocking menu bar badge.
- **Wrapper must never block the user.** Any failure during capture setup falls back to plain `exec` of the user shell with a one-line stderr warning.
- **Errors are redacted before logging.** A pre-log scrubber strips `(?i)(token|secret|password|api[_-]?key)=[^\s]+` patterns from `~/Library/Logs/TerminalHistory/<date>.log`.
- **Idempotent replay.** Replaying from any offset never throws; missing events render as blank lines.

## 14. Privacy

- 100% local. No network calls of any kind in v1.
- README documents exactly which files are created and where.
- `uninstall` includes a one-line option to delete all data.

## 15. Open questions deferred (will be re-brained later)

- Cloud sync (iCloud Drive of the DB file is the obvious candidate)
- Encryption at rest
- Auto-update via Sparkle (would re-introduce a SwiftPM dep; design decision needed)
- Sharing / public links (requires either a server or a third-party paste service)
- XCUITest for the menu bar app
- Per-command grouping derived from event stream

---

## Appendix A — File-level responsibilities (for the implementation plan)

These will become task boundaries in the plan:

- `Sources/THCore/SessionStore.swift` — DB open/migrate/CRUD
- `Sources/THCore/Schema.sql` — canonical schema
- `Sources/THCore/GzipCodec.swift`
- `Sources/THCore/PTY/` — PTY pair alloc, fork, capture loop
- `Sources/THCore/SessionRecorder.swift`
- `Sources/THCore/SessionReplayer.swift`
- `Sources/THCore/TerminalLauncher/` — one file per terminal
- `Sources/THCore/Retention.swift`
- `Sources/THCore/Export.swift`
- `Sources/THCore/Search.swift`
- `Sources/THCore/Config.swift` — reads/writes `~/.config/terminalhistory/config.json`
- `Sources/THCore/ULID.swift` — minimal ULID generator (no external dep)
- `Sources/th/main.swift` — arg parser + subcommand dispatch
- `Sources/th/Subcommands/` — one file per subcommand
- `App/TerminalHistory/TerminalHistoryApp.swift` — SwiftUI App entry
- `App/TerminalHistory/MenuContent.swift` — MenuBarExtra view
- `App/TerminalHistory/SearchWindow.swift`
- `App/TerminalHistory/Preferences.swift`
- `App/TerminalHistory/Theme.swift`
- `App/TerminalHistory/LoginItem.swift`
- `install.sh`, `uninstall.sh`
- `README.md`, `LICENSE` (MIT)

## Appendix B — User-facing CLI examples

```sh
th setup
th uninstall
th list --limit 10
th list --day 2026-06-25
th view 01HX...
th replay 01HX...
th pin 01HX...
th search "k8s rollout"
th export 01HX... --format cast --out /tmp/session.cast
th export 01HX... --format txt  --out /tmp/session.txt
th config set default_terminal iterm
th config get retention_max_days
th completions zsh > ~/.zsh/completions/_th
```
