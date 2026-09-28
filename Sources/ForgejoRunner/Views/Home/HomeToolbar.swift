import SwiftUI

// connections, images and settings as buttons in the top right of the title bar. the
// activity log already opens from the bar along the bottom.
struct HomeToolbar: ToolbarContent {
  let openWindow: OpenWindowAction

  var body: some ToolbarContent {
    if #available(macOS 26, *) {
      ToolbarSpacer(.flexible)
    }
    ToolbarItemGroup(placement: .primaryAction) {
      ForEach([AppPanel.connections, .images]) { panel in
        Button(panel.title, systemImage: panel.symbol) { openWindow(id: panel.rawValue) }
          .help(panel.title)
      }
      SettingsLink {
        Label("Settings", systemImage: "gearshape")
      }
      .help("Settings")
    }
  }
}
