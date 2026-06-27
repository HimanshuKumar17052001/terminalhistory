#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Verifying Xcode Command Line Tools..."
xcode-select -p >/dev/null || { echo "Run: xcode-select --install"; exit 1; }
echo "Building th..."
swift build -c release --product th
mkdir -p "$HOME/.local/bin"
install -m 0755 .build/release/th "$HOME/.local/bin/th"
if [ -d "App/TerminalHistory.xcodeproj" ]; then
  echo "Building TerminalHistory.app..."
  xcodebuild -project App/TerminalHistory.xcodeproj -scheme TerminalHistory -configuration Release
  cp -R App/build/Release/TerminalHistory.app /Applications/
fi
SHELL_PATH="$HOME/.local/bin/th"
if ! grep -qxF "$SHELL_PATH" /etc/shells; then
  echo "Adding $SHELL_PATH to /etc/shells (sudo required)..."
  echo "$SHELL_PATH" | sudo tee -a /etc/shells >/dev/null
fi
PREV_SHELL=$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')
mkdir -p "$HOME/.config/terminalhistory"
cat > "$HOME/.config/terminalhistory/config.json" <<EOF
{ "userShell": "$PREV_SHELL", "previousShell": "$PREV_SHELL", "defaultTerminal": null, "retention": { "maxAgeDays": 90, "maxBytes": 5368709120 }, "theme": { "iconVariant": "auto", "accentHex": "system" } }
EOF
chsh -s "$SHELL_PATH"
if [ -d "/Applications/TerminalHistory.app" ]; then open /Applications/TerminalHistory.app; fi
echo "Done. Open a new terminal window to test."