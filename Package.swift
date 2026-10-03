// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LoLPing",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LoLPing", targets: ["LoLPing"])],
    targets: [
        .target(name: "PingCore"),
        .executableTarget(name: "LoLPing", dependencies: ["PingCore"]),
        .executableTarget(name: "PingCoreChecks", dependencies: ["PingCore"], path: "Tests/PingCoreTests")
    ]
)
