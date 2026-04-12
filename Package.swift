// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenClawController",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenClawController",
            path: "Sources/OpenClawController"
        )
    ]
)
