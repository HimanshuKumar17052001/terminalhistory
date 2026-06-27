import SwiftUI
import THCore

@main
struct TerminalHistoryApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            // Use a plain SF Symbol to avoid macOS 26 layout recursion
            // (dynamic Color in the label closure triggered a scene-invalidated error).
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}
