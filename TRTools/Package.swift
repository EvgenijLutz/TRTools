// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TRTools",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .custom("Windows", versionString: "10")
    ],
    products: [
        .library(
            name: "TRTools",
            targets: ["TRTools"]
        ),
        .executable(
            name: "WADEditorCLI",
            targets: [
                "WADEditorCLI"
            ]
        )
    ],
    dependencies: [
        .package(name: "TRToolsDependencies", path: "../TRToolsDependencies")
    ],
    targets: [
        .target(
            name: "TRTools",
            dependencies: [
                .product(name: "TRToolsDependencies", package: "TRToolsDependencies")
            ]
        ),
        
        .executableTarget(
            name: "WADEditorCLI",
            dependencies: [
                .target(name: "TRTools")
            ]
        )
    ]
)
