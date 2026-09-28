import SwiftUI

struct ImageSettingsTab: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      ProvisioningSettingsSection()
    }
    .formStyle(.grouped)
    .disabled(model.coordinator.isRunning)
  }
}
