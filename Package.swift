// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleSay",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppleSayCore", targets: ["AppleSayCore"]),
        .executable(name: "AppleSay", targets: ["AppleSay"])
    ],
    targets: [
        .target(name: "AppleSayCore"),
        .executableTarget(name: "AppleSay", dependencies: ["AppleSayCore"]),
        .testTarget(name: "AppleSayCoreTests", dependencies: ["AppleSayCore"])
    ],
    swiftLanguageModes: [.v6]
)
