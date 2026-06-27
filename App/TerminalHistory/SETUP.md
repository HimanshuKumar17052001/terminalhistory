# Xcode project setup

This file is created when you run File → New → Project → macOS → App in Xcode. The Swift source files in this directory (`TerminalHistoryApp.swift`, `AppModel.swift`, `MenuContentView.swift`, `SearchWindow.swift`, `Preferences.swift`, `Theme.swift`, `LoginItem.swift`) and the asset catalog and entitlements are pre-staged so they can be dragged into the project on creation.

## One-time setup on your Mac

1. **Open Xcode** → File → New → Project → macOS → App
2. **Product Name:** `TerminalHistory`
3. **Interface:** SwiftUI
4. **Language:** Swift
5. **Bundle ID:** `com.himanshukumar17052001.TerminalHistory`
6. **Minimum Deployments:** macOS 13.0
7. **Save into:** `/Users/himanshukumar/Developer/terminalhistory/App/`
   - Xcode creates `App/TerminalHistory.xcodeproj/` and `App/TerminalHistory/TerminalHistory/` (this dir).
8. **Replace** the auto-generated `TerminalHistoryApp.swift` and **delete** the auto-generated `ContentView.swift`. Drag in all the other `.swift` files from this directory into the project target.
9. **Add THCore as a local SwiftPM dependency**: File → Add Package Dependencies → Add Local… → pick `../../` (the repo root) → select `THCore` library → Add to the `TerminalHistory` target.
10. **Set LSUIElement = YES** in the generated `Info.plist` (or Target → Info → Application is agent = YES).
11. **Disable App Sandbox** in Signing & Capabilities (v1 needs `chsh`, `osascript`, writes to `~/Library`).
12. **Build** (⌘B). If the entitlements file path is wrong, set the target's Code Signing Entitlements to `TerminalHistory/TerminalHistory.entitlements` (this file).
13. **Push the project**:

```sh
cd ~/Developer/terminalhistory
git add App/
git commit -m "feat(app): Xcode project skeleton"
git push origin feat/v0.1.0
```

## After the project is pushed

I will write any remaining SwiftUI updates, then you can build and run the app. If the build fails, share the error and I'll fix.
