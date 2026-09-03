// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-sound-classifier",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [.library(name: "SoundClassifier", targets: ["SoundClassifier"])],
    targets: [
        .target(name: "SoundClassifier"),
        .testTarget(name: "SoundClassifierTests", dependencies: ["SoundClassifier"]),
    ]
)
