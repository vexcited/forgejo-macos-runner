import SwiftUI

struct ControllerSettingsTab: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var preferences = model.preferences

    Form {
      if model.coordinator.isRunning {
        Section {
          Label("Stop the controller to change these settings.", systemImage: "lock.fill")
            .foregroundStyle(.secondary)
        }
      }
      Section("Virtual machines") {
        TextField("VM name prefix", text: $preferences.vmPrefix)
        KeepAwakeSettingRow()
      }
      .disabled(model.coordinator.isRunning)
    }
    .formStyle(.grouped)
  }
}
