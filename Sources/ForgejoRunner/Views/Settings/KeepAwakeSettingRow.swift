import SwiftUI

struct KeepAwakeSettingRow: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var preferences = model.preferences

    SettingRow(
      title: "Keep this Mac awake",
      detail:
        "The Mac may sleep, for example in a bag, and the controller reconnects when it wakes. Turn on so it never misses a job while listening."
    ) {
      Toggle("Keep this Mac awake", isOn: $preferences.preventSleep)
    }
  }
}
