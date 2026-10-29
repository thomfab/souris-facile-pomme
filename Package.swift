// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SourisFacile",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SourisFacile",
            path: "Sources/SourisFacile"
        ),
        .testTarget(
            name: "SourisFacileTests",
            dependencies: ["SourisFacile"],
            path: "Tests/SourisFacileTests"
        ),
    ]
)
