// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacGestureControl",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacGestureControl", targets: ["MacGestureControl"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacGestureControl",
            path: "Sources/MacGestureControl",
            resources: [.process("Resources")]
        )
    ]
)
