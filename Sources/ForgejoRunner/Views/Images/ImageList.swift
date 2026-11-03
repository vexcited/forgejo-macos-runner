import SwiftUI

struct ImageList: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: String?
  let provisioningDisabled: Bool
  let onDelete: (TartImage) -> Void
  let onUpdate: (ImageUpdateTarget) -> Void
  @State private var collapsed: Set<String> = []

  var body: some View {
    List(selection: $selection) {
      ForEach(topLevelImages) { image in
        let sessions = sessions(of: image)
        if sessions.isEmpty {
          row(for: image)
        } else {
          DisclosureGroup(isExpanded: expansion(of: image)) {
            ForEach(sessions) { session in
              row(for: session)
            }
          } label: {
            row(for: image)
          }
        }
      }
    }
    .listStyle(.inset)
    .task(id: model.writtenBytes.keys.sorted()) {
      // a job keeps writing to its vm, so its size is measured again while it runs.
      while !model.writtenBytes.isEmpty, !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        model.measureWrittenBytes()
      }
    }
  }

  // session vms are clones of the golden image, so they sit under it.
  private var topLevelImages: [TartImage] {
    model.images.filter { !isSession($0) || !hasGoldenImage }
  }

  private var hasGoldenImage: Bool {
    model.images.contains { $0.name == model.preferences.selectedImage }
  }

  private func sessions(of image: TartImage) -> [TartImage] {
    guard image.name == model.preferences.selectedImage else { return [] }
    return model.images.filter(isSession)
  }

  private func isSession(_ image: TartImage) -> Bool {
    image.name.hasPrefix(VMName.controllerPrefix)
  }

  private func expansion(of image: TartImage) -> Binding<Bool> {
    Binding(
      get: { !collapsed.contains(image.name) },
      set: { isExpanded in
        if isExpanded {
          collapsed.remove(image.name)
        } else {
          collapsed.insert(image.name)
        }
      }
    )
  }

  private func row(for image: TartImage) -> some View {
    ImageRow(
      image: image,
      isGolden: model.preferences.selectedImage == image.name,
      isProvisioned: model.preferences.isProvisioned(image.name),
      isProvisioning: model.isProvisioningImage
        && model.preferences.selectedImage == image.name,
      version: model.preferences.origin(of: image.name).map { $0.version ?? $0.tag },
      update: model.imageUpdates.statuses[image.name],
      writtenBytes: model.writtenBytes[image.name]
    ) {
      actions(for: image)
    }
    .tag(image.name)
    .contextMenu {
      actions(for: image)
    }
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
      .disabled(isSession(image))
    }
    if let repository = model.imageUpdates.repositories[image.name] {
      Button("Update...", systemImage: "arrow.down.circle") {
        onUpdate(ImageUpdateTarget(image: image, repository: repository))
      }
      .disabled(
        provisioningDisabled || model.pausedClone != nil || model.coordinator.isRunning)
    }
    Divider()
    Button("Delete", systemImage: "trash", role: .destructive) {
      onDelete(image)
    }
    .disabled(model.coordinator.isRunning)
  }
}
