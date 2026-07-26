// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Internd",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Internd", targets: ["EarlyTalentScout"])
    ],
    targets: [
        .executableTarget(
            name: "EarlyTalentScout",
            path: "AppSource/EarlyTalentScout",
            resources: [.copy("Resources")]
        )
    ]
)
