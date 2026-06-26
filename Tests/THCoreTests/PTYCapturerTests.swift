import XCTest
@testable import THCore

final class PTYCapturerTests: XCTestCase {
    func testCapturesChildStdout() throws {
        var captured: [Data] = []
        let exitCode = try PTYCapturer().run(
            executable: "/bin/sh", args: ["-c", "printf hello; exit 7"],
            onOutput: { data, _ in captured.append(data) })
        XCTAssertEqual(exitCode, 7)
        XCTAssertEqual(String(data: captured.reduce(Data(), +), encoding: .utf8), "hello")
    }
}
