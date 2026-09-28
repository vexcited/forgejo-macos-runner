import Foundation

nonisolated enum SSHError: LocalizedError, Sendable {
  case notExecutable(String)
  case invalidCredential(String)
  case notReady(String)
  case runnerExited(Int32)
  case outdatedGuestHelper

  var errorDescription: String? {
    switch self {
    case .notExecutable(let path):
      "SSH is not executable at \(path)."
    case .invalidCredential(let message):
      message
    case .notReady(let reason):
      "SSH did not become ready: \(reason)"
    case .runnerExited(let status):
      "The Forgejo runner session exited with status \(status)."
    case .outdatedGuestHelper:
      "The golden image has an older guest helper. Re-provision it to use the runner broker."
    }
  }
}
