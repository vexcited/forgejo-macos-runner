import SwiftUI

struct ControllerButton: View {
  @Environment(AppModel.self) private var model
  var fillsWidth = false

  var body: some View {
    if model.coordinator.isRunning {
      Button {
        Task { await model.stopController() }
      } label: {
        Label("Stop", systemImage: "stop.fill")
          .frame(maxWidth: fillsWidth ? .infinity : nil)
      }
      .disabled(model.coordinator.isStopping)
      .help("Stop the controller and delete its VM.")
    } else {
      Button {
        Task { await model.startController() }
      } label: {
        Label("Start", systemImage: "play.fill")
          .frame(maxWidth: fillsWidth ? .infinity : nil)
      }
      .buttonStyle(.borderedProminent)
      .disabled(!model.canStartController)
      .help(
        model.canStartController
          ? "Start serving jobs from every connection."
          : "Add a connection and choose a golden image first.")
    }
  }
}
