// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

func getDepandencies() -> [Package.Dependency] {
#if true
    // Local dependencies for development
    [
        .package(path: "../../WADKit"),
        .package(path: "../../Lemur"),
        .package(path: "../../Cashmere"),
    ]
#else
    // Local dependencies for release
    [
        .package(url: "https://github.com/EvgenijLutz/WADKit.git", exact: .init(1, 0, 0)),
        .package(url: "https://github.com/EvgenijLutz/Lemur.git", exact: .init(1, 0, 0)),
        .package(url: "https://github.com/EvgenijLutz/Cashmere.git", exact: .init(1, 0, 0)),
    ]
#endif
}


let package = Package(
    name: "TRToolsDependencies",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TRToolsDependencies",
            targets: ["TRToolsDependencies"]
        ),
    ],
    dependencies: getDepandencies(),
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TRToolsDependencies",
            dependencies: [
                .product(name: "WADKit", package: "WADKit"),
                .product(name: "Lemur", package: "Lemur", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "Cashmere", package: "Cashmere"),
            ]
        ),
    ]
)
