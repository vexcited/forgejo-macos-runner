import SwiftUI

struct UpdateSettingsSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var updater = model.updater

    Section {
      SettingRow(
        title: "Check for updates automatically",
        detail: "Look for a new release once a day."
      ) {
        Toggle("Check for updates automatically", isOn: $updater.automaticallyChecksForUpdates)
      }
      SettingRow(
        title: "Download updates automatically",
        detail: "Install a new release the next time Forgejo Runner quits."
      ) {
        Toggle("Download updates automatically", isOn: $updater.automaticallyDownloadsUpdates)
      }
      .disabled(!updater.automaticallyChecksForUpdates)
      LabeledContent(lastCheck) {
        Button("Check Now") { updater.checkForUpdates() }
      }
    } header: {
      Text("Updates")
    } footer: {
      if !updater.isAvailable {
        Text("Development builds do not update themselves.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .disabled(!updater.isAvailable)
  }

  private var lastCheck: String {
    guard let date = model.updater.lastCheckDate else { return "Never checked" }
    return "Last checked \(date.formatted(.relative(presentation: .named)))"
  }
}
