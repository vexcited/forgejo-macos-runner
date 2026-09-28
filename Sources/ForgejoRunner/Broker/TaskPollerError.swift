import Foundation

nonisolated enum TaskPollerError: LocalizedError, Sendable {
  case unexpectedAdditionalTasks(String)
  case invalidTask(String)

  var errorDescription: String? {
    switch self {
    case .unexpectedAdditionalTasks(let connection):
      "Forgejo handed \(connection) more than one task for a capacity-one runner."
    case .invalidTask(let connection):
      "Forgejo handed \(connection) a task without a valid id."
    }
  }
}
