import Foundation

// removes disposable vms that an earlier session or controller run left behind.
@MainActor
final class StaleVMCleaner {
  private let tart: TartClient
  private let log: ActivityLog

  init(tart: TartClient, log: ActivityLog) {
    self.tart = tart
    self.log = log
  }

  func removeStaleVMs(prefix: String, excluding goldenImage: String) async throws {
    let staleVMs = try await tart.images().filter {
      $0.name.hasPrefix(prefix) && $0.name != goldenImage
    }
    guard !staleVMs.isEmpty else { return }
    log.append("Found \(staleVMs.count) stale controller VM\(staleVMs.count == 1 ? "" : "s").")
    for vm in staleVMs {
      do {
        try await tart.stop(name: vm.name, timeoutSeconds: 30)
      } catch {
        log.append("Could not stop stale VM \(vm.name): \(error.localizedDescription)")
      }
      do {
        try await tart.delete(name: vm.name)
      } catch {
        log.append("Could not delete stale VM \(vm.name): \(error.localizedDescription)")
      }
    }
    let failures = try await tart.images().map(\.name).filter {
      $0.hasPrefix(prefix) && $0 != goldenImage
    }
    if !failures.isEmpty {
      throw ControllerError.staleVMs(failures)
    }
  }
}
