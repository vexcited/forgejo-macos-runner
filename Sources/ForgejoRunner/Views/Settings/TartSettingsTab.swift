import SwiftUI

struct TartSettingsTab: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      SandboxSettingsSection()
        .disabled(model.coordinator.isRunning)

      Section("Locations") {
        TextField("Tart", text: tartPath)
          .font(.body.monospaced())
          .onSubmit { Task { await model.refreshSandboxStatus() } }
          .disabled(model.coordinator.isRunning)
        PathRow(title: "VM", url: model.paths.tartHome) { model.revealTartHome() }
        PathRow(title: "Connections", url: model.paths.connectionsFile) {
          model.revealConnectionsFile()
        }
        .disabled(!FileManager.default.fileExists(atPath: model.paths.connectionsFile.path))
        PathRow(title: "Logs", url: model.paths.logsDirectory) { model.revealLogs() }
      }
    }
    .formStyle(.grouped)
  }

  private var tartPath: Binding<String> {
    Binding(
      get: { model.preferences.tartExecutablePath },
      set: { model.preferences.tartExecutablePath = $0 }
    )
  }
}
