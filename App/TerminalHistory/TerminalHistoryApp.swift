import SwiftUI
import THCore

@main
struct TerminalHistoryApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            ThemedMenuLabel(
                variant: model.themeVariant,
                accent: Color(hex: model.accentHex)
            )
        }
        .menuBarExtraStyle(.menu)
    }
}
