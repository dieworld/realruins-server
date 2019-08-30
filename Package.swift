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
        .package(url: "https://github.com/dieworld/storage.git", from: "1.0.0-beta"),
        
        // 🗄 GZip implementation for swift
        .package(url: "https://github.com/1024jp/GzipSwift.git", from: "4.0.4"),
        
        // 🍃 An expressive, performant, and extensible templating language built for Swift.
        .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),
        
        // fixed swift nio version to prevent some errors
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .exact("1.3.2")),
        .package(url: "https://github.com/vapor/http.git", .exact("3.1.6")),
    ],
    targets: [
        .target(name: "App", dependencies: ["Storage", "Leaf", "Gzip", "FluentMySQL", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

