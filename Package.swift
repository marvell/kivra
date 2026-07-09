// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kivra",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Kivra", targets: ["Kivra"])
    ],
    targets: [
        .executableTarget(name: "Kivra"),
        .testTarget(name: "KivraTests", dependencies: ["Kivra"])
    ]
)
