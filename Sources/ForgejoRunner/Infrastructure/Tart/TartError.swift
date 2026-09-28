import Foundation

nonisolated enum TartError: LocalizedError, Sendable {
  case notExecutable(String)
  case missingSyntax(command: String, value: String)
  case invalidName
  case invalidSource
  case invalidIPAddress
  case sandboxUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .notExecutable(let path):
      "Tart is not executable at \(path)."
    case .missingSyntax(let command, let value):
      "The installed Tart command \(command) does not support \(value)."
    case .invalidName:
      "The Tart VM name is unsafe."
    case .invalidSource:
      "Enter a Tart registry source or local image name without whitespace."
    case .invalidIPAddress:
      "Tart returned an invalid VM IP address."
    case .sandboxUnavailable(let message):
      message
    }
  }
}
