import Foundation
import Testing
@testable import THCore

@Suite struct PTYCapturerTests {
    @Test func testCapturesChildStdout() throws {
        var captured: [Data] = []
        let exitCode = try PTYCapturer().run(
            executable: "/bin/sh", args: ["-c", "printf hello; exit 7"],
            onOutput: { data, _ in captured.append(data) })
        #expect(exitCode == 7)
        #expect(String(data: captured.reduce(Data(), +), encoding: .utf8) == "hello")
    }
}
