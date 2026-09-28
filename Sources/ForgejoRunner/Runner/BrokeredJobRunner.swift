import Foundation
import Security

// runs the fetched task in the guest behind a broker that holds the token.
@MainActor
final class BrokeredJobRunner {
  private let ssh: SSHControlling
  private let logHandler: @MainActor @Sendable (String) -> Void

  init(ssh: SSHControlling, logHandler: @escaping @MainActor @Sendable (String) -> Void) {
    self.ssh = ssh
    self.logHandler = logHandler
  }

  func run(
    _ assignment: TaskAssignment,
    api: ForgejoRunnerAPI,
    identity: SecIdentity,
    poller: TaskPoller,
    ipAddress: String,
    deadline: ContinuousClock.Instant,
    outputHandler: @escaping @MainActor @Sendable (String) -> Void
  ) async throws {
    let broker = RunnerBroker(
      assignment: assignment, api: api, identity: identity, logHandler: logHandler)
    var jobError: Error?
    do {
      let hostSocket = try await broker.start()
      // a fresh vm has nothing listening yet, and a clash fails the forward and the session.
      let guestPort = UInt16.random(in: 20_000...60_999)
      _ = try await ssh.runOneJob(
        ipAddress: ipAddress,
        connection: assignment.connection.connection,
        proxyURL: broker.guestProxyURL(guestPort: guestPort),
        brokerForward: BrokerForward(guestPort: guestPort, hostSocket: hostSocket),
        timeout: max(deadline - ContinuousClock.now, .seconds(60)),
        outputHandler: outputHandler
      )
    } catch {
      jobError = error
    }
    broker.stop()
    if !broker.taskFinished {
      // a detached task, so a cancelled session still closes its job in forgejo.
      await Task { await poller.failTask(assignment) }.value
    }
    if let jobError {
      throw jobError
    }
  }
}
