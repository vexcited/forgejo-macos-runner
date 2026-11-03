import Foundation

nonisolated enum RegistryError: LocalizedError, Sendable {
  case unexpectedStatus(Int)

  var errorDescription: String? {
    switch self {
    case .unexpectedStatus(let status):
      "The image registry answered with HTTP status \(status)."
    }
  }
}
