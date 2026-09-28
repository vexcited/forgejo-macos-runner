import AppKit
import SwiftUI

struct RunnerMenuView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let status = model.controllerStatus

    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 1) {
          Text("Forgejo Runner")
            .font(.headline)
          HStack(spacing: 6) {
            StatusDot(tint: status.tint, size: 7)
            Text(status.title)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
      }

      VStack(alignment: .leading, spacing: 8) {
        infoRow("Connections", value: "\(model.connections.connections.count)")
        infoRow(
          "Golden image",
          value: model.preferences.selectedImage.isEmpty
            ? "Not chosen" : model.preferences.selectedImage)
        if let pool = model.coordinator.orderedStatuses.first, model.coordinator.isRunning {
          infoRow("Phase", value: pool.phase.title)
          if let vmName = pool.vmName {
            infoRow("VM", value: vmName)
          }
        }
        if let error = model.coordinator.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(3)
        }
      }

      ControllerButton(fillsWidth: true)
        .controlSize(.large)

      Divider()

      VStack(spacing: 2) {
        MenuRow(title: "Open", symbol: "macwindow", shortcut: "O") {
          dismiss()
          model.showMainWindow(using: openWindow)
        }
        .keyboardShortcut("o")
        MenuRow(title: "Settings", symbol: "gearshape", shortcut: ",") {
          dismiss()
          NSApp.activate()
          openSettings()
        }
        .keyboardShortcut(",")
        MenuRow(title: "Quit", symbol: "power", shortcut: "Q") {
          dismiss()
          NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
      }
    }
    .padding(12)
    .frame(width: 290)
  }

  private func infoRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(.callout)
  }
}
