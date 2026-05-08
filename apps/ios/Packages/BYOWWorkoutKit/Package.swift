// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BYOWWorkoutKit",
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
        .library(name: "BYOWDesignSystem", targets: ["BYOWDesignSystem"]),
        .library(name: "BYOWWorkoutKitCore", targets: ["BYOWWorkoutKitCore"]),
        .library(name: "BYOWWorkoutKitNet", targets: ["BYOWWorkoutKitNet"]),
    ],
    targets: [
        .target(
            name: "BYOWDesignSystem",
            path: "Sources/BYOWDesignSystem",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "BYOWWorkoutKitCore",
            dependencies: ["BYOWDesignSystem"],
            path: "Sources/BYOWWorkoutKitCore"
        ),
        .target(
            name: "BYOWWorkoutKitNet",
            dependencies: ["BYOWWorkoutKitCore"],
            path: "Sources/BYOWWorkoutKitNet"
        ),
        .testTarget(
            name: "BYOWWorkoutKitTests",
            dependencies: ["BYOWWorkoutKitCore", "BYOWWorkoutKitNet"],
            path: "Tests/BYOWWorkoutKitTests"
        ),
    ]
)
