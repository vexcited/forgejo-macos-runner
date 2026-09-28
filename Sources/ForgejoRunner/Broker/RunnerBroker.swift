import Foundation
import Network
import Security

// stands between the guest runner and forgejo for one job. the guest runner reaches
// an http CONNECT proxy through an ssh reverse tunnel on the pinned controller
// connection, its tls ends at this broker, and the broker forwards each runner call
// to forgejo with the real token added here. both listeners are unix sockets in a
// private directory, so no network peer and no other local user can reach them.
//
// the policy is one task per vm: the guest gets the task the host already fetched,
// never a second one, and may only report on that task. a workflow that takes over
// the guest therefore holds no long-lived secret and cannot pull other jobs.
@MainActor
final class RunnerBroker {
  private let identity: SecIdentity
  private let credentials: BrokerProxyCredentials
  private let connections = BrokerConnections()
  private let policy: BrokerCallPolicy
  private let proxy: BrokerProxy
  private let tlsServer: BrokerTLSServer

  private var directory: URL?
  private var proxyListener: NWListener?
  private var tlsListener: NWListener?

  // true once forgejo accepted a final result for the task.
  var taskFinished: Bool { policy.taskFinished }

  init(
    assignment: TaskAssignment,
    api: ForgejoRunnerAPI,
    identity: SecIdentity,
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) {
    let credentials = BrokerProxyCredentials(password: Self.randomToken())
    let refusals = BrokerRefusalLog(logHandler: logHandler)
    let policy = BrokerCallPolicy(
      assignment: assignment, api: api, refusals: refusals, logHandler: logHandler)
    let url = assignment.connection.connection.url
    self.identity = identity
    self.credentials = credentials
    self.policy = policy
    proxy = BrokerProxy(
      connections: connections, credentials: credentials, refusals: refusals,
      forgejoAuthority: "\(url.host() ?? ""):\(url.port ?? 443)".lowercased())
    tlsServer = BrokerTLSServer(connections: connections, policy: policy)
  }

  // starts both listeners and returns the proxy socket path the ssh forward targets.
  func start() async throws -> String {
    // short names keep the socket paths under the unix socket length limit.
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "fjb-\(Self.randomToken().prefix(8))", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    self.directory = directory
    let tlsPath = directory.appending(path: "t").path
    let proxyPath = directory.appending(path: "p").path

    tlsListener = try await BrokerListener.start(
      parameters: BrokerListener.tlsParameters(identity: identity), path: tlsPath,
      handler: { [weak self] connection in self?.tlsServer.accept(connection) })
    proxyListener = try await BrokerListener.start(
      parameters: .tcp, path: proxyPath,
      handler: { [weak self] connection in
        self?.proxy.accept(connection, tlsPath: tlsPath)
      })
    return proxyPath
  }

  // the proxy url for the guest runner, whose ssh reverse tunnel listens on guestPort.
  func guestProxyURL(guestPort: UInt16) -> String {
    credentials.proxyURL(guestPort: guestPort)
  }

  func stop() {
    connections.stop()
    proxyListener?.cancel()
    tlsListener?.cancel()
    proxyListener = nil
    tlsListener = nil
    if let directory {
      try? FileManager.default.removeItem(at: directory)
    }
    directory = nil
  }

  private static func randomToken() -> String {
    var generator = SystemRandomNumberGenerator()
    return (0..<24).map { _ in
      String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator))
    }.joined()
  }
}
