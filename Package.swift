// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleEditor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SimpleEditor", targets: ["SimpleEditor"])
    ],
    targets: [
        .executableTarget(
            name: "SimpleEditor",
            path: "Sources/SimpleEditor"
        )
    ]
)
