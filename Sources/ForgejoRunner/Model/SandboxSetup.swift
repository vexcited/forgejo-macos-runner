import Foundation
import Observation

@MainActor
@Observable
final class SandboxSetup {
  private let tart: TartClient
  private let tartConfigurator: TartConfigurator
  private let activity: ActivityLog

  // whether softnet can sandbox the runner vms, nil until checked.
  private(set) var status: SandboxStatus?
  private(set) var isSettingUp = false
  var errorMessage: String?

  init(tart: TartClient, tartConfigurator: TartConfigurator, activity: ActivityLog) {
    self.tart = tart
    self.tartConfigurator = tartConfigurator
    self.activity = activity
  }

  func refreshStatus() async {
    tartConfigurator.configure()
    status = await tart.sandboxStatus()
  }

  // asks macOS for an admin password once, so tart can run softnet as root.
  func setUp() async {
    guard case .needsPrivileges = status else { return }
    isSettingUp = true
    errorMessage = nil
    defer { isSettingUp = false }
    do {
      try await tart.grantSandboxPrivileges()
      activity.append("The sandbox is set up.")
    } catch {
      errorMessage = error.localizedDescription
    }
    await refreshStatus()
  }
}
