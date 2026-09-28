import Foundation

// checks the host and the golden image before the controller starts its sessions.
@MainActor
final class ControllerPreflight {
  private let tart: TartClient
  private let ssh: SSHClient
  private let staleVMs: StaleVMCleaner

  init(tart: TartClient, ssh: SSHClient, staleVMs: StaleVMCleaner) {
    self.tart = tart
    self.ssh = ssh
    self.staleVMs = staleVMs
  }

  func check(goldenImage name: String) async throws {
    // every runner vm is sandboxed, there is no unsandboxed fallback.
    if let problem = await tart.sandboxStatus().problem {
      throw TartError.sandboxUnavailable(problem)
    }
    try await ssh.validateCLI()
    try Task.checkCancellation()
    let images = try await tart.images()
    guard let goldenImage = images.first(where: { $0.name == name }) else {
      throw ControllerError.imageMissing(name)
    }
    guard !goldenImage.isRunning, goldenImage.state.lowercased() == "stopped" else {
      throw ControllerError.imageRunning(name)
    }
    try await staleVMs.removeStaleVMs(
      prefix: VMName.controllerPrefix,
      excluding: name
    )
  }
}
