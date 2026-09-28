import Foundation

nonisolated enum RunnerWorkerError: LocalizedError, Sendable {
  case noConnections
  case cleanupFailed(String)
  case sessionIdle
  case guestHelperOutdated
  case preparationFailed(String)

  // configuration problems need the user to act; a cleanup failure is transient and
  // is retried after the controller removes the stale VM.
  var isFatal: Bool {
    switch self {
    case .noConnections, .guestHelperOutdated: true
    case .cleanupFailed, .sessionIdle, .preparationFailed: false
    }
  }

  var errorDescription: String? {
    switch self {
    case .noConnections:
      "No Forgejo server connections were provided."
    case .cleanupFailed(let vmName):
      "The VM \(vmName) could not be deleted. Runner identity reuse is blocked for the pool."
    case .sessionIdle:
      "No job arrived within the runner session limit."
    case .guestHelperOutdated:
      SSHError.outdatedGuestHelper.localizedDescription
    case .preparationFailed(let reason):
      "Could not prepare the VM sandbox: \(reason)"
    }
  }
}
