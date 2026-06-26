# TerminalHistory

Native macOS menu bar app + CLI that captures every terminal session automatically and lets you replay any past session into your preferred terminal, with a fresh shell in the original working directory.

## Install

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/HimanshuKumar17052001/terminalhistory.git
cd terminalhistory
./install.sh
```

The install script will prompt for your password once (to register the shell wrapper in `/etc/shells` and switch your login shell).

## Uninstall

```sh
th uninstall
```

## Documentation

- Design spec: `docs/superpowers/specs/2026-06-26-terminalhistory-design.md`
- Implementation plan: `docs/superpowers/plans/2026-06-26-terminalhistory-impl.md`

## License

MIT