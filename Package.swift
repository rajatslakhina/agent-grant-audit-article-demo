// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentGrantAudit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AgentGrantAudit", targets: ["AgentGrantAudit"])
    ],
    targets: [
        .target(name: "AgentGrantAudit"),
        .testTarget(name: "AgentGrantAuditTests", dependencies: ["AgentGrantAudit"])
    ]
)
