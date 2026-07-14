// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kivra",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Kivra", targets: ["Kivra"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.4"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.0"),
    ],
    targets: [
        .executableTarget(
            name: "Kivra",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ])
            ]
        ),
        .testTarget(name: "KivraTests", dependencies: ["Kivra"]),
    ]
)
