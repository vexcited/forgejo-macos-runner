import Foundation

// the dedicated controller ssh identity the golden image trusts.
@MainActor
final class ControllerSSHIdentity {
  private let commands: CommandExecuting
  private let paths: AppPaths
  private let baseEnvironment: [String: String]
  private let sshKeygenURL: URL

  init(
    commands: CommandExecuting,
    paths: AppPaths,
    baseEnvironment: [String: String],
    sshKeygenURL: URL
  ) {
    self.commands = commands
    self.paths = paths
    self.baseEnvironment = baseEnvironment
    self.sshKeygenURL = sshKeygenURL
  }

  // Generates the dedicated controller Ed25519 identity if it does not exist yet
  // and returns its public key line.
  func ensurePublicKey(
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) async throws -> String {
    let manager = FileManager.default
    let identity = paths.sshIdentityFile
    let publicKeyURL = URL(filePath: identity.path + ".pub")
    try manager.createDirectory(
      at: identity.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    if !manager.fileExists(atPath: identity.path) {
      logHandler("Generating a new Ed25519 controller SSH identity.")
      try await runKeygen([
        "-q", "-t", "ed25519", "-N", "", "-C", "forgejo-tart-controller", "-f", identity.path,
      ])
    }
    try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: identity.path)
    if !manager.fileExists(atPath: publicKeyURL.path) {
      let derived = try await runKeygen(["-y", "-f", identity.path])
      try derived.output.write(to: publicKeyURL, options: .atomic)
    }
    let key = try String(contentsOf: publicKeyURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard key.hasPrefix("ssh-ed25519 ") else {
      throw ProvisioningError.identityUnavailable
    }
    return key
  }

  @discardableResult
  private func runKeygen(_ arguments: [String]) async throws -> CommandResult {
    let result = try await commands.run(
      CommandRequest(
        executableURL: sshKeygenURL,
        arguments: arguments,
        environment: baseEnvironment
      ),
      timeout: .seconds(30),
      outputHandler: nil
    )
    guard result.status == 0 else {
      throw CommandFailure(
        executable: "ssh-keygen", status: result.status, output: result.outputString)
    }
    return result
  }
}
