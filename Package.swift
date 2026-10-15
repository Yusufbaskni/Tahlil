// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tahlil",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Tahlil", targets: ["Tahlil"])
    ],
    targets: [
        .target(
            name: "TahlilCore",
            resources: [
                .copy("Resources/scales")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Tahlil",
            dependencies: ["TahlilCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TahlilCoreTests",
            dependencies: ["TahlilCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
