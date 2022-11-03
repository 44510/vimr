// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "Commons",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(name: "Commons", targets: ["Commons", "CommonsObjC"]),
  ],
  dependencies: [
    .package(url: "https://github.com/Quick/Nimble", from: "11.1.0"),
  ],
  targets: [
    .target(name: "Commons", dependencies: []),
    .target(name: "CommonsObjC", dependencies: []),
    .testTarget(
      name: "CommonsTests",
      dependencies: ["Commons", "Nimble"],
      resources: [
        .copy("Resources"),
      ]
    ),
  ]
)
