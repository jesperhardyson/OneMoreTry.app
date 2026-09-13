// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "OMTKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "OMTCore", targets: ["OMTCore"]),
    ],
    targets: [
        // OMTCore importerar ingenting — inte UIKit, inte Metal, inte Foundation.
        // Se CLAUDE.md. Det är vad som gor den testbar headless och Linux-ren.
        .target(
            name: "OMTCore",
            swiftSettings: [.defaultIsolation(nil), .treatAllWarnings(as: .error)]
        ),
        .testTarget(name: "OMTCoreTests", dependencies: ["OMTCore"]),
    ]
)
