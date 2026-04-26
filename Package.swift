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
  targets: [
    .target(
      name: "VocraCore",
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    ),
    .executableTarget(
      name: "Vocra",
      dependencies: ["VocraCore"]
    ),
    .testTarget(
      name: "VocraCoreTests",
      dependencies: ["VocraCore"]
    )
  ]
)
