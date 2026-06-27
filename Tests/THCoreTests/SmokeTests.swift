import Testing
import Foundation
@testable import THCore

@Suite struct SmokeTests {
    @Test func packageBuilds() {
        #expect(1 + 1 == 2)
    }
}
