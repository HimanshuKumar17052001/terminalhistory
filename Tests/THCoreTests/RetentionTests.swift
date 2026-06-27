import Testing
import Foundation
@testable import THCore

@Suite struct RetentionTests {
    @Test func testPrunesByAge() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        try store.insertSession(Session(id: "OLD", startedAt: now - 100*86_400_000,
                                        shell: "/bin/sh", cwdInitial: "/", host: "h",
                                        status: .exited, exitCode: 0, pinned: false,
                                        title: nil, bytesIn: 0, bytesOut: 0))
        try store.insertSession(Session(id: "FRESH", startedAt: now, shell: "/bin/sh",
                                        cwdInitial: "/", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        let r = try Retention(store: store, policy: RetentionPolicy(maxAgeDays: 30, maxBytes: 1_000_000_000)).prune()
        #expect(r.deleted == ["OLD"])
        #expect(try store.session(id: "FRESH") != nil)
    }
    @Test func testPinnedSessionsExemptFromAge() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        try store.insertSession(Session(id: "PIN", startedAt: now - 200*86_400_000,
                                        shell: "/bin/sh", cwdInitial: "/", host: "h",
                                        status: .exited, exitCode: 0, pinned: true,
                                        title: nil, bytesIn: 0, bytesOut: 0))
        let r = try Retention(store: store, policy: RetentionPolicy(maxAgeDays: 30, maxBytes: 1_000_000_000)).prune()
        #expect(r.deleted.isEmpty)
    }
}