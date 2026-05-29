// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tortoise",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "Tortoise",
            targets: ["Tortoise"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Tortoise"
        ),
    ]
)
