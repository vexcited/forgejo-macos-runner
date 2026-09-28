import SwiftUI

// a secondary screen in its own window, next to the small status window.
struct PanelWindow: View {
  let panel: AppPanel

  var body: some View {
    Group {
      switch panel {
      case .connections: ConnectionsView()
      case .images: ImagesView()
      case .activity: ActivityView()
      }
    }
    .frame(minWidth: 560, minHeight: 420)
  }
}
