import Foundation

nonisolated enum CommandExecutionError: LocalizedError, Sendable {
  case timedOut(String)

  var errorDescription: String? {
    switch self {
    case .timedOut(let executable):
      "\(executable) timed out and was terminated."
    }
  }
}
