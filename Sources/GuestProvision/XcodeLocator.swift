import Foundation
import GuestKit

enum XcodeLocator {
  static func makeDiscovery() -> XcodeDiscovery {
    let environment = ProcessInfo.processInfo.environment
    let applicationsDir = environment["XCODE_APPLICATIONS_DIR"] ?? "/Applications"
    let selectBin = environment["XCODE_SELECT_BIN"] ?? "/usr/bin/xcode-select"
    var selectedDeveloperDir: String?
    if FileManager.default.isExecutableFile(atPath: selectBin),
      let result = ProcessRunner.capture(
        selectBin, ["-p"], environment: ProvisionEnvironment.base),
      result.status == 0
    {
      let developer = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !developer.isEmpty { selectedDeveloperDir = developer }
    }
    return XcodeDiscovery(
      applicationsDir: applicationsDir, selectedDeveloperDir: selectedDeveloperDir)
  }

  // the --find-xcode mode, which prints the resolved application and exits.
  static func runFindMode(_ arguments: [String]) -> Never {
    guard arguments.count <= 2 else {
      Console.error("usage: forgejo-guest-provision --find-xcode [xcode-app]")
      exit(64)
    }
    let requested = arguments.count == 2 ? arguments[1] : ""
    do {
      print(try makeDiscovery().find(requested: requested))
      exit(0)
    } catch let error as XcodeDiscoveryError {
      Console.error(error.description)
      exit(error.exitCode)
    } catch {
      Console.error("\(error)")
      exit(1)
    }
  }
}
