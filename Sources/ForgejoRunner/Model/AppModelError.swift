import Foundation

nonisolated enum AppModelError: LocalizedError, Sendable {
  case stopControllerFirst
  case imageOperationRunning
  case connectionsUnavailable
  case reservedImageName
  case pausedCloneExists

  var errorDescription: String? {
    switch self {
    case .stopControllerFirst:
      "Stop the runner controller before changing this resource."
    case .imageOperationRunning:
      "Wait for the current image download or setup to finish."
    case .connectionsUnavailable:
      "Resolve the connections manifest error before starting the controller."
    case .reservedImageName:
      "Image names beginning with fjmr- are reserved for disposable worker VMs."
    case .pausedCloneExists:
      "Resume or discard the paused image clone before starting another one."
    }
  }
}
