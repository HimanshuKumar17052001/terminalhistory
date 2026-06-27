import XCTest
@testable import THCore

final class GzipCodecTests: XCTestCase {
    func testRoundTripSmall() throws {
        let original = Data("hello world\n".utf8)
        let gz = try GzipCodec.compress(original)
        XCTAssertEqual(try GzipCodec.decompress(gz), original)
    }
    func testRoundTripEmpty() throws {
        let original = Data()
        XCTAssertEqual(try GzipCodec.decompress(try GzipCodec.compress(original)), original)
    }
    func testRoundTripLarge() throws {
        let original = Data((0..<100_000).map { _ in UInt8.random(in: 0...255) })
        let gz = try GzipCodec.compress(original)
        XCTAssertLessThan(gz.count, original.count)
        XCTAssertEqual(try GzipCodec.decompress(gz), original)
    }
    func testDecompressRejectsBadInput() {
        XCTAssertThrowsError(try GzipCodec.decompress(Data([0,1,2,3])))
    }
}