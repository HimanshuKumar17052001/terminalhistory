import XCTest
@testable import THCore

final class TerminalLauncherTests: XCTestCase {
    func testTerminalAppBuildsAppleScript() {
        let a = TerminalAppLauncher().arguments(for: "echo hi", escape: { _ in "echo hi" })
        XCTAssertEqual(a.count, 2); XCTAssertEqual(a[0], "-e")
        XCTAssertTrue(a[1].contains("do script"))
    }
    func testITermBuildsAppleScript() {
        let a = ITermLauncher().arguments(for: "echo hi", escape: { _ in "echo hi" })
        XCTAssertTrue(a[1].contains("create window"))
    }
    func testWarpBuildsURL() {
        let a = WarpLauncher().arguments(for: "echo hi", escape: { "echo%20hi" })
        XCTAssertTrue(a[0].hasPrefix("warp://run"))
    }
    func testRegistryResolvesByName() {
        let r = TerminalLauncherRegistry()
        XCTAssertNotNil(r.launcher(for: "terminal"))
        XCTAssertNotNil(r.launcher(for: "iterm"))
        XCTAssertNotNil(r.launcher(for: "warp"))
        XCTAssertNotNil(r.launcher(for: "/usr/local/bin/myterm"))
    }
}