// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Vocra",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "Vocra", targets: ["Vocra"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.1")
  ],
  targets: [
    .target(
      name: "VocraCore",
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    ),
    .executableTarget(
      name: "Vocra",
      dependencies: [
        "VocraCore",
        .product(name: "Sparkle", package: "Sparkle")
      ]
    ),
    .testTarget(
      name: "VocraCoreTests",
      dependencies: ["VocraCore"]
    )
  ]
)
