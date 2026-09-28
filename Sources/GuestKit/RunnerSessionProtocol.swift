import Foundation

public enum RunnerSessionProtocol {
  // bumped whenever the host and the installed guest helper stop being compatible.
  public static let version = 3
  public static let validationMarker = "FORGEJO_ONE_JOB_PROTOCOL=\(version)"
}
