import Testing
import Foundation
@testable import THCore

@Suite struct SessionStoreTests {
    @Test func testOpenCreatesSchema() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try SessionStore(url: url)
    }
    @Test func testInsertAndFetchSession() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let s = Session(id: "S1", startedAt: 1, shell: "/bin/zsh", cwdInitial: "/tmp",
                        host: "h", status: .active, exitCode: nil, pinned: false,
                        title: nil, bytesIn: 0, bytesOut: 0)
        try store.insertSession(s)
        let loaded = try store.session(id: "S1")
        #expect(loaded?.shell == "/bin/zsh")
        #expect(loaded?.status == .active)
    }
    @Test func testAppendAndFetchEvents() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        try store.insertSession(Session(id: "S1", startedAt: 1, shell: "/bin/sh",
                                        cwdInitial: "/", host: "h", status: .active,
                                        exitCode: nil, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        try store.appendEvents(sessionID: "S1", events: [
            Event(seq: 0, ts: 1, direction: .out, data: Data("hi".utf8)),
            Event(seq: 1, ts: 2, direction: .in,  data: Data("ls".utf8)),
        ])
        let events = try store.events(sessionID: "S1")
        #expect(events.count == 2)
        #expect(events[0].direction == .out)
    }
    @Test func testListRecentSessions() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        for i in 0..<5 {
            try store.insertSession(Session(id: "S\(i)", startedAt: UInt64(i) * 1000,
                                            shell: "/bin/sh", cwdInitial: "/", host: "h",
                                            status: .exited, exitCode: 0, pinned: false,
                                            title: nil, bytesIn: 0, bytesOut: 0))
        }
        let recent = try store.recentSessions(limit: 3)
        #expect(recent.count == 3)
        #expect(recent.first?.id == "S4")
    }
    @Test func testMarkStaleActiveSessionsCrashed() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        try store.insertSession(Session(
            id: "S1",
            startedAt: UInt64(Date().timeIntervalSince1970 * 1000) - UInt64(48 * 3600 * 1000),
            shell: "/bin/sh", cwdInitial: "/", host: "h",
            status: .active, exitCode: nil, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        try store.markStaleActiveSessionsCrashed(olderThanHours: 24)
        let s = try store.session(id: "S1")
        #expect(s?.status == .crashed)
    }
}
