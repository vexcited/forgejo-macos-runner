import Foundation
import GuestKit

enum RunnerBinary {
  static let path =
    ProcessInfo.processInfo.environment["FORGEJO_RUNNER_BIN"]
    ?? "/usr/local/bin/forgejo-runner"

  static func validate() -> Bool {
    guard Machine.isARM64() else {
      Console.error("forgejo runner host is not arm64.")
      return false
    }
    guard FileManager.default.isExecutableFile(atPath: path) else {
      Console.error("forgejo-runner is not executable.")
      return false
    }
    guard let version = ProcessRunner.capture(path, ["--version"]), version.status == 0,
      let major = RunnerToolchain.majorVersion(fromVersionOutput: version.output)
    else {
      Console.error("cannot parse forgejo-runner version.")
      return false
    }
    guard major >= 13 else {
      Console.error("forgejo-runner v13 or newer is required.")
      return false
    }
    guard let globalHelp = ProcessRunner.capture(path, ["--help"]),
      RunnerToolchain.help(globalHelp.output, contains: "--config")
    else {
      Console.error("forgejo-runner is missing --config.")
      return false
    }
    guard let oneJobHelp = ProcessRunner.capture(path, ["one-job", "--help"]),
      RunnerToolchain.help(oneJobHelp.output, contains: "--wait")
    else {
      Console.error("forgejo-runner is missing --wait.")
      return false
    }
    return true
  }
}
