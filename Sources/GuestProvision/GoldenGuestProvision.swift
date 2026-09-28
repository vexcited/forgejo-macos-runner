import Foundation

// runs every provisioning step in order and turns the outcome into an exit code.
struct GoldenGuestProvision {
  let runnerVersion: String
  let sshPublicKey: String
  let requestedXcode: String

  func run() -> Int32 {
    let runnerBuild = RunnerBuild()
    do {
      try provision(runnerBuild)
      return 0
    } catch let failure as ProvisionFailure {
      runnerBuild.removeDirectory()
      if !failure.message.isEmpty { Console.error(failure.message) }
      return failure.code
    } catch {
      runnerBuild.removeDirectory()
      Console.error("\(error)")
      return 1
    }
  }

  private func provision(_ runnerBuild: RunnerBuild) throws {
    let prerequisites = try Prerequisites.check(
      runnerVersion: runnerVersion, sshPublicKey: sshPublicKey, requestedXcode: requestedXcode)

    let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    try AuthorizedKeysStep.replace(with: sshPublicKey, home: home)
    try SSHDHardeningStep.apply()
    try BootFirewallStep.install()
    RemoteAccessStep.disable()
    try LockdownVerification.verify()

    let brewEnvironment = ProvisionEnvironment.homebrew(prefix: prerequisites.brewPrefix)
    try ToolchainSetup.install(prerequisites, brewEnvironment: brewEnvironment)
    try runnerBuild.buildAndInstall(
      runnerVersion: runnerVersion, runnerMajor: prerequisites.runnerMajor,
      brewPrefix: prerequisites.brewPrefix, brewEnvironment: brewEnvironment)

    Console.log("removing any runner registration and work cache from the image.")
    try? FileManager.default.removeItem(atPath: home + "/.runner")
    try? FileManager.default.removeItem(atPath: home + "/.cache/act")

    try InstalledRunnerValidation.validate(runnerVersion: runnerVersion)

    runnerBuild.removeDirectory()
    Console.log("golden guest provisioning completed.")
  }
}
