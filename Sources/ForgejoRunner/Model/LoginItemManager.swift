import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginItemManager {
  private(set) var status: SMAppService.Status = .notRegistered
  var errorMessage: String?

  var isEnabled: Bool {
    status == .enabled
  }

  var requiresApproval: Bool {
    status == .requiresApproval
  }

  init() {
    refresh()
  }

  func refresh() {
    status = SMAppService.mainApp.status
  }

  func setEnabled(_ enabled: Bool) async {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try await SMAppService.mainApp.unregister()
      }
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
    refresh()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
