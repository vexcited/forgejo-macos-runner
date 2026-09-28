import SwiftUI

struct SettingsView: View {
  @State private var tab = SettingsTab.general

  var body: some View {
    TabView(selection: $tab) {
      Tab("General", systemImage: "gearshape", value: .general) {
        GeneralSettingsTab()
      }
      Tab("Controller", systemImage: "cpu", value: .controller) {
        ControllerSettingsTab()
      }
      Tab("Golden Image", systemImage: "star", value: .image) {
        ImageSettingsTab()
      }
      Tab("VM", systemImage: "internaldrive", value: .tart) {
        TartSettingsTab()
      }
    }
    .frame(width: 600, height: 520)
  }
}
