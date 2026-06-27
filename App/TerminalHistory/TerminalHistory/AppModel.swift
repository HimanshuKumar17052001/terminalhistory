import Foundation
import Combine
import THCore

@MainActor
final class AppModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var pinned: [Session] = []
    @Published var searchResults: [SearchResult] = []
    @Published var searchQuery: String = ""
    @Published var themeVariant: IconVariant = .auto
    @Published var accentHex: String = "system"
    private let storeURL: URL

    init() {
        self.storeURL = AppSupport.url().appendingPathComponent("store.sqlite")
        refresh()
        refreshTheme()
    }

    func refresh() {
        do {
            let store = try SessionStore(url: storeURL)
            let recent = try store.recentSessions(limit: 50)
            sessions = recent
            pinned = recent.filter { $0.pinned }
            try store.close()
        } catch {
            sessions = []
            pinned = []
        }
    }

    func refreshTheme() {
        let cfg = Config(directory: AppSupport.configDirectory())
        themeVariant = cfg.theme.iconVariant
        accentHex = cfg.theme.accentHex
    }

    func togglePin(_ id: String) {
        do {
            let store = try SessionStore(url: storeURL)
            let s = try store.session(id: id)
            try store.setPinned(id, pinned: !(s?.pinned ?? false))
            try store.close()
            refresh()
        } catch {}
    }

    func groupedByDay() -> [(String, [Session])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let groups = Dictionary(grouping: sessions) {
            fmt.string(from: Date(timeIntervalSince1970: TimeInterval($0.startedAt) / 1000))
        }
        return groups.sorted { $0.key > $1.key }
    }

    func replay(_ session: Session) {
        do {
            let store = try SessionStore(url: storeURL)
            let cfg = Config(directory: AppSupport.configDirectory())
            let name = cfg.defaultTerminal ?? TerminalLauncherRegistry().detectInstalled()
            let script = try SessionReplayer(store: store).replayScript(
                for: session.id, shellPath: session.shell, cwdFinal: session.cwdFinal
            )
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", terminalInvocation(name: name, script: script)]
            try task.run()
            try store.close()
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
        }
    }

    private func terminalInvocation(name: String, script: String) -> String {
        switch name {
        case "warp":
            let e = script.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? script
            return "/usr/bin/open 'warp://run?command=\(e)'"
        case "terminal":
            let e = script.replacingOccurrences(of: "\"", with: "\\\"")
            return "/usr/bin/osascript -e 'tell application \"Terminal\" to do script \"\(e)\"'"
        case "iterm":
            let e = script.replacingOccurrences(of: "\"", with: "\\\"")
            return "/usr/bin/osascript -e 'tell application \"iTerm\" to create window with default profile command \"\(e)\"'"
        default:
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sh")
            try? script.write(to: tmp, atomically: true, encoding: .utf8)
            return "\(name) <\(tmp.path)"
        }
    }

    func runSearch() {
        guard !searchQuery.isEmpty else { searchResults = []; return }
        do {
            let store = try SessionStore(url: storeURL)
            searchResults = try Search(store: store).query(searchQuery, limit: 50)
            try store.close()
        } catch { searchResults = [] }
    }
}
