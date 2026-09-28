import Foundation

nonisolated enum ProvisioningError: LocalizedError, Sendable {
  case resourcesMissing
  case imageMissing(String)
  case imageNotStopped(String)
  case stagingFailed
  case identityUnavailable
  case guestAgentUnavailable
  case shutdownTimedOut(String)

  var errorDescription: String? {
    switch self {
    case .shutdownTimedOut(let name):
      "\(name) did not shut down cleanly, so the provisioning may not have reached its disk."
    case .resourcesMissing:
      "The app's golden image provisioning resources are missing."
    case .guestAgentUnavailable:
      "The Tart guest agent did not answer. Runner sessions prepare their sandbox through it, so use a Cirrus Labs image that ships the agent."
    case .imageMissing(let name):
      "The Tart image \(name) does not exist in the app's Tart home."
    case .imageNotStopped(let name):
      "The golden image \(name) must be stopped before provisioning."
    case .stagingFailed:
      "Could not stage the guest provisioning script in the VM."
    case .identityUnavailable:
      "The controller SSH identity could not be prepared."
    }
  }
}
