import Foundation

// stops and deletes a session vm, and only reports success once tart confirms it is gone.
@MainActor
final class SessionVMCleaner {
  private let tart: TartControlling
  private let logHandler: @MainActor @Sendable (String) -> Void

  init(tart: TartControlling, logHandler: @escaping @MainActor @Sendable (String) -> Void) {
    self.tart = tart
    self.logHandler = logHandler
  }

  func cleanup(
    vmName: String,
    tartRunTask: Task<CommandResult, Error>?
  ) async -> Bool {
    logHandler("Stopping \(vmName).")
    do {
      try await tart.stop(name: vmName, timeoutSeconds: 30)
    } catch {
      logHandler("Tart could not stop \(vmName): \(error.localizedDescription)")
    }
    tartRunTask?.cancel()
    if let tartRunTask {
      _ = await tartRunTask.result
    }

    logHandler("Deleting \(vmName).")
    do {
      try await tart.delete(name: vmName)
    } catch {
      logHandler("Tart could not delete \(vmName): \(error.localizedDescription)")
      do {
        if try await !tart.containsImage(named: vmName) {
          logHandler("Confirmed that \(vmName) does not exist.")
          return true
        }
      } catch {
        logHandler(
          "Could not inspect \(vmName) after deletion failed: \(error.localizedDescription)")
      }
      return false
    }
    do {
      return try await !tart.containsImage(named: vmName)
    } catch {
      logHandler("Could not confirm deletion of \(vmName): \(error.localizedDescription)")
      return false
    }
  }
}
