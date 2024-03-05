// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-concurrency-primitives",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Primitives",
            targets: ["Primitives"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Primitives",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ]),
        .testTarget(
            name: "Primitives-Tests",
            dependencies: ["Primitives"],
            path: "Tests/PrimitivesTests"
        )
    ]
)
