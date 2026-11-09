// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IleDelbe",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "IleDelbeCore"),
        .executableTarget(name: "IleDelbe", dependencies: ["IleDelbeCore"]),
        .testTarget(name: "IleDelbeCoreTests", dependencies: ["IleDelbeCore"]),
    ]
)
