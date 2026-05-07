// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FBBWorkoutKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        // macOS only so `swift build` (which defaults to host) compiles cleanly
        // for SourceKit and CI; the Xcode targets that link the package are
        // iOS / watchOS only.
        .macOS(.v15),
    ],
    products: [
        .library(name: "FBBDesignSystem", targets: ["FBBDesignSystem"]),
        .library(name: "FBBWorkoutKitCore", targets: ["FBBWorkoutKitCore"]),
        .library(name: "FBBWorkoutKitNet", targets: ["FBBWorkoutKitNet"]),
    ],
    targets: [
        .target(
            name: "FBBDesignSystem",
            path: "Sources/FBBDesignSystem",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "FBBWorkoutKitCore",
            dependencies: ["FBBDesignSystem"],
            path: "Sources/FBBWorkoutKitCore"
        ),
        .target(
            name: "FBBWorkoutKitNet",
            dependencies: ["FBBWorkoutKitCore"],
            path: "Sources/FBBWorkoutKitNet"
        ),
        .testTarget(
            name: "FBBWorkoutKitTests",
            dependencies: ["FBBWorkoutKitCore", "FBBWorkoutKitNet"],
            path: "Tests/FBBWorkoutKitTests"
        ),
    ]
)
