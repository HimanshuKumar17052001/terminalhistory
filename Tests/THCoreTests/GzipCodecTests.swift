import Testing
import Foundation
@testable import THCore

@Suite struct GzipCodecTests {
    @Test func testRoundTripSmall() throws {
        let original = Data("hello world\n".utf8)
        let gz = try GzipCodec.compress(original)
        #expect(try GzipCodec.decompress(gz) == original)
    }
    @Test func testRoundTripEmpty() throws {
        let original = Data()
        #expect(try GzipCodec.decompress(try GzipCodec.compress(original)) == original)
    }
    @Test func testRoundTripLarge() throws {
        let original = Data((0..<100_000).map { _ in UInt8.random(in: 0...255) })
        let gz = try GzipCodec.compress(original)
        // Random data won't compress — we just verify the round-trip is correct.
        #expect(try GzipCodec.decompress(gz) == original)
    }
    @Test func testDecompressRejectsBadInput() {
        #expect(throws: (any Error).self) { try GzipCodec.decompress(Data([0,1,2,3])) }
    }
}