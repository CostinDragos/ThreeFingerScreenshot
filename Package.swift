// swift-tools-version: 6.3.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ThreeFingerScreenshot",
  platforms: [
    .iOS(.v14),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to
    // other packages.
    .library(
      name: "ThreeFingerScreenshot",
      targets: ["ThreeFingerScreenshot"],
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "ThreeFingerScreenshot",
    ),
    .testTarget(
      name: "ThreeFingerScreenshotTests",
      dependencies: ["ThreeFingerScreenshot"],
    ),
  ],
  swiftLanguageModes: [.v6],
)
