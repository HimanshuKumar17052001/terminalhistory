import XCTest
@testable import THCore

final class ULIDTests: XCTestCase {
    func testGenerateIsLexicographicallyOrdered() {
        let a = ULID.generate(at: 1_700_000_000_000)
        let b = ULID.generate(at: 1_700_000_001_000)
        XCTAssertLessThan(a, b)
    }
    func testLengthIs26() { XCTAssertEqual(ULID.generate(at: 0).count, 26) }
    func testCrockfordAlphabet() {
        let id = ULID.generate(at: 0)
        for c in id { XCTAssertFalse("ILOU".contains(c), "forbidden char \(c)") }
    }
    func testParseRoundTrip() {
        let ts: UInt64 = 1_700_000_000_000
        let id = ULID.generate(at: ts)
        let parsed = try! ULID.parse(id)
        XCTAssertEqual(parsed.timestamp, ts)
    }
    func testParseRejectsBadLength() { XCTAssertThrowsError(try ULID.parse("abc")) }

    func testParseRoundTripRandomness() throws {
        let ts: UInt64 = 1_700_000_000_000
        let rng: [UInt8] = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xA5, 0x5A]
        let id = ULID.generate(at: ts, randomness: rng)
        let parsed = try ULID.parse(id)
        XCTAssertEqual(parsed.randomness, rng)
    }

    func testParseRoundTripAllBytes() throws {
        let ts: UInt64 = 1_700_000_000_000
        for byte in 0..<256 {
            let rng = [UInt8](repeating: UInt8(byte), count: 10)
            let id = ULID.generate(at: ts, randomness: rng)
            let parsed = try ULID.parse(id)
            XCTAssertEqual(parsed.randomness, rng, "byte value \(byte) failed round-trip")
        }
    }
}