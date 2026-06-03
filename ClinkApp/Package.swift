// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClinkApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Clink", targets: ["Clink"]),
    ],
    targets: [
        .executableTarget(
            name: "Clink",
            dependencies: ["ClinkCore"],
            path: "Sources/Clink",
            resources: [.copy("Resources")]
        ),
        .target(
            name: "ClinkCore",
            path: "Sources/ClinkCore"
        ),
    ]
)
