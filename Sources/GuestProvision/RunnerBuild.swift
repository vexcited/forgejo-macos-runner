import Foundation
import GuestKit

// builds forgejo-runner from source and installs it, keeping track of the build
// directory so every exit path can remove it.
final class RunnerBuild {
  private var directory: String?

  func buildAndInstall(
    runnerVersion: String, runnerMajor: Int, brewPrefix: String,
    brewEnvironment: [String: String]
  ) throws {
    let baseEnvironment = ProvisionEnvironment.base
    let buildDir = "/private/tmp/forgejo-runner-build.\(UUID().uuidString)"
    try FileManager.default.createDirectory(
      atPath: buildDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    directory = buildDir
    let sourceDir = buildDir + "/source"
    let builtRunner = buildDir + "/forgejo-runner"

    Console.log("cloning forgejo runner v\(runnerVersion) source.")
    try ProcessRunner.stream(
      "/usr/bin/git",
      [
        "clone", "--depth", "1", "--branch", "v\(runnerVersion)",
        "https://code.forgejo.org/forgejo/runner.git", sourceDir,
      ],
      environment: brewEnvironment)

    guard
      let moduleResult = ProcessRunner.capture(
        brewPrefix + "/bin/go", ["list", "-m"], environment: brewEnvironment,
        workingDirectory: sourceDir),
      moduleResult.status == 0
    else {
      throw ProvisionFailure(message: "could not read the runner go module path.", code: 1)
    }
    let modulePath = moduleResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
    let expectedModule = RunnerToolchain.expectedModulePath(major: runnerMajor)
    guard modulePath == expectedModule else {
      throw ProvisionFailure(message: "unexpected runner module \(modulePath).", code: 1)
    }

    Console.log("building the native arm64 forgejo runner binary.")
    try ProcessRunner.stream(
      brewPrefix + "/bin/go",
      [
        "build", "-trimpath",
        "-ldflags", "-s -w -X \(modulePath)/internal/pkg/ver.version=v\(runnerVersion)",
        "-o", builtRunner, ".",
      ],
      environment: brewEnvironment, workingDirectory: sourceDir)

    guard
      let fileResult = ProcessRunner.capture(
        "/usr/bin/file", [builtRunner], environment: baseEnvironment),
      fileResult.status == 0, fileResult.output.contains("arm64")
    else {
      throw ProvisionFailure(message: "the built forgejo-runner is not an arm64 binary.", code: 1)
    }

    Console.log("installing forgejo-runner in /usr/local/bin.")
    try ProcessRunner.stream(
      "/usr/bin/sudo", ["install", "-d", "-m", "0755", "/usr/local/bin"],
      environment: baseEnvironment)
    try ProcessRunner.stream(
      "/usr/bin/sudo", ["install", "-m", "0755", builtRunner, "/usr/local/bin/forgejo-runner"],
      environment: baseEnvironment)
  }

  func removeDirectory() {
    if let directory {
      try? FileManager.default.removeItem(atPath: directory)
      self.directory = nil
    }
  }
}
