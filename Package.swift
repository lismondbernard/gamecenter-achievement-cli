// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameCenterCLI",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", exact: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "GameCenterCLI",
            dependencies: [
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk")
            ],
            path: "Sources/GameCenterCLI"
        )
    ]
)
