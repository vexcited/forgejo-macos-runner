import Foundation

nonisolated enum ForgejoRunnerAPIError: LocalizedError, Sendable {
  case invalidPath(String)
  case invalidResponse
  case rejected(method: String, status: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .invalidPath(let path):
      "The runner call path \(path) is not allowed."
    case .invalidResponse:
      "Forgejo returned a response that is not HTTP."
    case .rejected(let method, let status, let message):
      "Forgejo rejected \(method) with HTTP \(status): \(message)"
    }
  }
}
