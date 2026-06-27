import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if !model.pinned.isEmpty {
            Section("Pinned") {
                ForEach(model.pinned, id: \.id) { row($0) }
            }
        }
        ForEach(model.groupedByDay(), id: \.0) { (day, items) in
            Section(day) {
                ForEach(items, id: \.id) { row($0) }
            }
        }
        Divider()
        Button("Search…") {
            SearchWindowOpener.shared.toggleSearchWindow(nil)
        }
        Button("Open data folder") {
            NSWorkspace.shared.open(AppSupport.url())
        }
        Button("Preferences…") {
            PreferencesOpener.shared.show()
        }
        Button("Refresh") {
            model.refresh()
        }
        Divider()
        Button("Quit TerminalHistory") {
            NSApp.terminate(nil)
        }
    }

    @ViewBuilder
    private func row(_ s: Session) -> some View {
        Button {
            model.replay(s)
        } label: {
            HStack {
                Text(s.title ?? s.shell)
                Spacer()
                Button {
                    model.togglePin(s.id)
                } label: {
                    Image(systemName: s.pinned ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
            }
        }
    }
}
