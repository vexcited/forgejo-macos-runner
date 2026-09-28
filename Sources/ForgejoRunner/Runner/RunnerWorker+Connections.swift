import Foundation

extension RunnerWorker {
  static func resolve(_ connections: [RunnerConnection]) -> [ResolvedRunnerConnection] {
    connections.map { ResolvedRunnerConnection(connection: $0, token: $0.token.rawValue) }
  }
}
