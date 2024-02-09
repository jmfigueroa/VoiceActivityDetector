// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "VoiceActivityDetectorSPM",
    products: [
        .library(
            name: "VoiceActivityDetectorSPM",
            targets: ["VoiceActivityDetector", "libfvad"]),
    ],
    targets: [
        .target(
            name: "VoiceActivityDetector",
            dependencies: ["libfvad"],
            path: "Sources/VoiceActivityDetector",
            exclude: ["../libfvad"]), // no C files included in the Swift target
        .target(
            name: "libfvad",
            dependencies: [],
            path: "Sources/libfvad",
            exclude: ["../VoiceActivityDetector"], // no Swift files included in the C target
            cSettings: [
                .headerSearchPath("include"),
            ]),
        .testTarget(
            name: "VoiceActivityDetectorTests",
            dependencies: ["VoiceActivityDetector"],
            resources: [
                .process("Resources/Audio")  
            ]
        ),
    ]
)
