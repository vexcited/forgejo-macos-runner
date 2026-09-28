import Foundation

enum InstalledRunnerValidation {
  static func validate(runnerVersion: String) throws {
    Console.log("validating the installed forgejo runner version.")
    guard
      let installed = ProcessRunner.capture(
        "/usr/local/bin/forgejo-runner", ["--version"], environment: ProvisionEnvironment.base),
      installed.status == 0
    else {
      throw ProvisionFailure(
        message: "the installed forgejo-runner did not report a version.", code: 1)
    }
    guard installed.output.contains("v\(runnerVersion)") else {
      throw ProvisionFailure(
        message:
          "unexpected installed runner version: \(installed.output.trimmingCharacters(in: .whitespacesAndNewlines))",
        code: 1)
    }
    FileHandle.standardOutput.write(Data(installed.output.utf8))
  }
}
