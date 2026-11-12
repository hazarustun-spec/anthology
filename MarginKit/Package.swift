// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarginKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "MarginCore", targets: ["MarginCore"]),
        .executable(name: "margin-mcp", targets: ["margin-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
    ],
    targets: [
        .target(name: "MarginCore"),
        .executableTarget(
            name: "margin-mcp",
            dependencies: ["MarginCore", .product(name: "MCP", package: "swift-sdk")]
        ),
        .testTarget(name: "MarginCoreTests", dependencies: ["MarginCore"]),
    ]
)
