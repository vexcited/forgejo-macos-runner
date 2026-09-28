import SwiftUI

struct ProvisioningSettingsSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var preferences = model.preferences

    Section("Provisioning") {
      TextField("Version of Forgejo Runner", text: $preferences.runnerVersion)
      TextField(
        "Location of Xcode",
        text: $preferences.xcodeApplicationPath,
        prompt: Text("Discover automatically")
      )
    }
  }
}
