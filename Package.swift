// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TerminalHistory",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "THCore", targets: ["THCore"]),
        .executable(name: "th", targets: ["th"]),
    ],
    targets: [
        .executableTarget(name: "th", dependencies: ["THCore"]),
        .target(name: "THCore", resources: [.process("Schema.sql")]),
        .testTarget(name: "THCoreTests", dependencies: ["THCore"]),
    ]
)