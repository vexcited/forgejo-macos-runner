import SwiftUI

struct WindowSettingsSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var preferences = model.preferences

    Section("Window and menu bar") {
      SettingRow(
        title: "Keep running in the background",
        detail:
          "Closing the window hides Forgejo Runner from the Dock while the controller keeps working. Reopen it from the menu bar."
      ) {
        Toggle("Keep running in the background", isOn: $preferences.keepRunningInBackground)
      }
      SettingRow(
        title: "Show in the menu bar",
        detail: preferences.keepRunningInBackground
          ? "Always shown while running in the background, since it is the way back to the app."
          : "Status and quick controls for the runner pool."
      ) {
        Toggle("Show in the menu bar", isOn: $preferences.showMenuBarItem)
          .disabled(preferences.keepRunningInBackground)
      }
    }
    .onChange(of: preferences.keepRunningInBackground) { model.updateDockPresence() }
  }
}
