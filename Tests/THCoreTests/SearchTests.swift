import XCTest
@testable import THCore

final class SearchTests: XCTestCase {
    func testSearchFindsTermInOutput() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try SessionStore(url: url)
        let now: UInt64 = 1_700_000_000_000
        try store.insertSession(Session(id: "S1", startedAt: now, shell: "/bin/zsh",
                                        cwdInitial: "/", host: "h", status: .exited,
                                        exitCode: 0, pinned: false, title: nil, bytesIn: 0, bytesOut: 0))
        try store.appendEvents(sessionID: "S1", events: [
            Event(seq: 0, ts: now, direction: .out, data: Data("hello world".utf8)),
        ])
        let results = try Search(store: store).query("hello", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.sessionID, "S1")
        XCTAssertTrue(results.first?.snippet.contains("hello") ?? false)
    }
}