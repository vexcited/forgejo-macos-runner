import Foundation

nonisolated enum ControllerError: LocalizedError, Sendable {
  case imageMissing(String)
  case imageRunning(String)
  case staleVMs([String])

  var errorDescription: String? {
    switch self {
    case .imageMissing(let name):
      "The selected Tart image \(name) does not exist in the app's Tart home."
    case .imageRunning(let name):
      "The selected golden image \(name) must be stopped."
    case .staleVMs(let names):
      "Could not delete stale Tart VMs: \(names.joined(separator: ", "))."
    }
  }
}
