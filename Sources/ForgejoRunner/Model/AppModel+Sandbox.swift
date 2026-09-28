import Foundation

extension AppModel {
  // whether softnet can sandbox the runner vms, nil until checked.
  var sandboxStatus: SandboxStatus? { sandboxSetup.status }
  var isSettingUpSandbox: Bool { sandboxSetup.isSettingUp }

  var sandboxErrorMessage: String? {
    get { sandboxSetup.errorMessage }
    set { sandboxSetup.errorMessage = newValue }
  }

  func refreshSandboxStatus() async {
    await sandboxSetup.refreshStatus()
  }

  func setUpSandbox() async {
    await sandboxSetup.setUp()
  }
}
