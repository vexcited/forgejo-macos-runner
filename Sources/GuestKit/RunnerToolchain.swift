import Foundation

public enum RunnerToolchain {
  public static func majorVersion(fromVersionOutput output: String) -> Int? {
    guard let match = output.firstMatch(of: #/v(\d+)\./#) else { return nil }
    return Int(match.output.1)
  }

  public static func help(_ help: String, contains flag: String) -> Bool {
    help.contains(flag)
  }

  // The major component of a strict `x.y.z` release, or nil when malformed.
  public static func major(ofVersion version: String) -> Int? {
    guard let match = version.wholeMatch(of: #/(\d+)\.\d+\.\d+/#) else { return nil }
    return Int(match.output.1)
  }

  // forgejo-runner v13 or newer, expressed as a strict `x.y.z` release.
  public static func isSupportedVersion(_ version: String) -> Bool {
    guard let major = major(ofVersion: version) else { return false }
    return major >= 13
  }

  // The go module path the runner source is expected to declare for a major.
  public static func expectedModulePath(major: Int) -> String {
    "code.forgejo.org/forgejo/runner/v\(major)"
  }
}
