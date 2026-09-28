import SwiftUI

struct StartupSettingsSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var preferences = model.preferences

    Section {
      SettingRow(
        title: "Open at login",
        detail: "Launch Forgejo Runner automatically when you log in to this Mac."
      ) {
        Toggle("Open at login", isOn: loginItemBinding)
      }
      if model.loginItem.requiresApproval {
        HStack {
          Label(
            "Allow Forgejo Runner in System Settings > General > Login Items.",
            systemImage: "exclamationmark.triangle.fill"
          )
          .foregroundStyle(.orange)
          .font(.callout)
          Spacer()
          Button("Open Login Items") { model.loginItem.openSystemSettings() }
        }
      }
      if let error = model.loginItem.errorMessage {
        Label(error, systemImage: "xmark.octagon.fill")
          .foregroundStyle(.red)
          .font(.callout)
          .textSelection(.enabled)
      }
      SettingRow(
        title: "Start the controller on launch",
        detail: "Begin serving jobs as soon as the configuration has loaded."
      ) {
        Toggle("Start the controller on launch", isOn: $preferences.launchControllerAutomatically)
      }
    } header: {
      Text("Startup")
    } footer: {
      if preferences.launchControllerAutomatically && model.loginItem.isEnabled {
        Text("This Mac serves jobs unattended after every login.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .onAppear { model.loginItem.refresh() }
  }

  private var loginItemBinding: Binding<Bool> {
    Binding(
      get: { model.loginItem.isEnabled || model.loginItem.requiresApproval },
      set: { enabled in
        Task { await model.loginItem.setEnabled(enabled) }
      }
    )
  }
}
