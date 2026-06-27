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
  if xcodebuild -version >/dev/null 2>&1 && [ "$(/usr/bin/xcode-select -p)" != "/Library/Developer/CommandLineTools" ]; then
    echo "Building TerminalHistory.app..."
    xcodebuild -project App/TerminalHistory.xcodeproj \
               -scheme TerminalHistory \
               -configuration Release \
               -derivedDataPath App/build
    cp -R App/build/Build/Products/Release/TerminalHistory.app /Applications/
    echo "✓ App copied to /Applications"
  else
    printf '\033[33mSkipping TerminalHistory.app build: full Xcode not installed (only Command Line Tools detected).\n\033[0m'
    printf '\033[33mThe CLI (`th`) is fully functional. To get the menu bar app, install full Xcode from the App Store and re-run install.sh.\n\033[0m'
  fi
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