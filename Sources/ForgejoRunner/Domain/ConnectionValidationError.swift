import Foundation

nonisolated enum ConnectionValidationError: LocalizedError, Equatable, Sendable {
  case invalidName
  case invalidURL
  case invalidUUID
  case invalidToken
  case tokenFileUnsupported
  case invalidLabels
  case duplicateName
  case duplicateUUID
  case tooManyConnections

  var errorDescription: String? {
    switch self {
    case .invalidName:
      "Use 1 to 40 letters, numbers, dots, underscores, or hyphens for the name."
    case .invalidURL:
      "Enter an HTTPS Forgejo URL without credentials, a query, or a fragment."
    case .invalidUUID:
      "Enter the UUID shown by Forgejo when the runner was created."
    case .invalidToken:
      "Enter a runner token of at most 1024 bytes without whitespace or control characters."
    case .tokenFileUnsupported:
      "Token files are no longer supported. Paste the runner token itself."
    case .invalidLabels:
      "Enter unique labels such as macos-latest."
    case .duplicateName:
      "Every connection name must be unique."
    case .duplicateUUID:
      "Every connection must use a different runner UUID."
    case .tooManyConnections:
      "Configure at most 128 runner connections."
    }
  }
}
