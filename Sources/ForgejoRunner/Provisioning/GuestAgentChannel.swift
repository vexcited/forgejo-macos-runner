import Foundation

// runs shell commands in a vm through the tart guest agent, a virtio channel that no
// network peer can reach. commands run as the admin user with its home directory,
// whichever account the agent itself runs as.
@MainActor
final class GuestAgentChannel {
  private let tart: TartProvisioning
  private let vmName: String
  private let user: String

  init(tart: TartProvisioning, vmName: String, user: String) {
    self.tart = tart
    self.vmName = vmName
    self.user = user
  }

  func run(
    _ shell: String,
    standardInput: Data? = nil,
    timeout: Duration,
    outputHandler: (@MainActor @Sendable (String) -> Void)? = nil
  ) async throws -> CommandResult {
    try await tart.execute(
      name: vmName,
      arguments: ["sudo", "-n", "-u", user, "-H", "/bin/sh", "-c", shell],
      standardInput: standardInput,
      timeout: timeout,
      outputHandler: outputHandler
    )
  }

  // the agent starts a little after the vm gets its address.
  func waitUntilReady(timeout: Duration) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    var lastError: Error?
    while ContinuousClock.now < deadline {
      try Task.checkCancellation()
      do {
        _ = try await run("/usr/bin/true", timeout: .seconds(30))
        return
      } catch {
        lastError = error
      }
      try await Task.sleep(for: .seconds(3))
    }
    throw lastError ?? ProvisioningError.guestAgentUnavailable
  }

  static func singleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
