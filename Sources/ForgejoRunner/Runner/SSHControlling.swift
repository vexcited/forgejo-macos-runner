import Foundation

@MainActor
protocol SSHControlling: AnyObject {
  func trustSessionHostKey(_ publicKey: String) throws
  func forgetSessionHostKey()
  func waitUntilReady(ipAddress: String, timeout: Duration) async throws
  func validateGuest(ipAddress: String) async throws
  func runOneJob(
    ipAddress: String,
    connection: RunnerConnection,
    proxyURL: String,
    brokerForward: BrokerForward,
    timeout: Duration,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult
}

extension SSHClient: SSHControlling {
}
