// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clipstack",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic with no AppKit, so it can be unit tested.
        .target(name: "ClipstackCore"),
        .executableTarget(name: "Clipstack", dependencies: ["ClipstackCore"]),
        .testTarget(name: "ClipstackCoreTests", dependencies: ["ClipstackCore"]),
    ]
)
