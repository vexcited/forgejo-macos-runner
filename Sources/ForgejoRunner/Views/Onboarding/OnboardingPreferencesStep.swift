import SwiftUI

struct OnboardingPreferencesStep: View {
  var body: some View {
    VStack(spacing: 0) {
      OnboardingStepHeader(step: .preferences)
      Form {
        StartupSettingsSection()
        WindowSettingsSection()
        Section("While listening") {
          KeepAwakeSettingRow()
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
    }
  }
}
