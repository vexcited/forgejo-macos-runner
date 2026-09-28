import Foundation

enum ToolchainSetup {
  static func install(_ prerequisites: Prerequisites, brewEnvironment: [String: String]) throws {
    let baseEnvironment = ProvisionEnvironment.base
    let brewPrefix = prerequisites.brewPrefix

    Console.log("selecting xcode and accepting its license.")
    try ProcessRunner.stream(
      "/usr/bin/sudo",
      ["/usr/bin/xcode-select", "--switch", prerequisites.xcodeApp + "/Contents/Developer"],
      environment: baseEnvironment)
    try ProcessRunner.stream(
      "/usr/bin/sudo", ["/usr/bin/xcodebuild", "-license", "accept"], environment: baseEnvironment)
    Console.log("completing xcode first-launch setup.")
    try ProcessRunner.stream(
      "/usr/bin/sudo", ["/usr/bin/xcodebuild", "-runFirstLaunch"], environment: baseEnvironment)

    Console.log("installing go and node with homebrew.")
    try ProcessRunner.stream(
      prerequisites.brewBin, ["install", "go", "node"], environment: brewEnvironment)

    Console.log("reporting installed tool versions.")
    try ProcessRunner.stream("/usr/bin/xcodebuild", ["-version"], environment: brewEnvironment)
    try ProcessRunner.stream(brewPrefix + "/bin/node", ["--version"], environment: brewEnvironment)
    try ProcessRunner.stream(brewPrefix + "/bin/go", ["version"], environment: brewEnvironment)
  }
}
