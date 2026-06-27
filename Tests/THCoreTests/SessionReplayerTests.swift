import XCTest
@testable import THCore

final class SessionReplayerTests: XCTestCase {
    func testReplayPreservesAnsiAndDimsInput() throws {
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
        XCTAssertTrue(script.contains("\u{1B}[31mred\u{1B}[0m"))
        XCTAssertTrue(script.contains("\u{1B}[2mls\u{1B}[0m"))
        XCTAssertTrue(script.contains("cd '/tmp'"))
        XCTAssertTrue(script.contains("exec '/bin/zsh' -l"))
    }
    func testReplaySkipsCdIfCwdNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        try store.insertSession(Session(id: "S", startedAt: 1, shell: "/bin/zsh",
                                        cwdInitial: "/", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        let script = try SessionReplayer(store: store).replayScript(for: "S", shellPath: "/bin/zsh", cwdFinal: nil)
        XCTAssertFalse(script.contains("cd '"))
    }
}