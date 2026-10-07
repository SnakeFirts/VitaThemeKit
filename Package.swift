// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VitaThemeKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "VitaThemeKit", targets: ["VitaThemeKit"]),
        .executable(name: "vitaframe", targets: ["vitaframe"]),
        .executable(name: "VitaThemeMaker", targets: ["VitaThemeMaker"])
    ],
    targets: [
        .target(name: "VitaThemeKit"),
        .executableTarget(name: "vitaframe", dependencies: ["VitaThemeKit"]),
        .executableTarget(
            name: "VitaThemeMaker",
            dependencies: ["VitaThemeKit"],
            resources: [.process("Media.xcassets")]
        ),
        .testTarget(name: "VitaThemeKitTests", dependencies: ["VitaThemeKit"])
    ]
)
