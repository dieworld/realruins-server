// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "rr-server",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),

        // 🔵 Swift ORM (queries, models, relations, etc) built on SQLite 3.
        .package(url: "https://github.com/vapor/fluent-mysql.git", from: "3.0.0"),
        
        // 📦 S3 Storage - uncomment it when they add support for custom regions
        .package(url: "https://github.com/dieworld/storage.git", from: "1.0.0-beta")
    ],
    targets: [
        .target(name: "App", dependencies: ["Storage", "FluentMySQL", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

