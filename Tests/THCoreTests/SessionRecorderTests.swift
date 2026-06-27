import Testing
import Foundation
@testable import THCore

@Suite struct SessionRecorderTests {
    @Test func testRecordsChildOutput() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let recorder = SessionRecorder(store: store, host: "test")
        try recorder.start(shell: "/bin/sh")
        _ = try PTYCapturer().run(executable: "/bin/sh", args: ["-c", "printf hi; exit 0"],
                                  onOutput: { data, ts in recorder.appendChild(data, at: ts) })
        try recorder.finish(exitCode: 0)
        let events = try store.events(sessionID: recorder.sessionID)
        #expect(!events.isEmpty)
        #expect(String(data: events.first?.data ?? Data(), encoding: .utf8) == "hi")
    }
    @Test func testUpdatesTitleFromFirstInput() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let recorder = SessionRecorder(store: store, host: "test")
        try recorder.start(shell: "/bin/sh")
        recorder.appendUser(Data("git status\n".utf8), at: UInt64(Date().timeIntervalSince1970 * 1000))
        try recorder.finish(exitCode: 0)
        #expect(try store.session(id: recorder.sessionID)?.title == "git status")
    }
}