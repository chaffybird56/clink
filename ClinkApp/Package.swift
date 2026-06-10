// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClinkApp",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .executable(name: "Clink", targets: ["Clink"]),
        // ClinkCore is platform-agnostic (Accelerate + AVFoundation + Core ML)
        // so the same scoring engine can ship in an iOS target.
        .library(name: "ClinkCore", targets: ["ClinkCore"]),
    ],
    targets: [
        .executableTarget(
            name: "Clink",
            dependencies: ["ClinkCore"],
            path: "Sources/Clink",
            resources: [.copy("Resources")],
            linkerSettings: [
                // Embed Info.plist (NSMicrophoneUsageDescription) so the
                // record-your-baseline flow can prompt for mic access.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Clink/Info.plist",
                ], .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ClinkCore",
            path: "Sources/ClinkCore"
        ),
        .testTarget(
            name: "ClinkCoreTests",
            dependencies: ["ClinkCore"],
            path: "Tests/ClinkCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
