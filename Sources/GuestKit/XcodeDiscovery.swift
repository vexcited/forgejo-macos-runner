import Foundation

// Resolves which Xcode application to use, mirroring the former shell find_xcode_app.
public struct XcodeDiscovery {
  public let applicationsDir: String
  // The `xcode-select -p` developer directory, when a usable one is selected.
  public let selectedDeveloperDir: String?
  private let fileManager: FileManager

  public init(
    applicationsDir: String,
    selectedDeveloperDir: String?,
    fileManager: FileManager = .default
  ) {
    self.applicationsDir = applicationsDir
    self.selectedDeveloperDir = selectedDeveloperDir
    self.fileManager = fileManager
  }

  public func isXcodeApp(_ appPath: String) -> Bool {
    var isDirectory: ObjCBool = false
    let developer = appPath + "/Contents/Developer"
    guard fileManager.fileExists(atPath: developer, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return false
    }
    return fileManager.isExecutableFile(atPath: developer + "/usr/bin/xcodebuild")
  }

  public func find(requested: String) throws -> String {
    if !requested.isEmpty {
      guard requested.hasPrefix(applicationsDir + "/Xcode"), requested.hasSuffix(".app") else {
        throw XcodeDiscoveryError.requestedNotInApplications(applicationsDir)
      }
      guard isXcodeApp(requested) else {
        throw XcodeDiscoveryError.requestedNotUsable(requested)
      }
      return requested
    }

    let developerSuffix = ".app/Contents/Developer"
    if let developer = selectedDeveloperDir,
      developer.hasPrefix(applicationsDir + "/Xcode"),
      developer.hasSuffix(developerSuffix)
    {
      let selectedApp = String(developer.dropLast("/Contents/Developer".count))
      if isXcodeApp(selectedApp) {
        return selectedApp
      }
    }

    let defaultApp = applicationsDir + "/Xcode.app"
    if isXcodeApp(defaultApp) {
      return defaultApp
    }

    let candidates = usableXcodeApps()
    if candidates.count == 1 {
      return candidates[0]
    }
    if candidates.isEmpty {
      throw XcodeDiscoveryError.noneFound(applicationsDir)
    }
    throw XcodeDiscoveryError.multipleUnselected(candidates)
  }

  private func usableXcodeApps() -> [String] {
    let entries = (try? fileManager.contentsOfDirectory(atPath: applicationsDir)) ?? []
    return
      entries
      .filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }
      .map { applicationsDir + "/" + $0 }
      .filter { isXcodeApp($0) }
      .sorted()
  }
}
