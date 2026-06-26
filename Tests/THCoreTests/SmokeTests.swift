import XCTest
@testable import THCore

final class SmokeTests: XCTestCase {
    func testPackageBuilds() {
        XCTAssertEqual(1 + 1, 2)
    }
}