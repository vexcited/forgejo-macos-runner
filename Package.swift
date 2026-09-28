// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ForgejoRunner",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "ForgejoRunner", targets: ["ForgejoRunner"]),
    .executable(name: "forgejo-one-job", targets: ["ForgejoOneJob"]),
    .executable(name: "forgejo-guest-provision", targets: ["GuestProvision"]),
  ],
  targets: [
    .executableTarget(
      name: "ForgejoRunner",
      dependencies: ["GuestKit"],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]
    ),
    .target(
      name: "GuestKit",
      swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
    ),
    .executableTarget(
      name: "ForgejoOneJob",
      dependencies: ["GuestKit"],
      swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
    ),
    .executableTarget(
      name: "GuestProvision",
      dependencies: ["GuestKit"],
      swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
    ),
  ]
)
