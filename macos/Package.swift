// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DropAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DropAgentShelf", targets: ["DropAgentShelf"]),
        .library(name: "DropAgentIngest", targets: ["DropAgentIngest"]),
        .library(name: "DropAgentCapture", targets: ["DropAgentCapture"]),
        .library(name: "DropAgentAgent", targets: ["DropAgentAgent"]),
        .library(name: "DropAgentJob", targets: ["DropAgentJob"]),
        .library(name: "DropAgentTUI", targets: ["DropAgentTUI"]),
        .library(name: "DropAgentPasteboard", targets: ["DropAgentPasteboard"]),
        .executable(name: "DropAgent", targets: ["DropAgent"]),
        .executable(name: "DropAgentCheck", targets: ["DropAgentCheck"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "DropAgentShelf",
            path: "Packages/DropAgentShelf/Sources"
        ),
        .target(
            name: "DropAgentCapture",
            path: "Packages/DropAgentCapture/Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("WebKit"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
        .target(
            name: "DropAgentIngest",
            dependencies: ["DropAgentShelf", "DropAgentCapture"],
            path: "Packages/DropAgentIngest/Sources",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .target(
            name: "DropAgentAgent",
            path: "Packages/DropAgentAgent/Sources"
        ),
        .target(
            name: "DropAgentJob",
            dependencies: ["DropAgentShelf", "DropAgentAgent"],
            path: "Packages/DropAgentJob/Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("Vision"),
            ]
        ),
        .target(
            name: "DropAgentTUI",
            dependencies: ["DropAgentShelf", "DropAgentAgent"],
            path: "Packages/DropAgentTUI/Sources"
        ),
        .target(
            name: "DropAgentPasteboard",
            dependencies: ["DropAgentShelf"],
            path: "Packages/DropAgentPasteboard/Sources",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .executableTarget(
            name: "DropAgentCheck",
            dependencies: [
                "DropAgentShelf",
                "DropAgentIngest",
                "DropAgentCapture",
                "DropAgentAgent",
                "DropAgentJob",
                "DropAgentTUI",
                "DropAgentPasteboard",
            ],
            path: "Check"
        ),
        .executableTarget(
            name: "DropAgent",
            dependencies: [
                "DropAgentShelf",
                "DropAgentIngest",
                "DropAgentAgent",
                "DropAgentJob",
                "DropAgentTUI",
                "DropAgentPasteboard",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "App",
            exclude: ["Info.plist", "DropAgent.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("PDFKit"),
            ]
        ),
    ]
)
