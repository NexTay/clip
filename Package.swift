// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NextayClip",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NextayClip", targets: ["NextayClip"])],
    targets: [
        .executableTarget(name: "NextayClip", resources: [.process("Resources")], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("SwiftUI"), .linkedFramework("Carbon"),
            .linkedFramework("ServiceManagement")
        ])
    ]
)
