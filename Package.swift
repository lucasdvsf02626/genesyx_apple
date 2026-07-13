// swift-tools-version: 5.9
import PackageDescription

// GenesyxCore — the pure, UI-free domain layer (models, cycle engine, pH + content logic),
// translated from the Android `domain/` package. Kept dependency-free so it builds and tests
// with `swift test` on any Mac (no Xcode project needed) and is reused by the SwiftUI app target.
let package = Package(
    name: "GenesyxCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GenesyxCore", targets: ["GenesyxCore"]),
    ],
    targets: [
        .target(name: "GenesyxCore"),
        .testTarget(
            name: "GenesyxCoreTests",
            dependencies: ["GenesyxCore"],
            resources: [.process("Resources/tracking_test_vectors.json")]
        ),
    ]
)
