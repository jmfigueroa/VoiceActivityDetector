// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VoiceActivityDetector",
    products: [
        .library(name: "VoiceActivityDetector", targets: ["VoiceActivityDetector"])
    ],
    targets: [
        .target(name: "VoiceActivityDetector", path: "VoiceActivityDetector", publicHeadersPath: ""),
    ],
    swiftLanguageVersions: [.v5]
)
