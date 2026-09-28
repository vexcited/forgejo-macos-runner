import Foundation

// one boot of the golden image during provisioning: it waits for the guest agent,
// shuts the vm down cleanly, and stops it if anything went wrong.
@MainActor
final class ProvisioningBoot {
  let guest: GuestAgentChannel
  private let tart: TartProvisioning
  private let image: String
  private let runTask: Task<CommandResult, Error>
  private let logHandler: @MainActor @Sendable (String) -> Void

  init(
    tart: TartProvisioning,
    settings: GoldenImageSettings,
    networkMode: TartNetworkMode,
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) {
    self.tart = tart
    self.logHandler = logHandler
    image = settings.image
    guest = GuestAgentChannel(tart: tart, vmName: settings.image, user: settings.adminUser)
    runTask = Task {
      try await tart.runVM(name: settings.image, networkMode: networkMode, outputHandler: nil)
    }
  }

  func waitUntilReady(_ settings: GoldenImageSettings) async throws {
    logHandler("Waiting up to \(settings.bootTimeoutSeconds) seconds for the VM IP address.")
    _ = try await tart.waitForIPAddress(name: image, timeoutSeconds: settings.bootTimeoutSeconds)
    logHandler(
      "Waiting up to \(settings.guestAgentTimeoutSeconds) seconds for the Tart guest agent.")
    try await guest.waitUntilReady(timeout: .seconds(settings.guestAgentTimeoutSeconds))
  }

  // sync can return before the data is on disk, a clean shutdown cannot.
  func shutDownCleanly() async throws {
    _ = try await guest.run("/bin/sync", timeout: .seconds(60))
    logHandler("Shutting \(image) down cleanly.")
    _ = try? await guest.run("sudo -n /sbin/shutdown -h now", timeout: .seconds(30))
    let deadline = ContinuousClock.now.advanced(by: .seconds(180))
    while ContinuousClock.now < deadline {
      if let found = try await tart.images().first(where: { $0.name == image }),
        !found.isRunning, found.state.lowercased() == "stopped"
      {
        return
      }
      try await Task.sleep(for: .seconds(2))
    }
    throw ProvisioningError.shutdownTimedOut(image)
  }

  // a cancelled task refuses to run commands, so the vm is stopped from a fresh one.
  func tearDown() async {
    let (tart, image, runTask, logHandler) = (tart, image, runTask, logHandler)
    await Task {
      logHandler("Stopping \(image).")
      try? await tart.stop(name: image, timeoutSeconds: 30)
      runTask.cancel()
      _ = await runTask.result
    }.value
  }
}
