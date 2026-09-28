import Foundation

nonisolated enum RunnerBrokerError: LocalizedError, Sendable {
  case identityUnavailable
  case listenerFailed(String)

  var errorDescription: String? {
    switch self {
    case .identityUnavailable:
      "The runner broker has no TLS identity."
    case .listenerFailed(let reason):
      "The runner broker could not listen: \(reason)"
    }
  }
}
