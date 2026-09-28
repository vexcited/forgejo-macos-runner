import Foundation

nonisolated enum ControllerLockError: LocalizedError, Sendable {
  case cannotOpen
  case alreadyRunning

  var errorDescription: String? {
    switch self {
    case .cannotOpen:
      "The controller lock file could not be opened."
    case .alreadyRunning:
      "Another Forgejo Runner controller process is already active."
    }
  }
}
