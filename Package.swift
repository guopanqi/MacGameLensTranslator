// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "MacGameLensTranslator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacGameLensTranslator",
            path: "Sources/MacGameLensTranslator",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MacGameLensTranslatorTests",
            dependencies: ["MacGameLensTranslator"],
            path: "Tests"
        )
    ]
)
