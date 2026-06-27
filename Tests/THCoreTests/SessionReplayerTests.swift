import Testing
import Foundation
@testable import THCore

@Suite struct SessionReplayerTests {
    @Test func testReplayPreservesAnsiAndDimsInput() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        try store.insertSession(Session(id: "S", startedAt: 1, shell: "/bin/zsh",
                                        cwdInitial: "/tmp", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        try store.appendEvents(sessionID: "S", events: [
            Event(seq: 0, ts: 1, direction: .out, data: Data("\u{1B}[31mred\u{1B}[0m".utf8)),
            Event(seq: 1, ts: 1, direction: .in,  data: Data("ls".utf8)),
        ])
        let script = try SessionReplayer(store: store).replayScript(for: "S", shellPath: "/bin/zsh", cwdFinal: "/tmp")
        // Output bytes are preserved verbatim via printf %b (ESC bytes pass through).
        #expect(script.contains("\u{1B}[31mred\u{1B}[0m"))
        // Input bytes are wrapped in literal \033 escape sequences for printf to interpret.
        #expect(script.contains("\\033[2mls\\033[0m"))
        #expect(script.contains("cd '/tmp'"))
        #expect(script.contains("exec '/bin/zsh' -l"))
    }
    @Test func testReplaySkipsCdIfCwdNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        try store.insertSession(Session(id: "S", startedAt: 1, shell: "/bin/zsh",
                                        cwdInitial: "/", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        let script = try SessionReplayer(store: store).replayScript(for: "S", shellPath: "/bin/zsh", cwdFinal: nil)
        #expect(!script.contains("cd '"))
    }
}