import Foundation
import GuestKit

// the default mode: validates the runner, reads the assignment from stdin and starts
// forgejo-runner for one job in an isolated runtime directory.
struct JobRun {
  let runner: Process
  private let runtimeDirectory: RuntimeDirectory

  static func start() -> JobRun {
    Console.log("validating the forgejo runner binary and one-job flags.")
    guard RunnerBinary.validate() else { exit(1) }

    let assignment = readAssignment()
    Console.log("received the job assignment for connection \(assignment.name).")
    Console.log("preparing an isolated runner directory.")

    umask(0o077)
    guard let runtimeDirectory = RuntimeDirectory.make() else {
      Console.error("could not create the runner runtime directory.")
      exit(1)
    }
    let configFile = writeConfig(for: assignment, in: runtimeDirectory)

    Console.log("configured connection \(assignment.name) for \(assignment.url).")
    Console.log(
      "connection \(assignment.name) advertises \(assignment.labels.joined(separator: ",")).")
    Console.log("the runner token stays on the host, runner calls go through the host broker.")

    Console.log("running the job the host broker assigned.")
    let runner = Process()
    runner.executableURL = URL(filePath: RunnerBinary.path)
    runner.arguments = ["--config", configFile, "one-job", "--wait"]
    runner.environment = RunnerConfig.processEnvironment(
      base: ProcessInfo.processInfo.environment, assignment: assignment)
    runner.standardInput = FileHandle.nullDevice
    runner.standardOutput = FileHandle.standardOutput
    runner.standardError = FileHandle.standardError
    do {
      try runner.run()
    } catch {
      Console.error("could not start forgejo-runner: \(error).")
      runtimeDirectory.remove()
      exit(1)
    }
    return JobRun(runner: runner, runtimeDirectory: runtimeDirectory)
  }

  func waitForExit() -> Int32 {
    runner.waitUntilExit()
    let runnerStatus = runner.terminationStatus
    runtimeDirectory.remove()
    Console.log("forgejo runner exited with status \(runnerStatus).")
    return runnerStatus
  }

  private static func readAssignment() -> GuestAssignment {
    let streamInput = String(
      decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    do {
      return try RunnerConnectionStream.decode(streamInput)
    } catch let error as RunnerStreamError {
      Console.error("invalid runner connection stream: \(error.message)")
      exit(65)
    } catch {
      Console.error("invalid runner connection stream: \(error).")
      exit(65)
    }
  }

  // returns the config file path, and removes the runtime directory before exiting on failure.
  private static func writeConfig(
    for assignment: GuestAssignment, in runtimeDirectory: RuntimeDirectory
  ) -> String {
    let runtimeDir = runtimeDirectory.path
    let configFile = "\(runtimeDir)/config.yml"
    let workDir = "\(runtimeDir)/work"
    try? FileManager.default.createDirectory(
      atPath: workDir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])

    let configYAML: String
    do {
      configYAML = try RunnerConfig.yaml(
        assignment: assignment, runnerFile: "\(runtimeDir)/.runner", workDir: workDir)
    } catch {
      Console.error("could not build the runner configuration: \(error).")
      runtimeDirectory.remove()
      exit(1)
    }
    guard
      FileManager.default.createFile(
        atPath: configFile, contents: Data(configYAML.utf8),
        attributes: [.posixPermissions: 0o600])
    else {
      Console.error("could not write the runner configuration.")
      runtimeDirectory.remove()
      exit(1)
    }
    return configFile
  }
}
