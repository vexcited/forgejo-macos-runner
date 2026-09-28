import Foundation
import GuestKit

// what the golden image must offer before anything in it changes.
struct Prerequisites {
  let runnerMajor: Int
  let brewBin: String
  let brewPrefix: String
  let xcodeApp: String

  static func check(runnerVersion: String, sshPublicKey: String, requestedXcode: String) throws
    -> Prerequisites
  {
    Console.log("validating the golden image architecture and prerequisites.")

    guard RunnerToolchain.isSupportedVersion(runnerVersion) else {
      throw ProvisionFailure(message: "forgejo-runner v13 or newer is required.", code: 64)
    }
    let runnerMajor = RunnerToolchain.major(ofVersion: runnerVersion) ?? 0

    guard GuestProvisionInput.isEd25519PublicKey(sshPublicKey) else {
      throw ProvisionFailure(message: "an ed25519 ssh public key is required.", code: 64)
    }

    guard Machine.isARM64() else {
      throw ProvisionFailure(message: "the golden image must run arm64 macos.", code: 1)
    }

    let brewBin = "/opt/homebrew/bin/brew"
    guard FileManager.default.isExecutableFile(atPath: brewBin) else {
      throw ProvisionFailure(message: "homebrew is missing from the golden image.", code: 1)
    }
    let brewPrefix = URL(filePath: brewBin).deletingLastPathComponent()
      .deletingLastPathComponent().path

    let xcodeApp: String
    do {
      xcodeApp = try XcodeLocator.makeDiscovery().find(requested: requestedXcode)
    } catch let error as XcodeDiscoveryError {
      throw ProvisionFailure(message: error.description, code: error.exitCode)
    }
    Console.log("using xcode application \(xcodeApp).")

    try ProcessRunner.stream(
      "/usr/bin/sudo", ["-n", "/usr/bin/true"], environment: ProvisionEnvironment.base)

    return Prerequisites(
      runnerMajor: runnerMajor, brewBin: brewBin, brewPrefix: brewPrefix, xcodeApp: xcodeApp)
  }
}
