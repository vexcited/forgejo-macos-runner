import Foundation

enum ProvisionEnvironment {
  static let defaultPath =
    "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin"

  static let base: [String: String] = {
    var environment = ProcessInfo.processInfo.environment
    environment["LC_ALL"] = "C"
    if environment["PATH"] == nil { environment["PATH"] = defaultPath }
    return environment
  }()

  static func homebrew(prefix brewPrefix: String) -> [String: String] {
    var brewEnvironment = base
    brewEnvironment["HOMEBREW_PREFIX"] = brewPrefix
    brewEnvironment["HOMEBREW_CELLAR"] = brewPrefix + "/Cellar"
    brewEnvironment["HOMEBREW_REPOSITORY"] = brewPrefix
    brewEnvironment["PATH"] =
      "\(brewPrefix)/bin:\(brewPrefix)/sbin:" + (base["PATH"] ?? defaultPath)
    return brewEnvironment
  }
}
