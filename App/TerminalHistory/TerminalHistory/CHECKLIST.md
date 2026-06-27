# Manual smoke checklist

Run before each release. ✓ = pass, ✗ = fail, blank = not tested.

## Fresh install
- [ ] `git clone` runs cleanly
- [ ] `xcode-select -p` succeeds
- [ ] `./install.sh` builds th, builds .app, prompts for sudo once
- [ ] After install, opening Terminal.app shows the new prompt (login shell is `~/.local/bin/th`)
- [ ] TerminalHistory.app appears in the menu bar
- [ ] System Settings → General → Login Items shows TerminalHistory

## Capture
- [ ] Run `ls` in Terminal.app → session appears in menu bar within 5s
- [ ] Run `cd /tmp; pwd` → replay shows the cd in the menu bar preview
- [ ] Quit TerminalHistory.app, reopen → sessions still listed
- [ ] Restart laptop, open Terminal.app → history intact

## Replay
- [ ] Click a session row → terminal opens with replay, drops to fresh shell in same cwd
- [ ] ANSI colors preserved in replay (run `ls -G` in original)
- [ ] Pinned session appears in Pinned section
- [ ] Star button toggles pin/unpin
- [ ] Replay into iTerm2 if installed
- [ ] Replay into Warp if installed (URL scheme test)
- [ ] Replay into custom terminal if configured

## Search
- [ ] Cmd-F or Search… opens window
- [ ] Type "k8s" → matching sessions shown
- [ ] Click a result → opens replay in chosen terminal

## Preferences
- [ ] Change default terminal → next replay uses it
- [ ] Change retention max age → save persists across app restart
- [ ] Open data folder opens `~/Library/Application Support/TerminalHistory/`
- [ ] Run retention now reports a count

## Uninstall
- [ ] `th uninstall --yes` restores previous shell
- [ ] Hook block removed from `~/.zshrc`
- [ ] `~/.local/bin/th` and `/Applications/TerminalHistory.app` are gone
- [ ] Login item removed from System Settings
