// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocCViewer",
    platforms: [.macOS(.v15), .iOS(.v18), .visionOS(.v2)],
    products: [
        .library(
            name: "DocCViewer",
            targets: ["DocCViewer"]
        ),
        .library(name: "BundleAppSourceProvider", targets: ["BundleAppSourceProvider"]),
    ],
    targets: [
        .target(name: "DocCViewer",
                dependencies: ["DocCViewerCore"]),

        .target(name: "BundleAppSourceProvider",
                dependencies: ["DocCViewerCore"],
                resources: [
                    .copy("Resources"),
                ]),

        .target(name: "DocCViewerCore"),
    ]
)
