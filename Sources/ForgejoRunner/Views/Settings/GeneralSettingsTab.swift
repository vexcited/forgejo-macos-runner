import SwiftUI

struct GeneralSettingsTab: View {
  var body: some View {
    Form {
      StartupSettingsSection()
      WindowSettingsSection()
      UpdateSettingsSection()
    }
    .formStyle(.grouped)
  }
}
