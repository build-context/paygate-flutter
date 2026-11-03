// swift-tools-version: 5.9

import PackageDescription

// Swift Package Manager build of the plugin, used when the app has Flutter's
// Swift Package Manager support on. CocoaPods apps keep using
// ../paygate_flutter.podspec, which builds the same sources.
//
// The native SDK pin below must match the podspec's `s.dependency 'Paygate'`
// (see sdks/RELEASING.md, "The cross-SDK pins are easy to forget"). SPM
// resolves it from the tag on build-context/paygate-ios.
let package = Package(
    name: "paygate_flutter",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "paygate-flutter", targets: ["paygate_flutter"])
    ],
    dependencies: [
        .package(url: "https://github.com/build-context/paygate-ios.git", exact: "0.4.0")
    ],
    targets: [
        .target(
            name: "paygate_flutter",
            dependencies: [
                .product(name: "Paygate", package: "paygate-ios")
            ]
        )
    ]
)
