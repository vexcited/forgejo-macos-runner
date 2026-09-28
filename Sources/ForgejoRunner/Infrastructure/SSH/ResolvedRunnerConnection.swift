import Foundation

nonisolated struct ResolvedRunnerConnection: Equatable, Sendable {
  let connection: RunnerConnection
  let token: String
}
