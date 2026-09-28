import Foundation

nonisolated struct TaskAssignment: Sendable {
  let connection: ResolvedRunnerConnection
  let taskID: Int64
  // the untouched FetchTaskResponse, handed to the guest runner as is.
  let fetchResponse: Data
}
