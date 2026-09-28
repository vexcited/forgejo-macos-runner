import SwiftUI

struct ImagesToolbar: ToolbarContent {
  @Environment(AppModel.self) private var model
  let canStartClone: Bool
  let provisioningDisabled: Bool
  let selectedImage: TartImage?
  let onClone: () -> Void
  let onDelete: (TartImage?) -> Void

  var body: some ToolbarContent {
    @Bindable var model = model

    ToolbarItemGroup(placement: .primaryAction) {
      if model.isImageOperationRunning {
        ProgressView()
          .controlSize(.small)
      }
      Toggle("Logs", systemImage: "text.alignleft", isOn: $model.showsOperationLogs)
        .toggleStyle(.button)
        .help("Show the full log.")
      Button("Refresh", systemImage: "arrow.clockwise") {
        Task { await model.refreshImages() }
      }
      .disabled(model.isImageOperationRunning)
      Button("Clone", systemImage: "square.and.arrow.down", action: onClone)
        .disabled(!canStartClone)
        .help(
          model.pausedClone == nil
            ? "Clone a registry or local image."
            : "Resume or discard the paused clone before starting another one."
        )
      Button("Provision", systemImage: "wrench.and.screwdriver") {
        Task { await model.provisionGoldenImage() }
      }
      .disabled(model.preferences.selectedImage.isEmpty || provisioningDisabled)
      .help("Re-run provisioning on the golden image.")
      Button("Delete", systemImage: "trash", role: .destructive) {
        onDelete(selectedImage)
      }
      .disabled(
        selectedImage == nil || model.isImageOperationRunning || model.coordinator.isRunning)
    }
  }
}
