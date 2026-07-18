// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "LookinServer",
    platforms: [
        .iOS(.v9), .macOS(.v10_15), .tvOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LookinServer",
            targets: ["LookinServer"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "603.0.2"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LookinServer",
            dependencies: [.target(name: "LookinServerSwift")],
            path: "Src/Main",
            // Wireless transport is intentionally CocoaPods-only for now. Keeping it
            // out of the default product prevents local-network access in normal SPM builds.
            exclude: ["Shared/Channel"],
            publicHeadersPath: "",
            cSettings: [
                .headerSearchPath("**"),
                .headerSearchPath("Server"),
                .headerSearchPath("Server/Category"),
                .headerSearchPath("Server/Connection"),
                .headerSearchPath("Server/Connection/RequestHandler"),
                .headerSearchPath("Server/Inspect"),
                .headerSearchPath("Server/Others"),
                .headerSearchPath("Server/Perspective"),
                .headerSearchPath("Shared"),
                .headerSearchPath("Shared/Category"),
                .headerSearchPath("Shared/Message"),
                .headerSearchPath("Shared/Peertalk"),
            ],
            cxxSettings: [
                .define("SHOULD_COMPILE_LOOKIN_SERVER", to: "1", .when(configuration: .debug)),
                .define("SPM_LOOKIN_SERVER_ENABLED", to: "1", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "LookinServerSwift",
            dependencies: [
                .target(name: "LookinServerBase"),
                .target(name: "LookinServerMacros"),
            ],
            path: "Src/Swift",
            cxxSettings: [
                .define("SHOULD_COMPILE_LOOKIN_SERVER", to: "1", .when(configuration: .debug)),
                .define("SPM_LOOKIN_SERVER_ENABLED", to: "1", .when(configuration: .debug))
            ],
            swiftSettings: [
                .define("SHOULD_COMPILE_LOOKIN_SERVER", .when(configuration: .debug)),
                .define("SPM_LOOKIN_SERVER_ENABLED", .when(configuration: .debug))
            ]
        ),
        .macro(
            name: "LookinServerMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
            path: "Src/Macros"
        ),
        .target(
            name: "LookinServerBase",
            dependencies: [],
            path: "Src/Base",
            publicHeadersPath: "",
            cxxSettings: [
                .define("SHOULD_COMPILE_LOOKIN_SERVER", to: "1", .when(configuration: .debug))
            ]
        )
    ]
)
