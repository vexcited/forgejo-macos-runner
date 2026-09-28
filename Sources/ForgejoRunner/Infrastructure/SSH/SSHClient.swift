import Foundation

@MainActor
final class SSHClient {
  private let commands: CommandExecuting
  private let factory: SSHCommandFactory

  init(commands: CommandExecuting, factory: SSHCommandFactory) {
    self.commands = commands
    self.factory = factory
  }

  func validateCLI() async throws {
    guard FileManager.default.isExecutableFile(atPath: factory.executableURL.path) else {
      throw SSHError.notExecutable(factory.executableURL.path)
    }
    try validateCredentialFile(factory.identityFile, description: "controller SSH identity")
    _ = try await commands.checked(factory.version(), timeout: .seconds(10))
  }

  // pins the host key a fresh clone generated before any job, which the host read over
  // the tart guest agent. nothing else is trusted, not even the golden image's key,
  // which every earlier job could read.
  func trustSessionHostKey(_ publicKey: String) throws {
    let url = factory.knownHostsFile
    try? FileManager.default.removeItem(at: url)
    guard
      FileManager.default.createFile(
        atPath: url.path,
        contents: Data("\(SSHCommandFactory.sessionHostAlias) \(publicKey)\n".utf8),
        attributes: [.posixPermissions: 0o600])
    else {
      throw SSHError.invalidCredential("Could not pin the session SSH host key.")
    }
  }

  func forgetSessionHostKey() {
    try? FileManager.default.removeItem(at: factory.knownHostsFile)
  }

  func waitUntilReady(ipAddress: String, timeout: Duration) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    var lastError: Error?
    while clock.now < deadline {
      try Task.checkCancellation()
      do {
        _ = try await commands.checked(
          factory.readiness(ipAddress: ipAddress), timeout: .seconds(10))
        return
      } catch {
        lastError = error
      }
      try await Task.sleep(for: .seconds(2))
    }
    throw SSHError.notReady(lastError?.localizedDescription ?? "unknown SSH error")
  }

  func validateGuest(ipAddress: String) async throws {
    let result = try await commands.checked(
      factory.validateGuest(ipAddress: ipAddress), timeout: .seconds(30))
    guard result.outputString.contains(RunnerConnectionStream.guestValidationMarker) else {
      throw SSHError.outdatedGuestHelper
    }
  }

  func runOneJob(
    ipAddress: String,
    connection: RunnerConnection,
    proxyURL: String,
    brokerForward: BrokerForward,
    timeout: Duration,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult {
    let result = try await commands.run(
      factory.runOneJob(
        ipAddress: ipAddress, connection: connection, proxyURL: proxyURL,
        brokerForward: brokerForward),
      timeout: timeout,
      outputHandler: outputHandler
    )
    guard result.status == 0 else {
      throw SSHError.runnerExited(result.status)
    }
    return result
  }

  private func validateCredentialFile(_ url: URL, description: String) throws {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw SSHError.invalidCredential("The \(description) is missing at \(url.path).")
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular,
      let permissions = attributes[.posixPermissions] as? NSNumber,
      permissions.intValue & 0o077 == 0,
      let size = attributes[.size] as? NSNumber,
      size.intValue > 0,
      size.intValue <= 1_048_576
    else {
      throw SSHError.invalidCredential(
        "The \(description) must be a non-empty private regular file of at most 1 MiB."
      )
    }
  }
}
