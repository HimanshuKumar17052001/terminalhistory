import Testing
import Foundation
@testable import THCore

@Suite struct ExportTests {
    @Test func testCastExport() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let now: UInt64 = 1_700_000_000_000
        try store.insertSession(Session(id: "S", startedAt: now, shell: "/bin/zsh",
                                        cwdInitial: "/", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        try store.appendEvents(sessionID: "S", events: [
            Event(seq: 0, ts: now, direction: .out, data: Data("hi".utf8)),
        ])
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("out.cast")
        defer { try? FileManager.default.removeItem(at: out) }
        try Export(store: store).cast(sessionID: "S", to: out)
        let text = try String(contentsOf: out)
        #expect(text.contains("\"version\":2"))
        // asciicast v2 uses base64-encoded output payloads.
        #expect(text.contains("aGk="))  // base64("hi")
    }
    @Test func testTxtExport() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        try store.insertSession(Session(id: "S", startedAt: 1, shell: "/bin/zsh",
                                        cwdInitial: "/", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        try store.appendEvents(sessionID: "S", events: [
            Event(seq: 0, ts: 1, direction: .out, data: Data("hello".utf8)),
        ])
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("out.txt")
        defer { try? FileManager.default.removeItem(at: out) }
        try Export(store: store).text(sessionID: "S", to: out)
        #expect(try String(contentsOf: out).contains("hello"))
    }
}