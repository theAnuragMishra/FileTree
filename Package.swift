// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileTree",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FileTree", targets: ["FileTree"]),
        .executable(name: "ft", targets: ["ft"]),
    ],
    targets: [
        .target(name: "FileTreeCore"),
        .executableTarget(name: "FileTree", dependencies: ["FileTreeCore"]),
        .executableTarget(name: "ft", dependencies: ["FileTreeCore"]),
    ]
)
