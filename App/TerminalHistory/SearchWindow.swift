import SwiftUI
import AppKit
import THCore

final class SearchWindowController: NSWindowController {
    convenience init(model: AppModel) {
        let host = NSHostingController(rootView: SearchView(model: model))
        let window = NSWindow(contentViewController: host)
        window.title = "Search sessions"
        window.setContentSize(NSSize(width: 520, height: 360))
        window.styleMask = [.titled, .closable, .resizable]
        self.init(window: window)
    }
}

@MainActor
final class SearchWindowOpener: NSObject {
    static let shared = SearchWindowOpener()
    private var controller: SearchWindowController?

    @objc func toggleSearchWindow(_ sender: Any?) {
        if let c = controller, c.window?.isVisible == true {
            c.close()
            controller = nil
            return
        }
        let model = AppModel()
        let c = SearchWindowController(model: model)
        c.showWindow(nil)
        controller = c
    }
}

struct SearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search command text…", text: $model.searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .onSubmit { model.runSearch() }
            List(model.searchResults, id: \.sessionID) { r in
                Button {
                    do {
                        let store = try SessionStore(url: AppSupport.url().appendingPathComponent("store.sqlite"))
                        if let s = try store.session(id: r.sessionID) {
                            model.replay(s)
                        }
                        try store.close()
                    } catch {}
                } label: {
                    VStack(alignment: .leading) {
                        Text(r.sessionID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(r.snippet)
                            .font(.body)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
