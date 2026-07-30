// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TerminalGridApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TerminalGridApp", targets: ["TerminalGridApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.7")
    ],
    targets: [
        .executableTarget(
            name: "TerminalGridApp",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        )
    ]
)
