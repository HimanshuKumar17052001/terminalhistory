import Testing
import Foundation
@testable import THCore

@Suite struct ConfigTests {
    @Test func testRoundTrip() throws {
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
        #expect(loaded.userShell == "/bin/zsh")
        #expect(loaded.defaultTerminal == "iterm")
        #expect(loaded.retention.maxAgeDays == 30)
        #expect(loaded.theme.iconVariant == .dark)
    }
    @Test func testMissingFileReturnsDefaults() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("th-cfg-\(UUID().uuidString)")
        let cfg = Config(directory: dir)
        #expect(cfg.userShell == nil)
        #expect(cfg.theme.iconVariant == .auto)
    }
}