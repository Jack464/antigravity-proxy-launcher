// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "AntigravityProxyLauncher",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "AntigravityProxyLauncher", targets: ["LauncherApp"])],
    targets: [
        .target(name: "LauncherCore"),
        .executableTarget(name: "LauncherApp", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"])
    ],
    swiftLanguageVersions: [.v5]
)
