// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XXPhotoPicker",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "XXPhotoPicker",
            targets: ["XXPhotoPicker"]),
    ],
    targets: [
        .target(
            name: "XXPhotoPicker",
            resources: [
                .process("Resources/XXPhotoPicker.bundle"),
                .copy("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .define("HXPICKER_ENABLE_SPM"),
                .define("HXPICKER_ENABLE_PICKER"),
            ]),
    ]
)
