import XCTest
@testable import THCore

final class ConfigTests: XCTestCase {
    func testRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("th-cfg-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        var cfg = Config(directory: dir)
        cfg.userShell = "/bin/zsh"
        cfg.defaultTerminal = "iterm"
        cfg.retention = RetentionPolicy(maxAgeDays: 30, maxBytes: 1024)
        cfg.theme = ThemeConfig(iconVariant: .dark, accentHex: "#ff00aa")
        try cfg.save()

        let loaded = Config(directory: dir)
        XCTAssertEqual(loaded.userShell, "/bin/zsh")
        XCTAssertEqual(loaded.defaultTerminal, "iterm")
        XCTAssertEqual(loaded.retention.maxAgeDays, 30)
        XCTAssertEqual(loaded.theme.iconVariant, .dark)
    }
    func testMissingFileReturnsDefaults() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("th-cfg-\(UUID().uuidString)")
        let cfg = Config(directory: dir)
        XCTAssertNil(cfg.userShell)
        XCTAssertEqual(cfg.theme.iconVariant, .auto)
    }
}