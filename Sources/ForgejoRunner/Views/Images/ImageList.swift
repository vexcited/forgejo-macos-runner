import SwiftUI

struct ImageList: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: String?
  let provisioningDisabled: Bool
  let onDelete: (TartImage) -> Void

  var body: some View {
    List(selection: $selection) {
      ForEach(model.images) { image in
        ImageRow(
          image: image,
          isGolden: model.preferences.selectedImage == image.name,
          isProvisioned: model.preferences.isProvisioned(image.name),
          isProvisioning: model.isProvisioningImage
            && model.preferences.selectedImage == image.name
        ) {
          actions(for: image)
        }
        .tag(image.name)
        .contextMenu {
          actions(for: image)
        }
      }
    }
    .listStyle(.inset)
  }

  @ViewBuilder
  private func actions(for image: TartImage) -> some View {
    if model.preferences.selectedImage == image.name {
      Button("Re-provision", systemImage: "wrench.and.screwdriver") {
        Task { await model.provisionGoldenImage() }
      }
      .disabled(provisioningDisabled)
    } else {
      Button("Use as Golden Image", systemImage: "star") {
        Task { await model.useAsGoldenImage(image.name) }
      }
      .disabled(image.name.hasPrefix(VMName.controllerPrefix))
    }
    Divider()
    Button("Delete", systemImage: "trash", role: .destructive) {
      onDelete(image)
    }
    .disabled(model.coordinator.isRunning)
  }
}
