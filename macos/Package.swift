// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortatoMenuBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PortatoMenuBar", targets: ["PortatoMenuBar"])],
    targets: [
        .target(name: "PortatoCore"),
        .executableTarget(name: "PortatoMenuBar", dependencies: ["PortatoCore"]),
        .executableTarget(name: "PortatoCoreChecks", dependencies: ["PortatoCore"], path: "Tests/PortatoCoreTests")
    ]
)
