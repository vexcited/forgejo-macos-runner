import SwiftUI

struct SandboxSettingsSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Section {
      SandboxStatusRow()
      if let error = model.sandboxErrorMessage {
        Text(error).font(.caption).foregroundStyle(.red)
      }
      SandboxDNSField()
    } header: {
      Text("Sandbox")
    } footer: {
      Text(
        "Jobs can reach the internet, but never this Mac, your network or each other. macOS asks for an admin password once to turn this on."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .task { await model.refreshSandboxStatus() }
  }
}
