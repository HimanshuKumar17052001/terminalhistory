import XCTest
@testable import THCore

final class CLISkeletonTests: XCTestCase {
    func testParserSplitsSubcommand() {
        let p = ArgumentParser(args: ["list", "--limit", "5"])
        XCTAssertEqual(p.subcommand, "list"); XCTAssertEqual(p.flags["limit"], "5")
    }
    func testParserDefaultsToHelp() { XCTAssertNil(ArgumentParser(args: []).subcommand) }
    func testParserParsesLongFlag() {
        let p = ArgumentParser(args: ["pin", "ABC", "--pinned"])
        XCTAssertEqual(p.subcommand, "pin"); XCTAssertEqual(p.positional.first, "ABC")
        XCTAssertEqual(p.flags["pinned"], "true")
    }
}