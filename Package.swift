// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyCustomMenu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MyCustomMenu", targets: ["MyCustomMenu"])
    ],
    targets: [
        .executableTarget(
            name: "MyCustomMenu",
            path: "Sources"
        )
    ]
)
