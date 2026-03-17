// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MarkPush",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MarkPush", targets: ["MarkPush"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.5.0"),
        .package(url: "https://github.com/twostraws/CodeScanner", from: "2.5.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "MarkPush",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Splash", package: "Splash"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "CodeScanner", package: "CodeScanner"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            path: "MarkPush"
        ),
        .testTarget(
            name: "MarkPushTests",
            dependencies: ["MarkPush"],
            path: "MarkPushTests"
        ),
    ]
)
