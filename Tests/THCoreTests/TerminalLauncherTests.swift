import Testing
import Foundation
@testable import THCore

@Suite struct TerminalLauncherTests {
    @Test func testTerminalAppBuildsAppleScript() {
        let a = TerminalAppLauncher().arguments(for: "echo hi", escape: { _ in "echo hi" })
        #expect(a.count == 2); #expect(a[0] == "-e")
        #expect(a[1].contains("do script"))
    }
    @Test func testITermBuildsAppleScript() {
        let a = ITermLauncher().arguments(for: "echo hi", escape: { _ in "echo hi" })
        #expect(a[1].contains("create window"))
    }
    @Test func testWarpBuildsURL() {
        let a = WarpLauncher().arguments(for: "echo hi", escape: { _ in "echo%20hi" })
        #expect(a[0].hasPrefix("warp://run"))
    }
    @Test func testRegistryResolvesByName() {
        let r = TerminalLauncherRegistry()
        #expect(r.launcher(for: "terminal") != nil)
        #expect(r.launcher(for: "iterm") != nil)
        #expect(r.launcher(for: "warp") != nil)
        #expect(r.launcher(for: "/usr/local/bin/myterm") != nil)
    }
}