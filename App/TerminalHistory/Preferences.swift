import SwiftUI
import THCore

struct PreferencesView: View {
    @State private var cfg = Config(directory: AppSupport.configDirectory())
    @State private var lastPrune: String = ""

    var body: some View {
        TabView {
            Form {
                Toggle("Launch TerminalHistory at login", isOn: Binding(
                    get: { LoginItemController.shared.enabled },
                    set: { LoginItemController.shared.setEnabled($0) }
                ))
                Picker("Default terminal", selection: $cfg.defaultTerminal) {
                    Text("Auto").tag(String?.none)
                    Text("Terminal.app").tag(String?.some("terminal"))
                    Text("iTerm2").tag(String?.some("iterm"))
                    Text("Warp").tag(String?.some("warp"))
                }
                Stepper("Max age: \(cfg.retention.maxAgeDays) days",
                        value: $cfg.retention.maxAgeDays, in: 1...3650)
                HStack {
                    Text("Max bytes")
                    TextField("", value: $cfg.retention.maxBytes, format: .number)
                        .frame(maxWidth: 200)
                }
                Button("Save") { try? cfg.save() }
            }
            .tabItem { Label("General", systemImage: "gear") }

            Form {
                Picker("Icon", selection: $cfg.theme.iconVariant) {
                    Text("Auto").tag(IconVariant.auto)
                    Text("Light").tag(IconVariant.light)
                    Text("Dark").tag(IconVariant.dark)
                    Text("Monochrome").tag(IconVariant.monochrome)
                }
                Picker("Accent", selection: $cfg.theme.accentHex) {
                    Text("System").tag("system")
                    Text("Blue").tag("#0a84ff")
                    Text("Purple").tag("#af52de")
                    Text("Pink").tag("#ff2d92")
                    Text("Orange").tag("#ff9f0a")
                    Text("Green").tag("#34c759")
                }
                Button("Save") { try? cfg.save() }
            }
            .tabItem { Label("Theme", systemImage: "paintbrush") }

            Form {
                Button("Open data folder") {
                    NSWorkspace.shared.open(AppSupport.url())
                }
                Button("Run retention now") {
                    do {
                        let store = try SessionStore(url: AppSupport.url().appendingPathComponent("store.sqlite"))
                        let r = try Retention(store: store, policy: cfg.retention).prune()
                        try store.close()
                        lastPrune = "Deleted \(r.deleted.count) sessions, \(r.remainingBytes) bytes remain"
                    } catch {
                        lastPrune = "Error: \(error)"
                    }
                }
                Text(lastPrune).font(.caption)
            }
            .tabItem { Label("Storage", systemImage: "internaldrive") }
        }
        .padding(16)
        .frame(width: 460, height: 340)
    }
}

@MainActor
final class PreferencesOpener: NSObject {
    static let shared = PreferencesOpener()
    private var window: NSWindow?

    func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: PreferencesView())
        let w = NSWindow(contentViewController: host)
        w.title = "TerminalHistory Preferences"
        w.setContentSize(NSSize(width: 460, height: 340))
        w.styleMask = [.titled, .closable]
        w.makeKeyAndOrderFront(nil)
        window = w
    }
}
