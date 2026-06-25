// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WindowSwitcher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WindowSwitcher",
            path: "Sources/WindowSwitcher",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
