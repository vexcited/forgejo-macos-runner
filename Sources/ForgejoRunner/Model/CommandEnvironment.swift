import Foundation

enum CommandEnvironment {
  static func make(homeDirectory: URL) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["HOME"] = homeDirectory.path
    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    return environment
  }
}
