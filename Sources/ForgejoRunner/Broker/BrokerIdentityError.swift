import Foundation

nonisolated enum BrokerIdentityError: LocalizedError, Sendable {
  case generationFailed(String)
  case importFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .generationFailed(let output):
      "Could not generate the broker certificate: \(output)"
    case .importFailed(let status):
      "Could not load the broker certificate (OSStatus \(status))."
    }
  }
}
