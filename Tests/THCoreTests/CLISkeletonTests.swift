import Testing
import Foundation
@testable import THCore

@Suite struct CLISkeletonTests {
    @Test func testParserSplitsSubcommand() {
        let p = ArgumentParser(args: ["list", "--limit", "5"])
        #expect(p.subcommand == "list")
        #expect(p.flags["limit"] == "5")
    }
    @Test func testParserDefaultsToHelp() {
        #expect(ArgumentParser(args: []).subcommand == nil)
    }
    @Test func testParserParsesLongFlag() {
        let p = ArgumentParser(args: ["pin", "ABC", "--pinned"])
        #expect(p.subcommand == "pin")
        #expect(p.positional.first == "ABC")
        #expect(p.flags["pinned"] == "true")
    }
}
