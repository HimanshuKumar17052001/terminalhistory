#!/usr/bin/env bash
# Runs every check that can be done without Xcode GUI.
# Paste this into Terminal on your Mac from the repo root.

set -euo pipefail
cd "$(dirname "$0")/.."

pass=0; fail=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; pass=$((pass+1)); }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; fail=$((fail+1)); }
hr()   { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }

hr "1. Toolchain"
if xcode-select -p >/dev/null 2>&1; then
  ok "xcode-select points to: $(xcode-select -p)"
else
  bad "xcode-select not configured. Run: xcode-select --install"
fi
if command -v swift >/dev/null 2>&1; then
  ok "swift: $(swift --version 2>&1 | head -1)"
else
  bad "swift not on PATH"
fi

hr "2. swift build"
if swift build 2>&1 | tee /tmp/th-build.log | tail -3; then
  if grep -qiE "warning:|error:" /tmp/th-build.log; then
    bad "build had warnings/errors (see /tmp/th-build.log)"
  else
    ok "build clean, no warnings"
  fi
else
  bad "swift build failed"
  exit 1
fi

hr "3. swift test"
if swift test 2>&1 | tee /tmp/th-test.log | tail -25; then
  if grep -q "Test Suite 'All tests' passed" /tmp/th-test.log; then
    ok "all tests passed"
  elif grep -q "Executed 0 tests" /tmp/th-test.log; then
    bad "no tests ran"
  else
    bad "tests had failures"
  fi
else
  bad "swift test failed to run"
fi

hr "4. Xcode project (.xcodeproj)"
if [ -d "App/TerminalHistory.xcodeproj" ]; then
  ok "App/TerminalHistory.xcodeproj exists"
else
  bad "App/TerminalHistory.xcodeproj missing"
fi
if [ -f "App/TerminalHistory/Info.plist" ]; then
  if /usr/libexec/PlistBuddy -c "Print :LSUIElement" "App/TerminalHistory/Info.plist" 2>/dev/null | grep -qi true; then
    ok "Info.plist: LSUIElement = true (no Dock icon)"
  else
    bad "Info.plist: LSUIElement not set to true"
  fi
fi
if [ -f "App/TerminalHistory/TerminalHistory.entitlements" ]; then
  if grep -q "com.apple.security.app-sandbox" "App/TerminalHistory/TerminalHistory.entitlements"; then
    sandbox=$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "App/TerminalHistory/TerminalHistory.entitlements" 2>/dev/null || echo "")
    if [ "$sandbox" = "false" ]; then
      ok "entitlements: App Sandbox disabled"
    else
      bad "entitlements: App Sandbox should be disabled"
    fi
  fi
fi

hr "5. App source files"
expected=("AppModel.swift" "MenuContentView.swift" "SearchWindow.swift" "Preferences.swift" "Theme.swift" "LoginItem.swift" "TerminalHistoryApp.swift")
for f in "${expected[@]}"; do
  if [ -f "App/TerminalHistory/$f" ]; then
    ok "App/TerminalHistory/$f"
  else
    bad "App/TerminalHistory/$f missing"
  fi
done

hr "6. Install scripts"
for f in install.sh uninstall.sh scripts/generate-xcodeproj.rb; do
  if [ -x "$f" ]; then
    ok "$f (executable)"
  elif [ -f "$f" ]; then
    bad "$f exists but not executable (chmod +x)"
  else
    bad "$f missing"
  fi
done

hr "Summary"
printf "  \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n" "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
printf "\nAll checks passed. Next: \033[1mopen App/TerminalHistory.xcodeproj\033[0m and ⌘R.\n"
